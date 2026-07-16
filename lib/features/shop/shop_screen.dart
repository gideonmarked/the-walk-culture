import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/currency.dart';
import '../../data/shop_catalog.dart';
import '../../models/shop_item.dart';
import '../../state/app_providers.dart';
import '../../widgets/sprite_thumb.dart';
import '../../widgets/tier_icon.dart' show kTierColors;
import '../spheres/spheres_screen.dart' show kRarityColor, rarityLabel;

/// The accent colour for a price tier, but only for Gold and above — lower
/// tiers keep the default text colour so the premium ones stand out. Returns
/// null (no tint) below Gold.
Color? _tierAccent(String tier) {
  const goldIndex = 3; // Steps, Copper, Silver, Gold, ...
  return kTierNames.indexOf(tier) >= goldIndex ? kTierColors[tier] : null;
}

/// Category order in the shop — character items first (prioritised), then pets
/// and home.
const List<ItemSlot> _shopCategoryOrder = [
  ItemSlot.base,
  ItemSlot.hair,
  ItemSlot.face,
  ItemSlot.top,
  ItemSlot.bottom,
  ItemSlot.shoes,
  ItemSlot.hat,
  ItemSlot.accessory,
  ItemSlot.pet,
  ItemSlot.home,
];

class ShopScreen extends ConsumerStatefulWidget {
  const ShopScreen({super.key});

  @override
  ConsumerState<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends ConsumerState<ShopScreen> {
  ItemSlot? _filter; // null = All

  @override
  Widget build(BuildContext context) {
    final player = ref.watch(playerControllerProvider);
    final controller = ref.read(playerControllerProvider.notifier);
    final fmt = NumberFormat.decimalPattern();

    final all = kShopCatalog.where((i) => i.inShop).toList();
    final categories =
        _shopCategoryOrder.where((s) => all.any((i) => i.slot == s)).toList();
    final items =
        _filter == null ? all : all.where((i) => i.slot == _filter).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Shop')),
      body: Column(
        children: [
          // Category filter chips.
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              children: [
                _CategoryChip(
                  label: 'All',
                  selected: _filter == null,
                  onTap: () => setState(() => _filter = null),
                ),
                for (final slot in categories)
                  _CategoryChip(
                    label: slot.label,
                    selected: _filter == slot,
                    onTap: () => setState(() => _filter = slot),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final item = items[i];
                final owned = player.owned.contains(item.id);
                final tierUnlocked = item.tierUnlocked(player.spendableSteps);
                final affordable = item.purchasable(player.spendableSteps);
                final rarityColor = kRarityColor[item.rarity] ?? Colors.grey;

                return Card(
                  // Rarity reads at a glance from the card edge, matching the
                  // colour language of the Collection grid and sphere drops.
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: rarityColor, width: 1.5),
                  ),
                  child: ListTile(
                    leading: SpriteThumb(item: item, size: 40),
                    title: Text(item.name),
                    subtitle: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(text: '${item.slot.label} · '),
                          TextSpan(
                            text: rarityLabel(item.rarity),
                            style: TextStyle(
                              color: rarityColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          TextSpan(text: ' · ${fmt.format(item.priceAmount)} '),
                          // Tint the currency name for Gold and above, so the
                          // premium tiers (up to Diamond) pop off the shelf.
                          TextSpan(
                            text: item.priceTier,
                            style: TextStyle(
                              color: _tierAccent(item.priceTier),
                              fontWeight: _tierAccent(item.priceTier) != null
                                  ? FontWeight.w600
                                  : null,
                            ),
                          ),
                        ],
                      ),
                    ),
                    trailing: owned
                        ? const Chip(label: Text('Owned'))
                        // Haven't banked this rarity's currency yet — say which
                        // tier is missing rather than a dead, unexplained Buy.
                        : !tierUnlocked
                            ? Chip(
                                avatar: const Icon(Icons.lock_outline, size: 16),
                                label: Text('Needs ${item.requiredTier}'),
                                labelStyle: TextStyle(color: rarityColor),
                              )
                            : FilledButton(
                                onPressed: affordable
                                    ? () async {
                                        final ok = await controller.buy(item);
                                        if (ok && context.mounted) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            SnackBar(
                                                content: Text('Bought ${item.name}! '
                                                    'Equip it in Character or place it in your House.')),
                                          );
                                        }
                                      }
                                    : null,
                                child: const Text('Buy'),
                              ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip(
      {required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
      ),
    );
  }
}
