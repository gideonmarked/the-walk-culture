import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/spheres.dart';
import '../../data/shop_catalog.dart';
import '../../models/shop_item.dart';
import '../../state/app_providers.dart';

const Map<Rarity, Color> kRarityColor = {
  Rarity.common: Color(0xFF9E9E9E),
  Rarity.uncommon: Color(0xFF4CAF50),
  Rarity.rare: Color(0xFF2196F3),
  Rarity.epic: Color(0xFF9C27B0),
  Rarity.legendary: Color(0xFFFF9800),
  Rarity.celestial: Color(0xFFFFD700),
};

String rarityLabel(Rarity r) => r.name[0].toUpperCase() + r.name.substring(1);

/// The sphere list, shown as a section beneath the daily quests rather than as
/// its own tab — so it lives inside the caller's scroll view, not a Scaffold.
class SpheresSection extends ConsumerWidget {
  const SpheresSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final player = ref.watch(playerControllerProvider);
    final controller = ref.read(playerControllerProvider.notifier);
    final fmt = NumberFormat.decimalPattern();

    final visible = [
      for (var i = 0; i < kSphereTiers.length; i++)
        if (sphereVisible(kSphereTiers, i, player.openedSpheres))
          kSphereTiers[i],
    ];
    final openedToday = [
      for (final tier in kSphereTiers)
        if (player.openedSpheres.contains(tier.id)) tier,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Mystery Spheres',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              const Text(
                'Reach each step goal to make a sphere glow, then double-tap '
                'it to open. Opening one reveals the next. Resets every day.',
              ),
            ],
          ),
        ),
        for (final tier in visible)
          _SphereCard(
            tier: tier,
            todaySteps: player.todaySteps,
            fmt: fmt,
            onOpen: () async {
              final result = await controller.openSphere(tier);
              if (result != null && context.mounted) {
                await showDialog<void>(
                  context: context,
                  barrierDismissible: false,
                  builder: (_) => SphereOpenDialog(tier: tier, result: result),
                );
              }
            },
          ),
        if (openedToday.isNotEmpty)
          _OpenedTodayCard(
            tiers: openedToday,
            rewards: player.sphereRewards,
            fmt: fmt,
          ),
      ],
    );
  }
}

/// Recap of the spheres already opened today. Collapsed it's just the day's
/// sphere icons; expanded it lists what each one paid out. These tiers are gone
/// from the list above.
class _OpenedTodayCard extends StatelessWidget {
  const _OpenedTodayCard({
    required this.tiers,
    required this.rewards,
    required this.fmt,
  });

  final List<SphereTier> tiers;
  final Map<String, String> rewards;
  final NumberFormat fmt;

  ShopItem? _item(String id) {
    for (final item in kShopCatalog) {
      if (item.id == id) return item;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final subtle = Theme.of(context).textTheme.bodySmall;

    return Card(
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16),
        childrenPadding:
            const EdgeInsets.only(left: 16, right: 16, bottom: 12),
        title: Text('Opened today (${tiers.length})',
            style: Theme.of(context).textTheme.titleSmall),
        // Collapsed, the day still reads at a glance as a row of sphere icons.
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Wrap(
            spacing: 6,
            children: [
              for (final tier in tiers)
                Text(tier.emoji, style: const TextStyle(fontSize: 16)),
            ],
          ),
        ),
        children: [
          for (final tier in tiers) _row(context, tier, subtle),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, SphereTier tier, TextStyle? subtle) {
    final code = rewards[tier.id];
    final reward = code == null ? null : decodeSphereReward(code);
    final item = reward?.itemId == null ? null : _item(reward!.itemId!);

    // Rewards were only recorded from this version onwards, so a sphere opened
    // before the upgrade (or an item since removed from the catalog) has none.
    final Widget trailing;
    if (item != null) {
      trailing = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(item.emoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 6),
          Text(item.name, style: subtle),
          const SizedBox(width: 6),
          Text(rarityLabel(item.rarity),
              style: subtle?.copyWith(color: kRarityColor[item.rarity])),
        ],
      );
    } else if (reward != null && reward.bonusSteps > 0) {
      trailing =
          Text('+${fmt.format(reward.bonusSteps)} Pebbles', style: subtle);
    } else {
      trailing = Text('Opened', style: subtle);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(tier.emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 8),
          Expanded(child: Text(tier.name, style: subtle)),
          Flexible(child: Align(alignment: Alignment.centerRight, child: trailing)),
        ],
      ),
    );
  }
}

class _SphereCard extends StatefulWidget {
  const _SphereCard({
    required this.tier,
    required this.todaySteps,
    required this.fmt,
    required this.onOpen,
  });

  final SphereTier tier;
  final int todaySteps;
  final NumberFormat fmt;
  final VoidCallback onOpen;

  @override
  State<_SphereCard> createState() => _SphereCardState();
}

