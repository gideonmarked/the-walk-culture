/// Shared, anonymous prayer requests — the ONE place the app deliberately lets
/// faith content leave the device. It sits apart from the private on-device
/// prayer/gratitude journal (design invariant #3): a request is uploaded only on
/// an explicit, consented tap, is stripped of any author identity before anyone
/// else can read it, and is rate-limited + moderated server-side. The private
/// journal is never touched by this feature.
library;

import '../models/shop_item.dart' show Rarity;
import 'prayer.dart' show kPrayerRewardOdds;

/// You may SEND at most this many requests per rolling 7 days. Enforced on the
/// server (`submit_prayer_request`); the client only mirrors it for the UI.
const int kMaxPrayerRequestsPerWeek = 2;

/// Hard cap on a request body — short enough to keep it a plea, not an essay,
/// and to discourage dumping personal details. Mirrored in the server RPC.
const int kPrayerRequestMaxChars = 280;

/// Praying for a request rewards a quiet cosmetic EVERY time — but only for the
/// first few each day, so it can't be farmed for currency.
const int kRewardedRequestPrayersPerDay = 5;

/// A shared request auto-hides once this many distinct people report it. Mirrors
/// the threshold in `report_prayer_request`.
const int kPrayerRequestReportThreshold = 3;

/// Reward odds for praying for a request — the same gentle curve as the other
/// devotions (kindest of the set; interceding for a stranger is the point).
const Map<Rarity, double> kRequestPrayerRewardOdds = kPrayerRewardOdds;

/// The consent shown before a request is sent. Deliberately blunt about where it
/// goes and what not to include — this is the explicit consent invariant #3
/// requires before any reflection may leave the device.
const String kPrayerRequestConsent =
    'Your request is shared anonymously with other walkers so they can pray for '
    'you. Please don’t include names, contact details, or anything you '
    'wouldn’t want a stranger to read.';

/// One shared prayer request as the app shows it — never carries who wrote it.
class SharedPrayerRequest {
  const SharedPrayerRequest({
    required this.id,
    required this.body,
    required this.prayCount,
    this.createdAt,
  });

  final String id;
  final String body;
  final int prayCount;
  final DateTime? createdAt;

  factory SharedPrayerRequest.fromMap(Map<String, dynamic> m) {
    final created = m['created_at'];
    return SharedPrayerRequest(
      id: m['id'] as String,
      body: (m['body'] as String?)?.trim() ?? '',
      prayCount: (m['pray_count'] as num?)?.toInt() ?? 0,
      createdAt: created is String ? DateTime.tryParse(created) : null,
    );
  }

  SharedPrayerRequest withPrayCount(int c) => SharedPrayerRequest(
        id: id,
        body: body,
        prayCount: c,
        createdAt: createdAt,
      );
}
