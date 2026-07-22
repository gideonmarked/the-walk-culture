import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/social.dart';
import '../../services/cloud/cloud_sync_service.dart';
import '../../services/cloud/social_service.dart';
import '../../state/app_providers.dart';

/// Friends & Groups. Your account code and the group-cost preview work offline;
/// the friend graph and group membership need the backend (and a second
/// account) to do anything — shown as an "offline" banner until then.
class SocialScreen extends ConsumerStatefulWidget {
  const SocialScreen({super.key});

  @override
  ConsumerState<SocialScreen> createState() => _SocialScreenState();
}

class _SocialScreenState extends ConsumerState<SocialScreen> {
  final _fmt = NumberFormat.decimalPattern();

  List<SocialUser> _friends = const [];
  List<Group> _groups = const [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    if (!ref.read(cloudSyncProvider).isReady) return;
    setState(() => _loading = true);
    final social = ref.read(socialServiceProvider);
    final f = await social.friends();
    final g = await social.myGroups();
    if (!mounted) return;
    setState(() {
      _friends = f;
      _groups = g;
      _loading = false;
    });
  }

  void _toast(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(m)));
  }

  @override
  Widget build(BuildContext context) {
    final player = ref.watch(playerControllerProvider);
    final online = ref.watch(cloudSyncProvider).isReady;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Friends & Groups'),
          bottom: const TabBar(tabs: [
            Tab(icon: Icon(Icons.people_outline), text: 'Friends'),
            Tab(icon: Icon(Icons.groups_outlined), text: 'Groups'),
          ]),
        ),
        body: Column(
          children: [
            _AccountCodeCard(
              username: player.username,
              accountCode: player.accountCode,
              onCopy: () {
                Clipboard.setData(ClipboardData(text: player.accountCode));
                _toast('Code copied');
              },
              onEditName: () => _editUsername(player.username),
            ),
            if (!online) const _OfflineBanner(),
            Expanded(
              child: TabBarView(
                children: [
                  _FriendsTab(
                    friends: _friends,
                    online: online,
                    loading: _loading,
                    onAdd: _addFriend,
                  ),
                  _GroupsTab(
                    groups: _groups,
                    online: online,
                    ownedCount: _groups
                        .where((g) => g.ownerId != '' /* owner rows */)
                        .length,
                    fmt: _fmt,
                    onCreate: _createGroup,
                    onJoin: _joinGroup,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editUsername(String current) async {
    final ctrl = TextEditingController(text: current);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Choose a username'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLength: 20,
          decoration: const InputDecoration(hintText: 'e.g. StrollKing'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
              child: const Text('Save')),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    await ref.read(playerControllerProvider.notifier).setUsername(name);
    final p = ref.read(playerControllerProvider);
    await ref.read(socialServiceProvider)
        .upsertProfile(username: p.username, accountCode: p.accountCode);
    _toast('Username set to $name');
  }

  Future<void> _addFriend() async {
    final ctrl = TextEditingController();
    final entry = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add a friend'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(
            hintText: 'Account code (A7A43B7) or username',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
              child: const Text('Send request')),
        ],
      ),
    );
    if (entry == null || entry.isEmpty) return;
    final social = ref.read(socialServiceProvider);
    // A valid 7-char code is treated as a code; otherwise as a username.
    final err = isValidCode(entry)
        ? await social.addFriendByCode(normalizeCode(entry))
        : await social.addFriendByUsername(entry);
    _toast(err ?? 'Friend request sent');
    if (err == null) _refresh();
  }

  Future<void> _createGroup() async {
    final ctrl = TextEditingController();
    final ownedNow = _groups.length; // best-effort; server is authoritative
    final cost = groupSlotCost(ownedNow);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Create a group'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: ctrl,
              autofocus: true,
              maxLength: 24,
              decoration: const InputDecoration(hintText: 'Group name'),
            ),
            Text(cost == 0
                ? 'Your first group is free.'
                : 'This group costs ${_fmt.format(cost)} Pebbles.'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
              child: Text(cost == 0 ? 'Create (free)' : 'Create')),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    final err = await ref.read(socialServiceProvider).createGroup(name);
    _toast(err ?? 'Group "$name" created');
    if (err == null) _refresh();
  }

  Future<void> _joinGroup() async {
    final ctrl = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Join a group'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(hintText: 'Group code (7 characters)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
              child: const Text('Join')),
        ],
      ),
    );
    if (code == null || !isValidCode(code)) {
      if (code != null && code.isNotEmpty) _toast('That is not a valid 7-character code');
      return;
    }
    final err = await ref.read(socialServiceProvider).joinGroup(normalizeCode(code));
    _toast(err ?? 'Joined the group');
    if (err == null) _refresh();
  }
}

