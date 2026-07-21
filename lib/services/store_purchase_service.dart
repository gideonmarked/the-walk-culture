import 'dart:async';

import 'package:flutter/foundation.dart';
// Prefixed: the plugin exports its own `PurchaseStatus`, which collides with
// ours in purchase_service.dart.
import 'package:in_app_purchase/in_app_purchase.dart' as iap;

import 'cloud/cloud_sync_service.dart';
import 'purchase_service.dart';

/// Real billing: Google Play / App Store via `in_app_purchase`, with the grant
/// gated on server-side receipt validation.
///
/// The rule this class exists to enforce: **a completed purchase-stream event is
/// not proof of payment.** A rooted device can forge one. So we never grant
/// here — we hand {productId, purchaseToken} to the validate-purchase Edge
/// Function, which asks Google directly and only then writes the entitlement.
/// [buy] returns [PurchaseStatus.purchased] solely when the server says ok.
class StorePurchaseService implements PurchaseService {
  StorePurchaseService(this._cloud);

  final CloudSyncService _cloud;
  final iap.InAppPurchase _iap = iap.InAppPurchase.instance;

  StreamSubscription<List<iap.PurchaseDetails>>? _sub;
  final Map<String, Completer<PurchaseStatus>> _pending = {};

  @override
  bool get isSimulated => false;

  /// Start listening for purchase updates. Must run before any [buy]; it also
  /// delivers purchases that completed while the app was closed.
  Future<void> start() async {
    if (!await _iap.isAvailable()) return;
    _sub ??= _iap.purchaseStream.listen(
      _onPurchases,
      onError: (Object e) => debugPrint('purchaseStream error: $e'),
    );
    // Surfaces anything Play still considers owed to this user (restore).
    await _iap.restorePurchases();
  }

  void dispose() {
    _sub?.cancel();
    _sub = null;
  }

  Future<void> _onPurchases(List<iap.PurchaseDetails> purchases) async {
    for (final p in purchases) {
      if (p.status == iap.PurchaseStatus.pending) continue;

      var result = PurchaseStatus.cancelled;
      if (p.status == iap.PurchaseStatus.error) {
        debugPrint('purchase error: ${p.error}');
        result = PurchaseStatus.unavailable;
      } else if (p.status == iap.PurchaseStatus.purchased ||
          p.status == iap.PurchaseStatus.restored) {
        // The only thing that grants: the server verifying the token.
        final ok = await _cloud.validatePurchase(
          productId: p.productID,
          purchaseToken: p.verificationData.serverVerificationData,
        );
        result = ok ? PurchaseStatus.purchased : PurchaseStatus.unavailable;
      }

      // Always complete, or Play auto-refunds after 3 days and the product
      // stays un-rebuyable in the meantime.
      if (p.pendingCompletePurchase) {
        await _iap.completePurchase(p);
      }
      _pending.remove(p.productID)?.complete(result);
    }
  }

  @override
  Future<Map<String, String>> priceLabels(Iterable<String> ids) async {
    if (!await _iap.isAvailable()) return const {};
    try {
      final res = await _iap.queryProductDetails(ids.toSet());
      // ProductDetails.price is already localized to the user's Play region and
      // currency — this is what makes the displayed price follow their location.
      return {for (final p in res.productDetails) p.id: p.price};
    } catch (e) {
      debugPrint('priceLabels failed: $e');
      return const {};
    }
  }

  @override
  Future<PurchaseStatus> buy(String storeProductId) async {
    if (!await _iap.isAvailable()) return PurchaseStatus.unavailable;

    final response = await _iap.queryProductDetails({storeProductId});
    if (response.productDetails.isEmpty) {
      debugPrint('product not in store: $storeProductId — not configured in the '
          'console, or this build was not installed from the store');
      return PurchaseStatus.unavailable;
    }
    final param = iap.PurchaseParam(productDetails: response.productDetails.first);

    final completer = Completer<PurchaseStatus>();
    _pending[storeProductId] = completer;

    // Step packs are consumables (re-buyable); VIP subscriptions are not.
    final isConsumable = storeProductId.contains('.currency.');
    final started = isConsumable
        ? await _iap.buyConsumable(purchaseParam: param, autoConsume: true)
        : await _iap.buyNonConsumable(purchaseParam: param);

    if (!started) {
      _pending.remove(storeProductId);
      return PurchaseStatus.unavailable;
    }
    // Resolved by the stream once Play — and then our server — answers.
    return completer.future.timeout(
      const Duration(minutes: 5),
      onTimeout: () {
        _pending.remove(storeProductId);
        return PurchaseStatus.cancelled;
      },
    );
  }
}
