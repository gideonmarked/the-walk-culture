import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/travel_pass.dart';
import '../../data/pass_catalog.dart';
import '../../state/app_providers.dart';
import '../../state/premium_providers.dart';
import '../../widgets/sprite_thumb.dart';
import '../store/store_screen.dart';

/// The Travel Pass: one 30-rung ladder, two columns. Free on the left, VIP on
/// the right. The header stays put while the ladder scrolls, so your level and
/// the season clock are always on screen.
class TravelPassScreen extends ConsumerStatefulWidget {
  const TravelPassScreen({super.key});

  @override
  ConsumerState<TravelPassScreen> createState() => _TravelPassScreenState();
}

/// Fixed row height — lets the list use `itemExtent` (cheap for 30 rows) and
/// makes the open-at-your-level jump exact arithmetic instead of a guess.
const double _kRowExtent = 92;

class _TravelPassScreenState extends ConsumerState<TravelPassScreen> {
  final _scroll = ScrollController();
  final _fmt = NumberFormat.decimalPattern();

  @override
  void initState() {
    super.initState();
    // Open on the rung you're standing on rather than at level 1 — by level 20
    // the interesting part is a long way down the list.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      final level = ref.read(playerControllerProvider.notifier).passLevel;
      final target = ((level - 1).clamp(0, kPassLevelCount - 1)) * _kRowExtent;
      _scroll.jumpTo(target.clamp(0, _scroll.position.maxScrollExtent));
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _claim(int level, {required bool vip}) async {
    final reward = await ref
        .read(playerControllerProvider.notifier)
        .claimPassReward(level, vip: vip);
    if (reward == null) {
      // The cell looked open but the controller refused — VIP expired since
      // this frame was built, or the season rolled under us. Never a dead tap.
      _toast('That reward is no longer available.');
      return;
    }
    _toast('Level $level — ${passRewardLabel(reward)} claimed!');
  }

  Future<void> _claimAll() async {
    final claimed =
        await ref.read(playerControllerProvider.notifier).claimAllPassRewards();
    if (claimed.isEmpty) {
      _toast('Nothing to claim right now.');
      return;
    }
    _toast(claimed.length == 1
        ? '${passRewardLabel(claimed.single)} claimed!'
        : '${claimed.length} rewards claimed');
  }

  /// The VIP column is the thing being sold, so tapping a locked cell explains
  /// what's behind it and offers the way in — never a dead tap.
  Future<void> _offerVip(int level) async {
    final reward = passLevelAt(level)!.vip;
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('VIP reward'),
        content: Text(
          '${passRewardLabel(reward)} is on the VIP track of level $level.\n\n'
          'Subscribe and every VIP reward you have already walked past — this '
          'one included — unlocks right away.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Not now')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('See VIP')),
        ],
      ),
    );
    if (go == true && mounted) {
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const StoreScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Watch both: the track redraws on XP/claim changes, and the whole VIP
    // column flips state the moment a subscription lands.
    ref.watch(playerControllerProvider);
    final isVip = ref.watch(premiumControllerProvider).isVip;
    final controller = ref.read(playerControllerProvider.notifier);

    final season = controller.passSeason;
    final level = controller.passLevel;
    final xp = ref.read(playerControllerProvider).passXp;
    final claimable = controller.passClaimableCount;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Travel Pass'),
        actions: [
          if (!isVip)
            IconButton(
              tooltip: 'Get VIP',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const StoreScreen()),
              ),
              icon: const Icon(Icons.workspace_premium, color: Colors.amber),
            ),
        ],
      ),
      body: Column(
        children: [
          _SeasonHeader(
            season: season,
            level: level,
            xp: xp,
            fmt: _fmt,
            claimable: claimable,
            onClaimAll: _claimAll,
          ),
          if (!isVip) _VipStrip(onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const StoreScreen()),
              )),
          const _TrackLegend(),
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              itemExtent: _kRowExtent,
              itemCount: kPassLevelCount,
              padding: const EdgeInsets.only(bottom: 24),
              itemBuilder: (context, i) {
                final rung = i + 1;
                return _LevelRow(
                  entry: kPassTrack[i],
                  reached: level >= rung,
                  freeState: _stateFor(controller, rung,
                      vip: false, isVip: isVip, reached: level >= rung),
                  vipState: _stateFor(controller, rung,
                      vip: true, isVip: isVip, reached: level >= rung),
                  onClaimFree: () => _claim(rung, vip: false),
                  onClaimVip: () => _claim(rung, vip: true),
                  onOfferVip: () => _offerVip(rung),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  _CellState _stateFor(PlayerController controller, int level,
      {required bool vip, required bool isVip, required bool reached}) {
    final entry = kPassTrack[level - 1];
    if ((vip ? entry.vip : entry.free) == null) return _CellState.empty;
    if (controller.passRewardClaimed(level, vip: vip)) return _CellState.claimed;
    // "Keep walking" outranks "VIP only": a rung you haven't reached reads as
    // locked on BOTH columns. Otherwise every VIP cell to level 30 would offer
    // a subscription for a reward you haven't earned — and the offer copy
    // ("everything you have already walked past") would be a lie.
    if (!reached) return _CellState.locked;
    if (vip && !isVip) return _CellState.vipLocked;
    return _CellState.claimable;
  }
}

/// What a single reward cell is doing right now.
enum _CellState {
  /// No reward on this track at this level (free column only).
  empty,

  /// Earned but not taken yet.
  claimable,

  /// Already taken.
  claimed,

  /// The level isn't reached yet — keep walking.
  locked,

  /// Reachable, but the VIP entitlement is missing. Retro-claims on subscribe.
  vipLocked,
}

class _SeasonHeader extends StatelessWidget {
  const _SeasonHeader({
    required this.season,
    required this.level,
    required this.xp,
    required this.fmt,
    required this.claimable,
    required this.onClaimAll,
  });

  final PassSeason season;
  final int level;
  final int xp;
  final NumberFormat fmt;
  final int claimable;
  final Future<void> Function() onClaimAll;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final maxed = level >= kPassLevelCount;
    final daysLeft = season.daysLeftAt(DateTime.now());

    return Card(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 6),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(season.emoji, style: const TextStyle(fontSize: 24)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(season.name,
                      style: Theme.of(context).textTheme.titleMedium),
                ),
                Chip(
                  label: Text(daysLeft == 1 ? '1 day left' : '$daysLeft days left'),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('Level $level',
                    style: Theme.of(context).textTheme.headlineSmall),
                Text(' / $kPassLevelCount',
                    style: Theme.of(context).textTheme.titleSmall),
                const Spacer(),
                Text(
                  maxed
                      ? 'Track complete 🏁'
                      : '${fmt.format(passXpIntoLevel(xp))} / '
                          '${fmt.format(kPassLevelXp)} XP',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                  value: passLevelProgress(xp), minHeight: 10),
            ),
            const SizedBox(height: 8),
            Text(
              'Every step you walk is 1 XP — ${fmt.format(kPassLevelXp)} a level. '
              'Quests, spheres and devotions chip in a little too.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (claimable > 0) ...[
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: onClaimAll,
                icon: const Icon(Icons.redeem),
                label: Text(claimable == 1
                    ? 'Claim 1 reward'
                    : 'Claim all $claimable rewards'),
                style: FilledButton.styleFrom(
                  backgroundColor: scheme.primary,
                  minimumSize: const Size.fromHeight(44),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The upsell, shown only to non-VIPs. States the exact count so the offer is
/// concrete rather than "unlock more!".
class _VipStrip extends StatelessWidget {
  const _VipStrip({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 6),
      color: scheme.secondaryContainer,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              const Icon(Icons.workspace_premium, color: Colors.amber),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '$vipExclusiveItemCount cosmetics on the VIP track are '
                  'VIP-only. Subscribe any time — everything you have already '
                  'earned unlocks with it.',
                  style: TextStyle(
                      fontSize: 12, color: scheme.onSecondaryContainer),
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

class _TrackLegend extends StatelessWidget {
  const _TrackLegend();

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelSmall;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 2, 12, 6),
      child: Row(
        children: [
          const SizedBox(width: 44),
          Expanded(child: Center(child: Text('FREE', style: style))),
          Expanded(child: Center(child: Text('VIP', style: style))),
        ],
      ),
    );
  }
}

class _LevelRow extends StatelessWidget {
  const _LevelRow({
    required this.entry,
    required this.reached,
    required this.freeState,
    required this.vipState,
    required this.onClaimFree,
    required this.onClaimVip,
    required this.onOfferVip,
  });

  final PassLevel entry;
  final bool reached;
  final _CellState freeState;
  final _CellState vipState;
  final VoidCallback onClaimFree;
  final VoidCallback onClaimVip;
  final VoidCallback onOfferVip;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          // The rung marker — filled once you've reached this level.
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: reached ? scheme.primary : scheme.surfaceContainerHighest,
            ),
            child: Text(
              '${entry.level}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: reached ? scheme.onPrimary : scheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _RewardCell(
              reward: entry.free,
              state: freeState,
              onTap: onClaimFree,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _RewardCell(
              reward: entry.vip,
              state: vipState,
              vipTrack: true,
              onTap: vipState == _CellState.vipLocked ? onOfferVip : onClaimVip,
            ),
          ),
        ],
      ),
    );
  }
}