class _AccountCodeCard extends StatelessWidget {
  const _AccountCodeCard(
      {required this.username,
      required this.accountCode,
      required this.onCopy,
      required this.onEditName});
  final String username;
  final String accountCode;
  final VoidCallback onCopy;
  final VoidCallback onEditName;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(username.isEmpty ? 'No username yet' : username,
                          style: Theme.of(context).textTheme.titleMedium),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        onPressed: onEditName,
                        icon: const Icon(Icons.edit, size: 18),
                      ),
                    ],
                  ),
                  Text('Your code', style: Theme.of(context).textTheme.bodySmall),
                  SelectableText(
                    accountCode.isEmpty ? '…' : accountCode,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          letterSpacing: 3,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                  ),
                ],
              ),
            ),
            IconButton.filledTonal(
                onPressed: onCopy, icon: const Icon(Icons.copy)),
          ],
        ),
      ),
    );
  }
}

class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner();
  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      color: s.surfaceContainerHighest,
      padding: const EdgeInsets.all(10),
      child: Text(
        'Offline — share your code now; friends and groups sync once you’re '
        'signed in to the backend.',
        style: TextStyle(color: s.onSurfaceVariant, fontSize: 12),
        textAlign: TextAlign.center,
      ),
    );
  }
}

class _FriendsTab extends StatelessWidget {
  const _FriendsTab(
      {required this.friends,
      required this.online,
      required this.loading,
      required this.onAdd});
  final List<SocialUser> friends;
  final bool online;
  final bool loading;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        if (loading)
          const LinearProgressIndicator()
        else if (friends.isEmpty)
          _Empty(
            icon: Icons.people_outline,
            text: online
                ? 'No friends yet. Add someone by their code or username.'
                : 'Add friends once you’re signed in.',
          )
        else
          ListView(
            padding: const EdgeInsets.only(bottom: 88),
            children: [
              for (final f in friends)
                ListTile(
                  leading: CircleAvatar(child: Text(f.display.characters.first)),
                  title: Text(f.display),
                  subtitle: Text(f.accepted ? (f.accountCode ?? '') : 'Request pending'),
                  trailing: f.accepted ? null : const Icon(Icons.hourglass_top, size: 18),
                ),
            ],
          ),
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton.extended(
            onPressed: onAdd,
            icon: const Icon(Icons.person_add),
            label: const Text('Add friend'),
          ),
        ),
      ],
    );
  }
}

class _GroupsTab extends StatelessWidget {
  const _GroupsTab(
      {required this.groups,
      required this.online,
      required this.ownedCount,
      required this.fmt,
      required this.onCreate,
      required this.onJoin});
  final List<Group> groups;
  final bool online;
  final int ownedCount;
  final NumberFormat fmt;
  final VoidCallback onCreate;
  final VoidCallback onJoin;

  @override
  Widget build(BuildContext context) {
    final nextCost = groupSlotCost(groups.length);
    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Group slots',
                        style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 4),
                    const Text('Your first group is free. Each next one costs more:'),
                    const SizedBox(height: 6),
                    Text('2nd · ${fmt.format(groupSlotCost(1))} Pebbles'),
                    Text('3rd · ${fmt.format(groupSlotCost(2))} Pebbles'),
                    Text('4th · ${fmt.format(groupSlotCost(3))} Pebbles'),
                    const SizedBox(height: 6),
                    Text(
                      nextCost == 0
                          ? 'Your next group is free.'
                          : 'Your next group costs ${fmt.format(nextCost)} Pebbles.',
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
            if (groups.isEmpty)
              _Empty(
                icon: Icons.groups_outlined,
                text: online
                    ? 'You’re not in a group yet.'
                    : 'Create or join groups once you’re signed in.',
              )
            else
              for (final g in groups)
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.groups),
                    title: Text(g.name),
                    subtitle: Text('Code ${g.code}  ·  tap for the group house'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => _GroupHousePlaceholder(group: g),
                    )),
                  ),
                ),
          ],
        ),
        Positioned(
          right: 16,
          bottom: 16,
          child: Row(
            children: [
              FloatingActionButton.extended(
                heroTag: 'join',
                onPressed: onJoin,
                icon: const Icon(Icons.login),
                label: const Text('Join'),
              ),
              const SizedBox(width: 12),
              FloatingActionButton.extended(
                heroTag: 'create',
                onPressed: onCreate,
                icon: const Icon(Icons.add),
                label: const Text('Create'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The shared group house — a placeholder that already frames the mechanic:
/// members expand and furnish it with their OWN currency.
class _GroupHousePlaceholder extends StatelessWidget {
  const _GroupHousePlaceholder({required this.group});
  final Group group;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${group.name} — House')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🏠', style: TextStyle(fontSize: 64)),
              const SizedBox(height: 12),
              Text('Group House', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(
                'A shared home for ${group.name}. Every member chips in with '
                'their own steps to expand it and place furniture. Coming soon.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 48, color: Theme.of(context).disabledColor),
          const SizedBox(height: 12),
          Text(text, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
