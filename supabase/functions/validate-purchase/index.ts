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
): Promise<boolean> {
  const access = await googleAccessToken();
  const kind = isSubscription ? 'subscriptions' : 'products';
  const url =
    `https://androidpublisher.googleapis.com/androidpublisher/v3/applications/` +
    `${PACKAGE_NAME}/purchases/${kind}/${productId}/tokens/${token}`;
  const res = await fetch(url, { headers: { Authorization: `Bearer ${access}` } });
  if (!res.ok) return false;
  const data = await res.json();

  if (isSubscription) {
    // Still inside the paid window?
    return Number(data.expiryTimeMillis ?? 0) > Date.now();
  }
  // purchaseState: 0 = purchased. Anything else (cancelled/pending) is a no.
  return data.purchaseState === 0;
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
    const grant = PRODUCTS[productId];
    if (!grant || !purchaseToken) {
      return new Response('unknown product', { status: 400 });
    }

    const isSub = (grant.vipDays ?? 0) > 0;
    if (!(await verifyWithGoogle(productId, purchaseToken, isSub))) {
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
      p_vip_days: grant.vipDays ?? 0,
    });
    if (error) throw error;

    return new Response(JSON.stringify({ ok: true }), {
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
