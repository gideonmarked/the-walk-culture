import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/purchase_fulfillment.dart';
import 'cloud/cloud_sync_service.dart';
import 'store_purchase_service.dart';

enum PurchaseStatus {
  /// Paid, verified and credited.
  purchased,
  cancelled,
  unavailable,

  /// The store took the payment but we couldn't confirm it yet (server
  /// unreachable, or still waiting on Play). Nothing is lost: the purchase
  /// stays open and is credited automatically once it verifies.
  deferred,
}

/// A purchase the server has verified, ready to credit. [key] identifies the
/// individual purchase (Play's order id), so crediting can be exactly-once.
class VerifiedPurchase {
  const VerifiedPurchase({
    required this.productId,
    required this.key,
    this.vipUntil,
  });

  final String productId;
  final String key;

  /// A subscription's expiry as the server now holds it; null for packs (and
  /// for the simulator, which grants the plan's nominal days instead).
  final DateTime? vipUntil;
}

/// Credits a verified purchase to the player. Called by the billing layer —
/// never by the UI — so a purchase is credited even when nobody is waiting on
/// it: one that verifies after the Store screen closed, after a timeout, or on
/// the next launch.
typedef OnPurchaseVerified = Future<void> Function(VerifiedPurchase purchase);

/// Buys a store product by id. The app codes against this so the entitlement
/// flow is testable and the billing SDK stays swappable. Implementations
/// credit through [OnPurchaseVerified]; [buy]'s status is only for the UI.
///
/// PRODUCTION: replace [SimulatedPurchaseService] with an `in_app_purchase`
/// implementation that (1) queries products from the store, (2) launches the
/// real purchase flow, and (3) hands the receipt to your backend for
/// server-side validation BEFORE the entitlement is granted. Never grant an
/// entitlement on the client's say-so alone.
abstract class PurchaseService {
  Future<PurchaseStatus> buy(String storeProductId);

  /// Localized price strings for the given products, keyed by store product id
  /// — e.g. "$0.99", "₱55.00", "€0,99". These come from the store, which prices
  /// per the user's Play region and currency, so display follows the user's
  /// location automatically. Missing/unknown ids are simply absent (the UI
  /// falls back to its own label). Empty when there's no real store.
  Future<Map<String, String>> priceLabels(Iterable<String> storeProductIds);

  /// True for the placeholder. The Store screen surfaces this loudly so a
  /// simulated grant is never mistaken for a real charge.
  bool get isSimulated;
}

/// Placeholder billing for local development ONLY: no real charge, grants the
/// entitlement after a beat. Every purchase path that uses it is labelled
/// "SIMULATED" in the UI, and [purchaseServiceProvider] refuses to hand it out
/// in a release build — shipping it would give away premium currency for free.
class SimulatedPurchaseService implements PurchaseService {
  SimulatedPurchaseService(this._onVerified);

  final OnPurchaseVerified _onVerified;
  int _seq = 0;

  @override
  bool get isSimulated => true;

  @override
  Future<PurchaseStatus> buy(String storeProductId) async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    await _onVerified(VerifiedPurchase(
      productId: storeProductId,
      key: 'sim-${DateTime.now().microsecondsSinceEpoch}-${_seq++}',
    ));
    return PurchaseStatus.purchased;
  }

  // No real store → no localized prices; the UI keeps its own labels.
  @override
  Future<Map<String, String>> priceLabels(Iterable<String> ids) async => const {};
}

/// Real billing in release; the simulator only in debug.
///
/// This split is the ship-blocker guard: even if someone forgets to swap an
/// implementation, a release build physically cannot grant an entitlement
/// without Play + the server both agreeing. In debug the simulator keeps the
/// store demoable without Play Console products.
final purchaseServiceProvider = Provider<PurchaseService>((ref) {
  Future<void> credit(VerifiedPurchase p) =>
      ref.read(purchaseFulfillerProvider).fulfill(p);
  if (kDebugMode) return SimulatedPurchaseService(credit);
  final store = StorePurchaseService(ref.read(cloudSyncProvider), credit);
  ref.onDispose(store.dispose);
  return store;
});
