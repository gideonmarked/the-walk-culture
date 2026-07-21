import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'cloud/cloud_sync_service.dart';
import 'store_purchase_service.dart';

enum PurchaseStatus { purchased, cancelled, unavailable }

/// Buys a store product by id. The app codes against this so the entitlement
/// flow is testable and the billing SDK stays swappable.
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
  const SimulatedPurchaseService();

  @override
  bool get isSimulated => true;

  @override
  Future<PurchaseStatus> buy(String storeProductId) async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
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
  if (kDebugMode) return const SimulatedPurchaseService();
  return StorePurchaseService(ref.read(cloudSyncProvider));
});
