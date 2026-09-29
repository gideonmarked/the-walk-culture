import 'dart:async';

import 'package:flutter/foundation.dart';
// Prefixed: the plugin exports its own `PurchaseStatus`, which collides with
// ours in purchase_service.dart.
import 'package:in_app_purchase/in_app_purchase.dart' as iap;
import 'package:in_app_purchase_android/in_app_purchase_android.dart'
    show InAppPurchaseAndroidPlatformAddition;

import 'cloud/cloud_sync_service.dart';
import 'purchase_service.dart';

/// Real billing: Google Play / App Store via `in_app_purchase`, with the grant
/// gated on server-side receipt validation.
///
/// The rule this class exists to enforce: **a completed purchase-stream event is
/// not proof of payment.** A rooted device can forge one. So we never grant on
/// it — we hand {productId, purchaseToken} to the validate-purchase Edge
/// Function, which asks Google directly, and credit only on its say-so.
///
/// The mirror-image rule: **never finish a purchase the server hasn't ruled
/// on.** Finishing (and, for packs, consuming) tells Play we delivered. If
/// validation merely failed to reach the server, the purchase is left open so
/// Play hands it back on the next [start] and it is retried.
class StorePurchaseService implements PurchaseService {
  StorePurchaseService(this._cloud, this._onVerified);

  final CloudSyncService _cloud;
  final OnPurchaseVerified _onVerified;
  final iap.InAppPurchase _iap = iap.InAppPurchase.instance;

  StreamSubscription<List<iap.PurchaseDetails>>? _sub;
  final Map<String, Completer<PurchaseStatus>> _pending = {};

  @override
  bool get isSimulated => false;

  static bool _isConsumable(String productId) => productId.contains('.currency.');

  /// Start listening for purchase updates. Runs at launch, before any [buy]:
  /// it also delivers purchases that completed while the app was closed, ones
  /// whose validation failed last time, and active subscriptions — which is
  /// how a renewal's new expiry reaches the server.
  Future<void> start() async {
    if (_sub != null || !await _iap.isAvailable()) return;
    _sub = _iap.purchaseStream.listen(
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
      var finish = true;
      if (p.status == iap.PurchaseStatus.error) {
        debugPrint('purchase error: ${p.error}');
        result = PurchaseStatus.unavailable;
      } else if (p.status == iap.PurchaseStatus.purchased ||
          p.status == iap.PurchaseStatus.restored) {
        // The only thing that grants: the server verifying the token.
        final token = p.verificationData.serverVerificationData;
        final v = await _cloud.validatePurchase(
          productId: p.productID,
          purchaseToken: token,
        );
        switch (v.outcome) {
          case ValidationOutcome.granted:
            try {
              await _onVerified(VerifiedPurchase(
                productId: p.productID,
                key: p.purchaseID ?? token,
                vipUntil: v.vipUntil,
              ));
              result = PurchaseStatus.purchased;
            } catch (e) {
              // Leave it open: the next delivery credits it (at most once).
              debugPrint('crediting purchase failed: $e');
              result = PurchaseStatus.deferred;
              finish = false;
            }
          case ValidationOutcome.rejected:
            result = PurchaseStatus.unavailable;
          case ValidationOutcome.retryLater:
            result = PurchaseStatus.deferred;
            finish = false;
        }
      }

      if (finish) await _finish(p);
      _pending.remove(p.productID)?.complete(result);
    }
  }

  /// Tell the store we're done with [p]. Packs are consumed here, by hand,
  /// rather than by the plugin's autoConsume — that consumes on arrival,
  /// before validation, and a consumed purchase is never redelivered.
  Future<void> _finish(iap.PurchaseDetails p) async {
    try {
      if (defaultTargetPlatform == TargetPlatform.android &&
          _isConsumable(p.productID)) {
        // Consuming also acknowledges, so there's no completePurchase after.
        await _iap
            .getPlatformAddition<InAppPurchaseAndroidPlatformAddition>()
            .consumePurchase(p);
      } else if (p.pendingCompletePurchase) {
        // Always complete, or Play auto-refunds after 3 days and the product
        // stays un-rebuyable in the meantime.
        await _iap.completePurchase(p);
      }
    } catch (e) {
      debugPrint('finishing purchase failed: $e');
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
    // autoConsume is off: _finish consumes once the server has ruled.
    final started = _isConsumable(storeProductId)
        ? await _iap.buyConsumable(purchaseParam: param, autoConsume: false)
        : await _iap.buyNonConsumable(purchaseParam: param);

    if (!started) {
      _pending.remove(storeProductId);
      return PurchaseStatus.unavailable;
    }
    // Resolved by the stream once Play — and then our server — answers. A
    // timeout doesn't mean it failed (a slow payment method can take far
    // longer); if it goes through, the stream credits it all the same.
    return completer.future.timeout(
      const Duration(minutes: 5),
      onTimeout: () {
        _pending.remove(storeProductId);
        return PurchaseStatus.deferred;
      },
    );
  }
}
