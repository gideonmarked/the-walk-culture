import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/premium.dart';
import '../../services/cloud/cloud_sync_service.dart';
import '../../services/purchase_service.dart';
import '../../services/rewarded_ad_service.dart';
import '../../services/store_purchase_service.dart';
import '../../state/app_providers.dart';
import '../../state/premium_providers.dart';

class StoreScreen extends ConsumerStatefulWidget {
  const StoreScreen({super.key});

  @override
  ConsumerState<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends ConsumerState<StoreScreen> {
  final _fmt = NumberFormat.decimalPattern();
  bool _busy = false;

  /// Store-localized prices (user's region currency), keyed by product id.
  /// Empty until fetched / when there's no real store, then the hardcoded
  /// labels show instead.
  Map<String, String> _prices = const {};

  @override
  void initState() {
    super.initState();
    final svc = ref.read(purchaseServiceProvider);
    // Begin listening for purchase updates and restore anything Play still owes
    // this user (e.g. a purchase that completed while the app was closed).
    if (svc is StorePurchaseService) svc.start();
    _loadPrices(svc);
  }

  Future<void> _loadPrices(PurchaseService svc) async {
    final ids = [
      for (final p in kCurrencyPacks) p.storeProductId,
      for (final v in kVipPlans) v.storeProductId,
    ];
    final prices = await svc.priceLabels(ids);
    if (mounted && prices.isNotEmpty) setState(() => _prices = prices);
  }

  /// The price to show: the store's localized price if we have it, else the
  /// SKU's own fallback label.
  String _price(String productId, String fallback) =>
      _prices[productId] ?? fallback;

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  /// Simulated-purchase gate. Makes it unmistakable no real money moves, so a
  /// prototype grant is never confused with a live charge.
  Future<bool> _confirmSimulated(String title, String price) async {
    final simulated = ref.read(purchaseServiceProvider).isSimulated;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Price: $price'),
            if (simulated) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Theme.of(ctx).colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'SIMULATED — no real money is charged. Placeholder billing '
                  'for testing; wire real in-app purchases before release.',
                  style: TextStyle(
                      color: Theme.of(ctx).colorScheme.onErrorContainer),
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(simulated ? 'Simulate' : 'Buy')),
        ],
      ),
    );
    return ok ?? false;
  }

  Future<void> _buyPack(CurrencyPack pack) async {
    if (_busy) return;
    if (!await _confirmSimulated('Buy ${pack.label}', _price(pack.storeProductId, pack.priceLabel))) return;
    setState(() => _busy = true);
    final status = await ref.read(purchaseServiceProvider).buy(pack.storeProductId);
    if (status == PurchaseStatus.purchased) {
      await ref.read(playerControllerProvider.notifier).grantBonusSteps(pack.steps);
      await ref.read(premiumControllerProvider.notifier)
          .recordPurchasedSteps(pack.steps);
      _toast('+${_fmt.format(pack.steps)} steps added to your wallet');
    } else if (status == PurchaseStatus.unavailable) {
      _toast('Store unavailable — billing not configured yet');
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _buyVip(VipPlan plan) async {
    if (_busy) return;
    if (!await _confirmSimulated(plan.label, _price(plan.storeProductId, plan.priceLabel))) return;
    setState(() => _busy = true);
    final status = await ref.read(purchaseServiceProvider).buy(plan.storeProductId);
    if (status == PurchaseStatus.purchased) {
      await ref.read(premiumControllerProvider.notifier).grantVip(plan.days);
      // Credit the day's stipend right away if this upgrade just made them VIP.
      await ref.read(playerControllerProvider.notifier).maybeGrantVipStipend();
      _toast('VIP active — enjoy your perks!');
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _watchAd() async {
    if (_busy) return;
    final premium = ref.read(premiumControllerProvider.notifier);
    if (!premium.canWatchAd) {
      _toast("You've hit today's ad reward limit — come back tomorrow");
      return;
    }
    setState(() => _busy = true);
    final outcome = await ref.read(rewardedAdServiceProvider).show();
    if (outcome == AdOutcome.earned) {
      // The SERVER is the authority on the daily cap when we're online — the
      // local counter is a tampered-client-bypassable UX nicety. Offline we
      // fall back to the local cap and reconcile on the next online claim.
      final cloud = ref.read(cloudSyncProvider);
      var allowed = true;
      if (cloud.isReady) {
        allowed = await cloud.claimAdReward(rewardSteps: kAdRewardSteps) != null;
        if (!allowed) {
          _toast("Today's ad reward limit reached");
        }
      }
      // Re-check + record locally so double-taps can't double-reward.
      if (allowed && premium.recordAdReward()) {
        await ref
            .read(playerControllerProvider.notifier)
            .grantBonusSteps(kAdRewardSteps);
        _toast('+${_fmt.format(kAdRewardSteps)} steps for watching!');
      }
    } else if (outcome == AdOutcome.failed) {
      _toast('No ad available right now — try again shortly');
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final premium = ref.watch(premiumControllerProvider);
    final simulated = ref.watch(purchaseServiceProvider).isSimulated;

    return Scaffold(
      appBar: AppBar(title: const Text('Store')),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(12),
            children: [
              if (simulated) const _SimulatedBanner(),
              _VipSection(
                premium: premium,
                onBuy: _buyVip,
                priceOf: (plan) => _price(plan.storeProductId, plan.priceLabel),
              ),
              const SizedBox(height: 8),
              _AdRewardCard(
                premium: premium,
                onWatch: _watchAd,
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 12, 4, 4),
                child: Text('Step packs',
                    style: Theme.of(context).textTheme.titleMedium),
              ),
              for (final pack in kCurrencyPacks)
                _PackTile(
                    pack: pack,
                    fmt: _fmt,
                    price: _price(pack.storeProductId, pack.priceLabel),
                    onBuy: () => _buyPack(pack)),
              const SizedBox(height: 24),
            ],
          ),
          if (_busy)
            const ColoredBox(
              color: Color(0x66000000),
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}

class _SimulatedBanner extends StatelessWidget {
  const _SimulatedBanner();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(Icons.warning_amber, color: scheme.onErrorContainer),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Demo store — purchases are simulated, no real money is charged. '
                'Real billing gets wired before release.',
                style: TextStyle(color: scheme.onErrorContainer, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VipSection extends StatelessWidget {
  const _VipSection(
      {required this.premium, required this.onBuy, required this.priceOf});

  final PremiumState premium;
  final Future<void> Function(VipPlan) onBuy;
  final String Function(VipPlan) priceOf;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: premium.isVip ? scheme.secondaryContainer : null,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.workspace_premium, color: Colors.amber),
                const SizedBox(width: 8),
                Text('VIP', style: Theme.of(context).textTheme.titleLarge),
                const Spacer(),
                if (premium.isVip)
                  Chip(label: Text('${premium.vipDaysLeft} days left')),
              ],
            ),
            const SizedBox(height: 8),
            for (final perk in kVipPerks)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    const Icon(Icons.check, size: 18),
                    const SizedBox(width: 8),
                    Expanded(child: Text(perk)),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            Text(premium.isVip ? 'Extend' : 'Subscribe',
                style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            for (final plan in kVipPlans)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(plan.label,
                                  style: Theme.of(context).textTheme.titleSmall),
                              if (plan.highlight) ...[
                                const SizedBox(width: 6),
                                const Chip(
                                  label: Text('Popular'),
                                  visualDensity: VisualDensity.compact,
                                ),
                              ],
                            ],
                          ),
                          Text(priceOf(plan),
                              style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                    ),
                    FilledButton(
                      onPressed: () => onBuy(plan),
                      child: Text(plan.highlight ? 'Best' : 'Get'),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _AdRewardCard extends StatelessWidget {
  const _AdRewardCard({required this.premium, required this.onWatch});

  final PremiumState premium;
  final VoidCallback onWatch;

  @override
  Widget build(BuildContext context) {
    final watched = premium.adRewardsDay == _todayKey()
        ? premium.adRewardsToday
        : 0;
    final limit = premium.adRewardLimit;
    final canWatch = watched < limit;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Text('📺', style: TextStyle(fontSize: 32)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Watch an ad',
                      style: Theme.of(context).textTheme.titleMedium),
                  Text(
                    canWatch
                        ? '+${NumberFormat.decimalPattern().format(kAdRewardSteps)} steps · $watched/$limit today'
                        : 'Daily limit reached ($limit/$limit)',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            FilledButton.tonal(
              onPressed: canWatch ? onWatch : null,
              child: const Text('Watch'),
            ),
          ],
        ),
      ),
    );
  }

  // Local mirror of the controller's day-key logic for the display counter.
  String _todayKey() {
    final d = DateTime.now();
    return '${d.year}-${d.month}-${d.day}';
  }
}

class _PackTile extends StatelessWidget {
  const _PackTile(
      {required this.pack,
      required this.fmt,
      required this.price,
      required this.onBuy});

  final CurrencyPack pack;
  final NumberFormat fmt;
  final String price;
  final VoidCallback onBuy;

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: pack.bestValue
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: Colors.amber, width: 1.5),
            )
          : null,
      child: ListTile(
        leading: const Text('👣', style: TextStyle(fontSize: 28)),
        title: Row(
          children: [
            Text(pack.label),
            if (pack.bestValue) ...[
              const SizedBox(width: 6),
              const Chip(
                label: Text('Best value'),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ],
        ),
        subtitle: Text('+${fmt.format(pack.steps)} steps'),
        trailing: FilledButton(onPressed: onBuy, child: Text(price)),
      ),
    );
  }
}