class _RewardCell extends StatelessWidget {
  const _RewardCell({
    required this.reward,
    required this.state,
    required this.onTap,
    this.vipTrack = false,
  });

  final PassReward? reward;
  final _CellState state;
  final VoidCallback onTap;
  final bool vipTrack;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final r = reward;
    if (r == null || state == _CellState.empty) {
      return Container(
        height: 76,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: scheme.outlineVariant, style: BorderStyle.solid),
          color: scheme.surface,
        ),
        alignment: Alignment.center,
        child: Text('—',
            style: TextStyle(color: scheme.outline, fontSize: 18)),
      );
    }

    final claimable = state == _CellState.claimable;
    final claimed = state == _CellState.claimed;
    final locked = state == _CellState.locked || state == _CellState.vipLocked;

    final background = claimable
        ? scheme.primaryContainer
        : claimed
            ? scheme.surfaceContainerHighest
            : scheme.surface;
    final border = claimable
        ? scheme.primary
        : state == _CellState.vipLocked
            ? Colors.amber
            : scheme.outlineVariant;

    return Semantics(
      button: claimable || state == _CellState.vipLocked,
      label: '${passRewardLabel(r)}, '
          '${claimed ? 'claimed' : claimable ? 'ready to claim' : state == _CellState.vipLocked ? 'VIP only' : 'locked'}',
      child: InkWell(
        onTap: (claimable || state == _CellState.vipLocked) ? onTap : null,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          height: 76,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: border, width: claimable ? 2 : 1),
            color: background,
          ),
          child: Stack(
            children: [
              Opacity(
                opacity: locked ? 0.45 : (claimed ? 0.6 : 1),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _RewardIcon(reward: r),
                      const SizedBox(height: 2),
                      Text(
                        passRewardLabel(r),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ],
                  ),
                ),
              ),
              if (claimed)
                Positioned(
                  top: 2,
                  right: 4,
                  child: Icon(Icons.check_circle,
                      size: 16, color: scheme.primary),
                ),
              if (state == _CellState.locked)
                Positioned(
                  top: 2,
                  right: 4,
                  child: Icon(Icons.lock_outline,
                      size: 14, color: scheme.onSurfaceVariant),
                ),
              if (state == _CellState.vipLocked)
                const Positioned(
                  top: 2,
                  right: 4,
                  child: Icon(Icons.workspace_premium,
                      size: 15, color: Colors.amber),
                ),
              if (claimable)
                Positioned(
                  bottom: 2,
                  right: 4,
                  child: Icon(Icons.redeem, size: 14, color: scheme.primary),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The reward's art: the real sprite for cosmetics (emoji until art is dropped
/// in — SpriteThumb handles that), a coin for Pebbles, a bolt for boosts.
class _RewardIcon extends StatelessWidget {
  const _RewardIcon({required this.reward});

  final PassReward reward;

  @override
  Widget build(BuildContext context) {
    switch (reward.kind) {
      case PassRewardKind.pebbles:
        return const Text('🪙', style: TextStyle(fontSize: 22));
      case PassRewardKind.boost:
        return const Text('⚡', style: TextStyle(fontSize: 22));
      case PassRewardKind.item:
        final item = passRewardItem(reward);
        if (item == null) return const Text('🎁', style: TextStyle(fontSize: 22));
        return SpriteThumb(item: item, size: 28);
    }
  }
}
