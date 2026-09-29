// Generates the art manifest — every sprite that has to exist, which ones do,
// and the order worth drawing them in — from the single source of truth,
// lib/data/shop_catalog.dart.
//
//   dart run tool/art_manifest.dart              > docs/ART_MANIFEST.md
//   dart run tool/art_manifest.dart --html       > /tmp/art_manifest.html
//
// Run from the repo root: file-existence checks resolve `assets/...` relative
// to the working directory, and that's what fills in the ✅/☐ column.
//
// Regenerate after any change to the catalog. A hand-written list goes stale
// the first time a cosmetic is added — which already happened once, when the
// 17 Travel Pass items landed and no art doc mentioned them.

import 'dart:io';

import 'package:step_quest/data/pass_catalog.dart';
import 'package:step_quest/data/shop_catalog.dart';
import 'package:step_quest/models/shop_item.dart';

/// Colour words the generated catalog uses. Mirrors `_kVariants`.
const List<String> kVariants = [
  'Crimson', 'Amber', 'Emerald', 'Azure', 'Violet',
  'Onyx', 'Ivory', 'Rose', 'Slate', 'Golden',
];

bool _exists(ShopItem i) => File(i.asset).existsSync();

String _canvas(ShopItem i) => i.isTight
    ? 'tight ${i.w.toInt()}×${i.h.toInt()} @ ${i.x.toInt()},${i.y.toInt()}'
    : (i.onStage ? '96 stage' : '64 sheet');

/// A generated style: one drawing, ten exported files.
class _Shape {
  _Shape(this.slot, this.noun);
  final ItemSlot slot;
  final String noun;
  final List<ShopItem> items = [];

  /// `gen_top_tee_` — the shared prefix of this shape's ten files.
  String get idPrefix {
    final id = items.first.id;
    return id.substring(0, id.lastIndexOf('_') + 1);
  }

  int get present => items.where(_exists).length;
}

