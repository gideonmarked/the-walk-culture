import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'cloud_sync_service.dart';

/// A friend or fellow group member, as the app needs to show them.
class SocialUser {
  const SocialUser({required this.id, this.username, this.accountCode, this.accepted = true});
  final String id;
  final String? username;
  final String? accountCode;
  final bool accepted; // false = a pending friend request
  String get display => (username?.isNotEmpty ?? false) ? username! : (accountCode ?? '—');
}

class Group {
  const Group({required this.id, required this.code, required this.name, required this.ownerId});
  final String id;
  final String code;
  final String name;
  final String ownerId;
}

/// The multiplayer social layer. Every method is a safe no-op / empty when the
/// backend isn't configured or the user is signed out, so the app runs the same
/// offline — the Social screen just shows an "offline" state instead of data.
///
/// NOTE: none of the server round-trips here can be verified with a single
/// device and no deployed backend. The account code shown on the Profile is
/// generated locally (see PlayerController) and is real; everything that needs a
/// second account activates once Supabase is live.
class SocialService {
  SocialService(this._ref);

  final Ref _ref;
  bool get _online => _ref.read(cloudSyncProvider).isReady;
  SupabaseClient get _db => Supabase.instance.client;

  /// Publish this device's username + locally-minted code to the server so
  /// others can find us. Adopts the server's code if it already assigned one.
  Future<void> upsertProfile({required String username, required String accountCode}) async {
    if (!_online) return;
    try {
      await _db.from('profile').upsert({
        'user_id': _db.auth.currentUser!.id,
        'username': username.isEmpty ? null : username,
        'account_code': accountCode.isEmpty ? null : accountCode,
      });
    } catch (e) {
      debugPrint('upsertProfile failed: $e');
    }
  }

  Future<List<SocialUser>> friends() async {
    if (!_online) return const [];
    try {
      final me = _db.auth.currentUser!.id;
      final rows = await _db
          .from('friendship')
          .select('friend_id, accepted, profile!friendship_friend_id_fkey(username, account_code)')
          .eq('user_id', me);
      return [
        for (final r in rows as List)
          SocialUser(
            id: r['friend_id'] as String,
            username: r['profile']?['username'] as String?,
            accountCode: r['profile']?['account_code'] as String?,
            accepted: r['accepted'] as bool? ?? false,
          ),
      ];
    } catch (e) {
      debugPrint('friends() failed: $e');
      return const [];
    }
  }

  /// Friend someone by their 7-char account code. Returns null on success, or a
  /// short error message to show ("no such code", etc).
  Future<String?> addFriendByCode(String code) async {
    if (!_online) return 'Sign in to add friends';
    try {
      await _db.rpc('send_friend_request', params: {'p_code': code});
      return null;
    } on PostgrestException catch (e) {
      return e.message;
    } catch (e) {
      return 'Could not send request';
    }
  }

  Future<String?> addFriendByUsername(String username) async {
    if (!_online) return 'Sign in to add friends';
    try {
      final row = await _db
          .from('profile')
          .select('account_code')
          .eq('username', username)
          .maybeSingle();
      final code = row?['account_code'] as String?;
      if (code == null) return 'No user "$username"';
      return addFriendByCode(code);
    } catch (e) {
      return 'Could not send request';
    }
  }

  Future<List<Group>> myGroups() async {
    if (!_online) return const [];
    try {
      final me = _db.auth.currentUser!.id;
      final rows = await _db
          .from('group_member')
          .select('groupe(id, code, name, owner_id)')
          .eq('user_id', me);
      return [
        for (final r in rows as List)
          if (r['groupe'] != null)
            Group(
              id: r['groupe']['id'] as String,
              code: r['groupe']['code'] as String,
              name: r['groupe']['name'] as String,
              ownerId: r['groupe']['owner_id'] as String,
            ),
      ];
    } catch (e) {
      debugPrint('myGroups() failed: $e');
      return const [];
    }
  }

  /// Create a group; the server charges the escalating slot cost from the
  /// wallet. Returns null on success or an error message (e.g. insufficient
  /// funds) to surface.
  Future<String?> createGroup(String name) async {
    if (!_online) return 'Sign in to create a group';
    try {
      await _db.rpc('create_group', params: {'p_name': name});
      return null;
    } on PostgrestException catch (e) {
      return e.message;
    } catch (e) {
      return 'Could not create group';
    }
  }

  Future<String?> joinGroup(String code) async {
    if (!_online) return 'Sign in to join a group';
    try {
      await _db.rpc('join_group', params: {'p_code': code});
      return null;
    } on PostgrestException catch (e) {
      return e.message;
    } catch (e) {
      return 'Could not join group';
    }
  }
}

final socialServiceProvider = Provider<SocialService>((ref) => SocialService(ref));
