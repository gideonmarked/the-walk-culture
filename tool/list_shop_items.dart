// Dumps every catalogue item and the sprite file it expects.
//
// Most of the catalogue is generated at runtime (`_generatedCatalog()` builds
// 50 styles x 10 colour variants), so the full item list exists nowhere you can
// read it — not in the source, not on disk. This prints it, and flags which
// sprites are still missing, so art can be worked through slot by slot.
//
//     dart run tool/list_shop_items.dart            # markdown, grouped by slot
//     dart run tool/list_shop_items.dart --json     # machine-readable
//     dart run tool/list_shop_items.dart --missing  # only items lacking art
//
// Re-run after editing the catalog. Paths come from `ShopItem.asset`, so this
// stays true to whatever the app actually loads.

import 'dart:convert';
import 'dart:io';

import 'package:step_quest/data/shop_catalog.dart';
import 'package:step_quest/models/shop_item.dart';

void main(List<String> args) {
  final asJson = args.contains('--json');
  final onlyMissing = args.contains('--missing');

  final items = [...kShopCatalog]..sort((a, b) {
      final bySlot = a.slot.index.compareTo(b.slot.index);
      return bySlot != 0 ? bySlot : a.id.compareTo(b.id);
    });

  bool hasArt(ShopItem i) => File(i.asset).existsSync();

  final shown = onlyMissing ? items.where((i) => !hasArt(i)).toList() : items;

  if (asJson) {
    stdout.writeln(const JsonEncoder.withIndent('  ').convert([
      for (final i in shown)
        {
          'id': i.id,
          'name': i.name,
          'emoji': i.emoji,
          'slot': i.slot.name,
          'rarity': i.rarity.name,
          'price': '${i.priceAmount} ${i.priceTier}',
          'asset': i.asset,
          'hasArt': hasArt(i),
          'inShop': i.inShop,
        }
    ]));
    return;
  }

  final done = items.where(hasArt).length;
  stdout.writeln('# Shop items — sprite checklist\n');
  stdout.writeln('${items.length} items, $done with art, '
      '${items.length - done} to draw.\n');

  for (final slot in ItemSlot.values) {
    final inSlot = shown.where((i) => i.slot == slot).toList();
    if (inSlot.isEmpty) continue;
    final slotDone = items.where((i) => i.slot == slot && hasArt(i)).length;
    final slotAll = items.where((i) => i.slot == slot).length;
    stdout.writeln('\n## ${slot.label}  ($slotDone/$slotAll)');
    stdout.writeln('`assets/${slot.assetFolder}/`\n');
    stdout.writeln('| | file | item | rarity | price |');
    stdout.writeln('|---|---|---|---|---|');
    for (final i in inSlot) {
      final mark = hasArt(i) ? '[x]' : '[ ]';
      final file = i.asset.split('/').last;
      stdout.writeln('| $mark | `$file` | ${i.emoji} ${i.name} | '
          '${i.rarity.name} | ${i.priceAmount} ${i.priceTier} |');
    }
  }
}