void main(List<String> args) {
  final html = args.contains('--html');

  final handmade = kShopCatalog.where((i) => !i.id.startsWith('gen_')).toList();
  final generated = kShopCatalog.where((i) => i.id.startsWith('gen_')).toList();

  // One _Shape per distinct drawing: the name is "<Colour> <Noun>", so the noun
  // is everything after the first word.
  final shapes = <String, _Shape>{};
  for (final item in generated) {
    final noun = item.name.split(' ').skip(1).join(' ');
    shapes
        .putIfAbsent('${item.slot.name}|$noun', () => _Shape(item.slot, noun))
        .items
        .add(item);
  }

  final bases = handmade.where((i) => i.slot == ItemSlot.base).toList();
  final pass = kPassCatalog.toList();
  final passIds = {for (final i in pass) i.id};

  // "First week": what a player can actually reach before they'd quit. The shop
  // gates on wallet tier, so early money is Pebbles and Copper — Common and
  // Uncommon. Everything rarer is invisible to a new player.
  final firstWeek = handmade
      .where((i) =>
          i.slot != ItemSlot.base &&
          !passIds.contains(i.id) &&
          (i.rarity == Rarity.common || i.rarity == Rarity.uncommon))
      .toList();
  final firstWeekIds = {for (final i in firstWeek) i.id};

  final later = handmade
      .where((i) =>
          i.slot != ItemSlot.base &&
          !passIds.contains(i.id) &&
          !firstWeekIds.contains(i.id))
      .toList();

  final totalFiles = kShopCatalog.length;
  final drawnFiles = kShopCatalog.where(_exists).length;
  final drawings = handmade.length + shapes.length;

  final out = StringBuffer();
  final w = html ? _HtmlWriter(out) : _MarkdownWriter(out);

  w.docStart('Art Manifest — The Walk Culture');
  w.p('**GENERATED** by `tool/art_manifest.dart` — do not edit by hand. '
      'Regenerate with `dart run tool/art_manifest.dart > docs/ART_MANIFEST.md` '
      'after any change to `lib/data/shop_catalog.dart`.');

  w.h2('Where things stand');
  w.p('**$drawnFiles of $totalFiles files** exist today. But $totalFiles is the '
      'wrong number to plan against: ${generated.length} of them are colour '
      'variants of just ${shapes.length} shapes, so the real workload is about '
      '**$drawings distinct drawings** — ${handmade.length} hand-authored plus '
      '${shapes.length} generated shapes, each exported in '
      '${kVariants.length} colours.');
  w.table(['Slot', 'Files', 'Drawn', 'Drawings needed'], [
    for (final slot in ItemSlot.values)
      () {
        final all = kShopCatalog.where((i) => i.slot == slot).toList();
        final hand = all.where((i) => !i.id.startsWith('gen_')).length;
        final shapeCount =
            shapes.values.where((s) => s.slot == slot).length;
        return [
          slot.label,
          '${all.length}',
          '${all.where(_exists).length}',
          '${hand + shapeCount}',
        ];
      }(),
  ]);

  w.h2('Rules that apply to every sprite');
  w.list([
    '**64×64** if it is worn on the body; **96×96 stage** if it stands beside '
        'him (pets, floor props). Transparent RGBA, no anti-aliasing.',
    'Upright anchors: crown **y3**, shoulders **y28**, ankles **y57**, centre '
        '**x32**. Ground line for stage props: **y88**, clear of the figure\'s '
        'column (x34–61).',
    'Light source top-left, shadows bottom-right. Skin and hair are 3 shades '
        '+ outline from the ramp.',
    'The filename must match the catalog `id` exactly — that is the only link '
        'between art and code. Drop the PNG at the path in these tables and it '
        'appears; no code change.',
    'Full detail, palettes and the Aseprite pipeline: `docs/PIXEL_ART_GUIDE.md` '
        'and `docs/ASSETS.md`.',
  ]);
  w.note('**Health poses are not wired yet.** The guide\'s `_0`…`_6` pose '
      'suffixes are a planned contract; today the compositor loads one standing '
      'body per skin tone (`base_medium.png`, no suffix). Pose art drawn now '
      'would not be loaded by anything until that lands — so it is deliberately '
      'left out of the tables below.');

  w.h2('Draw in this order');
  w.list([
    '**P0 — Skin tones (${bases.length}).** '
        '${bases.where(_exists).length} of ${bases.length} done. Everything '
        'else is drawn on top of these, so they come first.',
    '**P1 — First week (${firstWeek.length}).** Common and Uncommon cosmetics: '
        'the only things a new player can afford, because the shop gates on '
        'banked wallet tier. If a tester quits in week one, this is all they '
        'ever saw.',
    '**P2 — Travel Pass (${pass.length}).** Seasonal track exclusives — '
        '${pass.where((i) => !i.id.startsWith('pass_vip_')).length} free, '
        '${pass.where((i) => i.id.startsWith('pass_vip_')).length} VIP-only. '
        'The VIP dozen is the thing a subscription actually buys, so an emoji '
        'placeholder there is the most expensive placeholder in the app.',
    '**P3 — Generated shapes (${shapes.length} → ${generated.length} files).** '
        'One drawing each, palette-swapped into ${kVariants.length} colours. '
        'Cheapest coverage per hour of work by a wide margin.',
    '**P4 — Rare and prestige (${later.length}).** Rare through Celestial. '
        'Aspirational flex items nobody sees for weeks.',
  ]);

  void itemTable(String title, List<ShopItem> items, {String? blurb}) {
    if (items.isEmpty) return;
    w.h3('$title — ${items.where(_exists).length}/${items.length}');
    if (blurb != null) w.p(blurb);
    final bySlot = <ItemSlot, List<ShopItem>>{};
    for (final i in items) {
      bySlot.putIfAbsent(i.slot, () => []).add(i);
    }
    for (final slot in ItemSlot.values) {
      final group = bySlot[slot];
      if (group == null || group.isEmpty) continue;
      w.h4('${slot.label} (${group.length})');
      w.table(['', 'Name', 'File', 'Canvas', 'Rarity'], [
        for (final i in group)
          [
            _exists(i) ? 'DONE' : 'TODO',
            i.name,
            i.asset,
            _canvas(i),
            i.rarity.name,
          ],
      ]);
    }
  }

  w.h2('P0 — Skin tones');
  w.table(['', 'Name', 'File', 'Canvas'], [
    for (final i in bases) [_exists(i) ? 'DONE' : 'TODO', i.name, i.asset, _canvas(i)],
  ]);

  w.h2('P1 — First week');
  itemTable('Common and Uncommon', firstWeek,
      blurb: 'Priced in Pebbles and Copper, so they are on the shelves from '
          'day one. Draw these before anything rarer.');

  w.h2('P2 — Travel Pass exclusives');
  itemTable(
      'Free track',
      pass.where((i) => !i.id.startsWith('pass_vip_')).toList(),
      blurb: 'Earned on the free column at levels 5, 12, 20, 25 and 30.');
  itemTable('VIP track', pass.where((i) => i.id.startsWith('pass_vip_')).toList(),
      blurb: 'VIP-only. These are what the subscription sells.');

  w.h2('P3 — Generated shapes');
  w.p('One drawing per row, exported ${kVariants.length} times with the palette '
      'swapped. The colour words are the same for every shape: '
      '${kVariants.join(', ')}.');
  w.p('Files follow `<prefix><colour>.png`, lowercase — e.g. '
      '`${shapes.values.first.idPrefix}${kVariants.first.toLowerCase()}.png`.');
  final byShapeSlot = <ItemSlot, List<_Shape>>{};
  for (final s in shapes.values) {
    byShapeSlot.putIfAbsent(s.slot, () => []).add(s);
  }
  for (final slot in ItemSlot.values) {
    final group = byShapeSlot[slot];
    if (group == null || group.isEmpty) continue;
    w.h4('${slot.label} (${group.length} shapes → ${group.length * kVariants.length} files)');
    w.table(['', 'Shape', 'Folder', 'File prefix'], [
      for (final s in group)
        [
          '${s.present}/${s.items.length}',
          s.noun,
          'assets/${s.slot.assetFolder}/',
          '${s.idPrefix}<colour>.png',
        ],
    ]);
  }

  w.h2('P4 — Rare and prestige');
  itemTable('Rare through Celestial', later,
      blurb: 'Gated behind Silver, Gold, Titanium and above. Weeks of walking '
          'away for most players.');

  w.docEnd();
  stdout.write(out.toString());
}