class _SphereCardState extends State<_SphereCard>
    with SingleTickerProviderStateMixin {
  // Only ready spheres glow, so the ticker is created on demand rather than for
  // every locked card. Must stay nullable: a `late final` initialiser would be
  // run by dispose() on a card that never glowed, building a Ticker against a
  // deactivated element.
  AnimationController? _pulse;

  AnimationController get _pulseController => _pulse ??= AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1100),
      )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tier = widget.tier;
    final ready = !tier.isRealMoney && widget.todaySteps >= tier.stepCost;
    final locked = !tier.isRealMoney && widget.todaySteps < tier.stepCost;
    final glow = kRarityColor[tier.baseRarity] ?? Colors.amber;

    final card = Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(tier.emoji, style: const TextStyle(fontSize: 36)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(tier.name,
                          style: Theme.of(context).textTheme.titleMedium),
                      Text(
                        tier.isRealMoney
                            ? 'Real-money purchase'
                            : ready
                                ? 'Ready! Double-tap to open ✨'
                                : 'Base: ${rarityLabel(tier.baseRarity)} · ${widget.fmt.format(tier.stepCost)} steps',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                _trailing(context, ready, locked),
              ],
            ),
            if (locked) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: (widget.todaySteps / tier.stepCost).clamp(0.0, 1.0),
                  minHeight: 8,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                  'Reach ${widget.fmt.format(tier.stepCost)} steps today to unlock',
                  style: Theme.of(context).textTheme.bodySmall),
            ],
            _OddsRow(tier: tier),
          ],
        ),
      ),
    );

    if (!ready) return card;

    // Glowing + double-tap to open when ready.
    return GestureDetector(
      onDoubleTap: widget.onOpen,
      child: AnimatedBuilder(
        animation: _pulseController,
        builder: (context, child) {
          final t = _pulseController.value;
          return Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: glow.withValues(alpha: 0.35 + 0.35 * t),
                  blurRadius: 10 + 14 * t,
                  spreadRadius: 1 + 2 * t,
                ),
              ],
            ),
            child: child,
          );
        },
        child: card,
      ),
    );
  }

  // Opened spheres never reach this card — they move to the day's summary.
  Widget _trailing(BuildContext context, bool ready, bool locked) {
    if (widget.tier.isRealMoney) return const Chip(label: Text('Soon'));
    if (ready) return const Icon(Icons.touch_app, size: 28);
    return const Icon(Icons.lock_outline);
  }
}

class _OddsRow extends StatelessWidget {
  const _OddsRow({required this.tier});
  final SphereTier tier;

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: Text('Drop rates', style: Theme.of(context).textTheme.bodySmall),
      children: [
        for (final r in kRarityOrder)
          if (tier.odds[r] != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(rarityLabel(r), style: TextStyle(color: kRarityColor[r])),
                  Text('${_fmtPct(tier.odds[r]!)}%'),
                ],
              ),
            ),
      ],
    );
  }

  String _fmtPct(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();
}

/// Animated open: the sphere shakes & swells, bursts, then the item pops in.
class SphereOpenDialog extends StatefulWidget {
  const SphereOpenDialog({super.key, required this.tier, required this.result});

  final SphereTier tier;
  final SphereResult result;

  @override
  State<SphereOpenDialog> createState() => _SphereOpenDialogState();
}

class _SphereOpenDialogState extends State<SphereOpenDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1700),
  )..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.result;
    final color = kRarityColor[r.rarity] ?? Colors.amber;
    final fmt = NumberFormat.decimalPattern();

    return AlertDialog(
      content: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final t = _c.value;
          final revealing = t >= 0.6;
          final reveal = ((t - 0.6) / 0.4).clamp(0.0, 1.0);

          Widget visual;
          if (!revealing) {
            // anticipation: wobble + swell + brightening glow
            final wobble = math.sin(t * math.pi * 10) * 0.15 * (1 - t);
            final scale = 1.0 + t * 0.5;
            visual = Transform.rotate(
              angle: wobble,
              child: Transform.scale(
                scale: scale,
                child: _glowing(widget.tier.emoji, color, 0.4 + t),
              ),
            );
          } else {
            final popScale = Curves.elasticOut.transform(reveal);
            visual = Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Transform.scale(
                  scale: popScale,
                  child: Text(r.item?.emoji ?? '🎁',
                      style: const TextStyle(fontSize: 72)),
                ),
                const SizedBox(height: 8),
                Opacity(
                  opacity: reveal,
                  child: Column(
                    children: [
                      Text(rarityLabel(r.rarity),
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: color, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(
                        r.item != null
                            ? '${r.item!.name}\nAdded to your inventory.'
                            : 'You own everything at this rarity —\n+${fmt.format(r.bonusSteps)} Pebbles instead',
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ],
            );
          }
          return SizedBox(
            height: 190,
            child: Center(child: visual),
          );
        },
      ),
      actions: [
        AnimatedBuilder(
          animation: _c,
          builder: (context, _) => _c.value > 0.62
              ? FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Nice!'))
              : const SizedBox(height: 40),
        ),
      ],
    );
  }

  Widget _glowing(String emoji, Color color, double intensity) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
              color: color.withValues(alpha: intensity.clamp(0.0, 1.0) * 0.7),
              blurRadius: 28,
              spreadRadius: 6),
        ],
      ),
      child: Text(emoji, style: const TextStyle(fontSize: 76)),
    );
  }
}
