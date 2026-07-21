import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A single day's gratitude entry.
class GratitudeEntry {
  const GratitudeEntry({required this.date, required this.items});
  final String date; // 'y-m-d'
  final List<String> items;

  Map<String, dynamic> toJson() => {'date': date, 'items': items};
  factory GratitudeEntry.fromJson(Map<String, dynamic> j) => GratitudeEntry(
        date: j['date'] as String? ?? '',
        items:
            ((j['items'] as List?) ?? const []).map((e) => e.toString()).toList(),
      );
}

/// On-device gratitude journal.
///
/// PRIVACY BY DESIGN: what you write here is personal religious reflection — a
/// special category of data under GDPR and similar laws. So it lives in ITS OWN
/// SharedPreferences key and is NEVER put into the player save that syncs to the
/// backend. Uninstalling the app erases it; nothing is uploaded. Keep it that
/// way unless you add explicit, separate consent for cloud-storing reflections.
class GratitudeJournal extends StateNotifier<List<GratitudeEntry>> {
  GratitudeJournal() : super(const []) {
    _load();
  }

  static const _key = 'twc_gratitude_journal_v1'; // local only, not synced

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return;
    try {
      final list = (jsonDecode(raw) as List)
          .map((e) => GratitudeEntry.fromJson(e as Map<String, dynamic>))
          .toList();
      state = list;
    } catch (_) {/* ignore a corrupt local journal */}
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _key, jsonEncode(state.map((e) => e.toJson()).toList()));
  }

  /// Save (or replace) today's entry. Newest first.
  Future<void> addEntry(String date, List<String> items) async {
    final cleaned = items.map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    state = [
      GratitudeEntry(date: date, items: cleaned),
      ...state.where((e) => e.date != date),
    ];
    await _save();
  }

  /// Wipe the journal (offered in the screen — the user owns this data).
  Future<void> clear() async {
    state = const [];
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}

final gratitudeJournalProvider =
    StateNotifierProvider<GratitudeJournal, List<GratitudeEntry>>(
        (ref) => GratitudeJournal());