// ---------------------------------------------------------------------------
// Two writers, one document. Markdown for the repo, HTML for printing to PDF —
// same data, so the two can't disagree.
// ---------------------------------------------------------------------------

abstract class _Writer {
  void docStart(String title);
  void docEnd();
  void h2(String s);
  void h3(String s);
  void h4(String s);
  void p(String s);
  void note(String s);
  void list(List<String> items);
  void table(List<String> headers, List<List<String>> rows);
}

class _MarkdownWriter implements _Writer {
  _MarkdownWriter(this.b);
  final StringBuffer b;

  @override
  void docStart(String title) => b.writeln('# $title\n');
  @override
  void docEnd() {}
  @override
  void h2(String s) => b.writeln('\n---\n\n## $s\n');
  @override
  void h3(String s) => b.writeln('\n### $s\n');
  @override
  void h4(String s) => b.writeln('\n#### $s\n');
  @override
  void p(String s) => b.writeln('$s\n');
  @override
  void note(String s) => b.writeln('> $s\n');
  @override
  void list(List<String> items) {
    for (final i in items) {
      b.writeln('- $i');
    }
    b.writeln();
  }

  @override
  void table(List<String> headers, List<List<String>> rows) {
    String cell(String s) => s.replaceAll('|', '\\|');
    b.writeln('| ${headers.map(cell).join(' | ')} |');
    b.writeln('|${headers.map((_) => '---').join('|')}|');
    for (final row in rows) {
      final cells = [
        for (var i = 0; i < row.length; i++)
          // Filenames read better as code; the status column as a box.
          if (headers[i] == 'File' || headers[i] == 'File prefix' ||
              headers[i] == 'Folder')
            '`${cell(row[i])}`'
          else if (headers[i].isEmpty)
            row[i] == 'DONE' ? '✅' : (row[i] == 'TODO' ? '☐' : row[i])
          else
            cell(row[i]),
      ];
      b.writeln('| ${cells.join(' | ')} |');
    }
    b.writeln();
  }
}

class _HtmlWriter implements _Writer {
  _HtmlWriter(this.b);
  final StringBuffer b;

