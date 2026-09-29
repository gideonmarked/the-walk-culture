// StepQuest — server-side purchase validation.
//
// The ONLY place a real-money entitlement is granted. Flow:
//   client buys via Play Billing  ->  sends {productId, purchaseToken}
//   -> we verify the token with Google's Android Publisher API
//   -> we call grant_purchase() with the service-role key (idempotent)
//
// Why it must be server-side: a client can lie about having purchased. The
// purchase token is the only thing Google will vouch for, and grant_purchase()
// keys off it uniquely so a replayed token cannot pay out twice.
//
// Responses the app relies on (lib/services/cloud/cloud_sync_service.dart):
//   200 {ok: true, vipUntil?}  granted (or already granted) — finish the purchase
//   4xx                        permanently refused — finish it, grant nothing
//   5xx                        couldn't decide — leave it open, retry later
//
// Deploy:  supabase functions deploy validate-purchase
// Secrets: supabase secrets set GOOGLE_SERVICE_ACCOUNT_JSON='{...}'
//
// Free tier: 500k invocations/month — far beyond what this needs.

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

// What each product grants. MUST mirror lib/core/premium.dart. Kept server-side
// so the client cannot claim "this pack is worth 10 million steps".
const PRODUCTS: Record<string, { steps?: number; vipDays?: number }> = {
  'com.perfeos.step_quest.currency.pouch': { steps: 10000 },
  'com.perfeos.step_quest.currency.sack': { steps: 60000 },
  'com.perfeos.step_quest.currency.chest': { steps: 150000 },
  'com.perfeos.step_quest.currency.vault': { steps: 400000 },
  'com.perfeos.step_quest.vip.weekly': { vipDays: 7 },
  'com.perfeos.step_quest.vip.monthly': { vipDays: 30 },
  'com.perfeos.step_quest.vip.annual': { vipDays: 365 },
};

const PACKAGE_NAME = 'com.perfeos.step_quest';

// Play purchase tokens are URL-safe base64-ish strings. Anything else is
// refused before it gets near a URL: a token like "x/../../<other product>/
// tokens/T" would otherwise have fetch() normalise the path and verify a
// different purchase, while the raw string dodges the unique-token replay
// guard (every new spelling of the same token looks unused).
const TOKEN_PATTERN = /^[A-Za-z0-9._-]{16,4096}$/;

/** Google answered, and the answer is final. */
type Verdict =
  | { valid: false }
  | { valid: true; vipUntil?: string };

class RetryableError extends Error {}

/** Mint a Google OAuth access token from the service-account key (JWT grant). */
async function googleAccessToken(): Promise<string> {
  const sa = JSON.parse(Deno.env.get('GOOGLE_SERVICE_ACCOUNT_JSON')!);
  const now = Math.floor(Date.now() / 1000);
  const header = { alg: 'RS256', typ: 'JWT' };
  const claim = {
    iss: sa.client_email,
    scope: 'https://www.googleapis.com/auth/androidpublisher',
    aud: 'https://oauth2.googleapis.com/token',
    exp: now + 3600,
    iat: now,
  };

  const b64 = (o: unknown) =>
    btoa(JSON.stringify(o)).replace(/=/g, '').replace(/\+/g, '-').replace(/\//g, '_');
  const unsigned = `${b64(header)}.${b64(claim)}`;

  // Import the PEM private key and sign the JWT.
  const pem = sa.private_key
    .replace(/-----(BEGIN|END) PRIVATE KEY-----/g, '')
    .replace(/\s/g, '');
  const der = Uint8Array.from(atob(pem), (c) => c.charCodeAt(0));
  const key = await crypto.subtle.importKey(
    'pkcs8',
    der,
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign'],
  );
  const sig = await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5',
    key,
    new TextEncoder().encode(unsigned),
  );
  const sigB64 = btoa(String.fromCharCode(...new Uint8Array(sig)))
    .replace(/=/g, '').replace(/\+/g, '-').replace(/\//g, '_');

  const res = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: `${unsigned}.${sigB64}`,
    }),
  });
  if (!res.ok) throw new Error(`google token: ${await res.text()}`);
  return (await res.json()).access_token;
}

