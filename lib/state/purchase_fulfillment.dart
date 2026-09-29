import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/premium.dart';
import '../services/purchase_service.dart';
import 'app_providers.dart';
import 'premium_providers.dart';

/// Turns a verified store purchase into wallet currency or VIP time.
///
/// The one place a purchase is credited. It used to happen in the Store
/// screen after `buy()` returned, which silently skipped every purchase that
/// verified with no screen waiting — after a timeout, after the player backed
/// out, or when Play redelivered it on a later launch.
class PurchaseFulfiller {
  PurchaseFulfiller(this._ref);

  final Ref _ref;

  Future<void> fulfill(VerifiedPurchase p) async {
    final premium = _ref.read(premiumControllerProvider.notifier);
    final player = _ref.read(playerControllerProvider.notifier);

    for (final pack in kCurrencyPacks) {
      if (pack.storeProductId != p.productId) continue;
      if (!premium.markPurchaseFulfilled(p.key)) return; // already credited
      await player.grantBonusSteps(pack.steps);
      await premium.recordPurchasedSteps(pack.steps);
      return;
    }

    for (final plan in kVipPlans) {
      if (plan.storeProductId != p.productId) continue;
      final until = p.vipUntil;
      if (until != null) {
        // The server's expiry is absolute, so re-applying it is harmless —
        // and a renewal arrives under the same key with a later expiry.
        await premium.setVipUntil(until);
      } else {
        // Simulator only: no server expiry, so grant the plan's nominal days.
        if (!premium.markPurchaseFulfilled(p.key)) return;
        await premium.grantVip(plan.days);
      }
      // Credit the day's stipend right away if this just made them VIP.
      await player.maybeGrantVipStipend();
      return;
    }
  }
}

final purchaseFulfillerProvider =
    Provider<PurchaseFulfiller>((ref) => PurchaseFulfiller(ref));