  String _esc(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;');

  /// Minimal inline markdown — `code` and **bold** — so both writers can share
  /// the same source strings.
  String _inline(String s) {
    var out = _esc(s);
    out = out.replaceAllMapped(
        RegExp(r'`([^`]+)`'), (m) => '<code>${m[1]}</code>');
    out = out.replaceAllMapped(
        RegExp(r'\*\*([^*]+)\*\*'), (m) => '<strong>${m[1]}</strong>');
    return out;
  }

  @override
  void docStart(String title) {
    b.writeln('''<!doctype html>
<html lang="en"><head><meta charset="utf-8">
<title>${_esc(title)}</title>
<style>
  @page { size: A4; margin: 14mm 12mm; }
  :root { --ink:#1a1a1a; --mut:#666; --line:#d8d8d8; --accent:#7C4DFF; --done:#1b8a3f; }
  * { box-sizing: border-box; }
  body { font: 10pt/1.45 -apple-system, "Segoe UI", Roboto, sans-serif;
         color: var(--ink); margin: 0; }
  h1 { font-size: 20pt; margin: 0 0 2mm; letter-spacing: -0.3px; }
  h2 { font-size: 13pt; margin: 9mm 0 2mm; padding-top: 2mm;
       border-top: 2px solid var(--accent); break-after: avoid; }
  h3 { font-size: 11pt; margin: 5mm 0 1.5mm; break-after: avoid; }
  h4 { font-size: 9.5pt; margin: 4mm 0 1mm; color: var(--mut);
       text-transform: uppercase; letter-spacing: .5px; break-after: avoid; }
  p { margin: 0 0 2.5mm; }
  ul { margin: 0 0 3mm; padding-left: 5mm; }
  li { margin-bottom: 1.2mm; }
  code { font: 8.5pt ui-monospace, "SF Mono", Menlo, Consolas, monospace;
         background: #f3f1fa; padding: 0.4mm 1mm; border-radius: 2px; }
  table { width: 100%; border-collapse: collapse; margin: 0 0 4mm;
          font-size: 8.5pt; break-inside: auto; table-layout: fixed; }
  td code { word-break: break-all; }
  thead { display: table-header-group; }
  tr { break-inside: avoid; }
  th { text-align: left; font-size: 7.5pt; text-transform: uppercase;
       letter-spacing: .4px; color: var(--mut); border-bottom: 1px solid var(--ink);
       padding: 1mm 1.5mm; }
  td { padding: 1mm 1.5mm; border-bottom: 1px solid var(--line);
       vertical-align: top; }
  td.status { width: 9mm; text-align: center; font-weight: 700; }
  .done { color: var(--done); }
  .todo { color: #bbb; }
  .note { background: #f7f5ff; border-left: 3px solid var(--accent);
          padding: 2.5mm 3mm; margin: 0 0 3mm; }
  .sub { color: var(--mut); font-size: 8.5pt; margin: -1mm 0 4mm; }
</style></head><body>
<h1>${_esc(title)}</h1>''');
  }

  @override
  void docEnd() => b.writeln('</body></html>');
  @override
  void h2(String s) => b.writeln('<h2>${_inline(s)}</h2>');
  @override
  void h3(String s) => b.writeln('<h3>${_inline(s)}</h3>');
  @override
  void h4(String s) => b.writeln('<h4>${_inline(s)}</h4>');
  @override
  void p(String s) => b.writeln('<p>${_inline(s)}</p>');
  @override
  void note(String s) => b.writeln('<p class="note">${_inline(s)}</p>');
  @override
  void list(List<String> items) {
    b.writeln('<ul>');
    for (final i in items) {
      b.writeln('<li>${_inline(i)}</li>');
    }
    b.writeln('</ul>');
  }

  /// Fixed column widths so every table on the page lines up. Independently
  /// sized tables read as ragged in a printed handoff, and this doc is mostly
  /// tables.
  static const Map<String, String> _colWidth = {
    '': '9mm',
    'Name': '36mm',
    'Shape': '36mm',
    'Slot': '32mm',
    'Canvas': '26mm',
    'Rarity': '22mm',
    'Files': '20mm',
    'Drawn': '20mm',
    'Drawings needed': '30mm',
    'Folder': '46mm',
    // 'File' / 'File prefix' deliberately absent: they take the remainder.
  };

  @override
  void table(List<String> headers, List<List<String>> rows) {
    b.writeln('<table><colgroup>');
    for (final h in headers) {
      final width = _colWidth[h];
      b.writeln(width == null ? '<col>' : '<col style="width:$width">');
    }
    b.writeln('</colgroup><thead><tr>');
    for (final h in headers) {
      b.writeln('<th>${_esc(h)}</th>');
    }
    b.writeln('</tr></thead><tbody>');
    for (final row in rows) {
      b.writeln('<tr>');
      for (var i = 0; i < row.length; i++) {
        final v = row[i];
        if (headers[i].isEmpty) {
          if (v == 'DONE') {
            b.writeln('<td class="status done">&#10003;</td>');
          } else if (v == 'TODO') {
            b.writeln('<td class="status todo">&#9633;</td>');
          } else {
            b.writeln('<td class="status">${_esc(v)}</td>');
          }
        } else if (headers[i] == 'File' ||
            headers[i] == 'File prefix' ||
            headers[i] == 'Folder') {
          b.writeln('<td><code>${_esc(v)}</code></td>');
        } else {
          b.writeln('<td>${_esc(v)}</td>');
        }
      }
      b.writeln('</tr>');
    }
    b.writeln('</tbody></table>');
  }
}