/** Ask Google whether this purchase token is real and still valid. */
async function verifyWithGoogle(
  productId: string,
  token: string,
  isSubscription: boolean,
): Promise<Verdict> {
  const access = await googleAccessToken();
  const kind = isSubscription ? 'subscriptions' : 'products';
  const url =
    `https://androidpublisher.googleapis.com/androidpublisher/v3/applications/` +
    `${PACKAGE_NAME}/purchases/${kind}/${encodeURIComponent(productId)}` +
    `/tokens/${encodeURIComponent(token)}`;
  const res = await fetch(url, { headers: { Authorization: `Bearer ${access}` } });
  // 5xx / rate limits are Google being unavailable, not a verdict.
  if (res.status >= 500 || res.status === 429) {
    throw new RetryableError(`google ${res.status}: ${await res.text()}`);
  }
  if (!res.ok) return { valid: false };
  const data = await res.json();

  if (isSubscription) {
    // Still inside the paid window? The expiry Google reports IS the
    // entitlement: it moves forward on each renewal under the same token.
    const expiry = Number(data.expiryTimeMillis ?? 0);
    if (!(expiry > Date.now())) return { valid: false };
    return { valid: true, vipUntil: new Date(expiry).toISOString() };
  }
  // Belt and braces: the purchase Google describes must be the one we price.
  if (data.productId != null && data.productId !== productId) {
    return { valid: false };
  }
  // purchaseState: 0 = purchased. Anything else (cancelled/pending) is a no.
  return data.purchaseState === 0 ? { valid: true } : { valid: false };
}

Deno.serve(async (req) => {
  try {
    if (req.method !== 'POST') return new Response('method not allowed', { status: 405 });

    // Identify the caller from their JWT — never trust a user_id in the body.
    const authHeader = req.headers.get('Authorization') ?? '';
    const anon = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_ANON_KEY')!,
      { global: { headers: { Authorization: authHeader } } },
    );
    const { data: userData } = await anon.auth.getUser();
    const user = userData?.user;
    if (!user) return new Response('unauthorized', { status: 401 });

    const { productId, purchaseToken } = await req.json();
    const grant = Object.hasOwn(PRODUCTS, productId) ? PRODUCTS[productId] : undefined;
    if (!grant) {
      return new Response('unknown product', { status: 400 });
    }
    if (typeof purchaseToken !== 'string' || !TOKEN_PATTERN.test(purchaseToken)) {
      return new Response('malformed purchase token', { status: 400 });
    }

    const isSub = (grant.vipDays ?? 0) > 0;
    const verdict = await verifyWithGoogle(productId, purchaseToken, isSub);
    if (!verdict.valid) {
      return new Response(JSON.stringify({ ok: false, reason: 'invalid receipt' }), {
        status: 402,
        headers: { 'Content-Type': 'application/json' },
      });
    }

    // Service role bypasses RLS — this is the only path allowed to grant.
    const admin = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    );
    const { error } = await admin.rpc('grant_purchase', {
      p_user: user.id,
      p_platform: 'google_play',
      p_product_id: productId,
      p_purchase_token: purchaseToken,
      p_steps: grant.steps ?? 0,
      p_vip_until: verdict.vipUntil ?? null,
    });
    if (error) {
      // A token already redeemed by another account is a final no, not a
      // server fault — don't make that client retry it forever.
      if (String(error.message).includes('belongs to another account')) {
        return new Response(JSON.stringify({ ok: false, reason: 'token already used' }), {
          status: 409,
          headers: { 'Content-Type': 'application/json' },
        });
      }
      throw error;
    }

    return new Response(JSON.stringify({ ok: true, vipUntil: verdict.vipUntil ?? null }), {
      headers: { 'Content-Type': 'application/json' },
    });
  } catch (e) {
    console.error(e);
    return new Response(JSON.stringify({ ok: false, error: String(e) }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' },
    });
  }
});
