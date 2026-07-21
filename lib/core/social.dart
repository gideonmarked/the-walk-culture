/// Friends & groups — shareable codes and the group-slot pricing curve.
///
/// The multiplayer parts (who is whose friend, group membership) live on the
/// server; this file is just the pure, testable rules that both client and
/// server agree on.
library;

import 'dart:math';

/// Characters used in account/group codes. Deliberately excludes the ambiguous
/// ones (0/O, 1/I/L) so a code read aloud or off a screen can't be mistyped.
const String kCodeAlphabet = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';

/// Length of an account/group code, e.g. "A7A43B7".
const int kCodeLength = 7;

/// A random share code like "A7A43B7". Uniqueness is enforced by the database
/// (a unique column); on collision the server simply regenerates.
String generateCode([Random? rng]) {
  final r = rng ?? Random.secure();
  return String.fromCharCodes(
    List.generate(
        kCodeLength, (_) => kCodeAlphabet.codeUnitAt(r.nextInt(kCodeAlphabet.length))),
  );
}

/// Whether [code] is a well-formed share code (case-insensitive). Used to
/// validate pasted input before hitting the network.
bool isValidCode(String code) {
  final c = code.trim().toUpperCase();
  if (c.length != kCodeLength) return false;
  for (final unit in c.codeUnits) {
    if (!kCodeAlphabet.contains(String.fromCharCode(unit))) return false;
  }
  return true;
}

/// Normalise user-entered codes: trim + uppercase, so "a7a43b7" == "A7A43B7".
String normalizeCode(String code) => code.trim().toUpperCase();

// ---- Group creation pricing -------------------------------------------------

/// Step cost to create each successive group. Your FIRST group is free; the
/// 2nd and 3rd cost escalating amounts, and each further one doubles from there.
/// The curve is steep on purpose: grinding a 2nd/3rd group by walking is slow,
/// which nudges players toward buying a currency pack with real money.
const List<int> _kGroupSlotCosts = [
  0, // 1st group — free
  50000, // 2nd
  200000, // 3rd
  500000, // 4th
];

/// The cost to create your next group given how many you already own.
/// [ownedGroups] == 0 → free (your first). Beyond the table, keeps doubling.
int groupSlotCost(int ownedGroups) {
  if (ownedGroups < 0) return 0;
  if (ownedGroups < _kGroupSlotCosts.length) return _kGroupSlotCosts[ownedGroups];
  var cost = _kGroupSlotCosts.last;
  for (var i = _kGroupSlotCosts.length; i <= ownedGroups; i++) {
    cost *= 2;
  }
  return cost;
}

/// Max members a group can hold (server-enforced; here for UI copy).
const int kGroupMaxMembers = 20;
