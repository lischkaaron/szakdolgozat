import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/friend.dart';
import '../../models/group.dart';
import '../../services/api_client.dart';
import '../../services/friends_service.dart';
import '../../services/groups_service.dart';
import '../../widgets/app_widgets.dart';
import 'community_dialogs.dart';

// ---------------------------------------------------------------------------
//  KÖZÖSSÉG -> CSOPORTOK fül
//  Csoport létrehozása, átnevezése, törlése és a tagság kezelése a backend
//  `/api/groups` végpontjaival (valós adatokkal).
// ---------------------------------------------------------------------------
class GroupsTab extends StatefulWidget {
  const GroupsTab({super.key});

  @override
  State<GroupsTab> createState() => _GroupsTabState();
}

class _GroupsTabState extends State<GroupsTab> {
  List<BikeGroup> _groups = const <BikeGroup>[];
  List<Friend> _friends = const <Friend>[];

  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  GroupsService get _groupsService => context.read<GroupsService>();

  Future<void> _load() async {
    final groupsService = _groupsService;
    final friendsService = context.read<FriendsService>();

    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final groups = await groupsService.fetchGroups();

      // A barátlista csak a tagfelvételhez kell; ha nem jön be, a csoportok
      // akkor is megjeleníthetők.
      List<Friend> friends = const <Friend>[];
      try {
        friends = await friendsService.fetchFriends();
      } on ApiException {
        friends = const <Friend>[];
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _groups = groups;
        _friends = friends;
        _loading = false;
      });
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _error = error.message;
        _loading = false;
      });
    }
  }

  /// Módosító művelet végrehajtása, majd a lista újratöltése.
  Future<bool> _run(
    Future<void> Function() action,
    String successMessage,
  ) async {
    if (_busy) {
      return false;
    }

    setState(() => _busy = true);

    try {
      await action();
      if (!mounted) {
        return true;
      }
      showCommunityMessage(context, successMessage);
      await _load();
      return true;
    } on ApiException catch (error) {
      if (!mounted) {
        return false;
      }
      showCommunityMessage(context, error.message, isError: true);
      return false;
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _createGroup() async {
    final draft = await showGroupEditorDialog(context, title: 'Új csoport');
    if (draft == null) {
      return;
    }

    await _run(
      () => _groupsService.createGroup(
        name: draft.name,
        description: draft.description,
      ),
      'Csoport létrehozva: ${draft.name}',
    );
  }

  Future<void> _editGroup(BikeGroup group) async {
    final draft = await showGroupEditorDialog(
      context,
      title: 'Csoport szerkesztése',
      initialName: group.name,
      initialDescription: group.description,
    );

    if (draft == null) {
      return;
    }

    await _run(
      () => _groupsService.updateGroup(
        group.id,
        name: draft.name,
        description: draft.description,
      ),
      'Csoport frissítve: ${draft.name}',
    );
  }

  Future<void> _deleteGroup(BikeGroup group) async {
    final confirmed = await confirmCommunityAction(
      context,
      title: 'Csoport törlése',
      message:
          'Biztosan törlöd a(z) ${group.name} csoportot? A tagság is törlődik.',
    );

    if (!confirmed) {
      return;
    }

    await _run(
      () => _groupsService.deleteGroup(group.id),
      'Csoport törölve: ${group.name}',
    );
  }

  Future<void> _addMember(BikeGroup group) async {
    final memberIds = group.members.map((member) => member.userId).toSet();
    final candidates = _friends
        .where((friend) => !memberIds.contains(friend.id))
        .toList();

    if (candidates.isEmpty) {
      showCommunityMessage(
        context,
        'Nincs olyan barátod, aki még nem tagja ennek a csoportnak.',
      );
      return;
    }

    final friend = await showAddGroupMemberDialog(
      context,
      groupName: group.name,
      candidates: candidates,
    );

    if (friend == null) {
      return;
    }

    await _run(
      () => _groupsService.addMember(group.id, userId: friend.id),
      '${friend.displayName} hozzáadva: ${group.name}',
    );
  }

  Future<void> _removeMember(BikeGroup group, GroupMember member) async {
    final confirmed = await confirmCommunityAction(
      context,
      title: 'Tag eltávolítása',
      message:
          'Biztosan eltávolítod ${member.displayName} tagot a(z) ${group.name} csoportból?',
      confirmLabel: 'ELTÁVOLÍTÁS',
    );

    if (!confirmed) {
      return;
    }

    await _run(
      () => _groupsService.removeMember(group.id, member.userId),
      '${member.displayName} eltávolítva a csoportból.',
    );
  }

  Future<void> _leaveGroup(BikeGroup group) async {
    final self = group.selfMember;

    if (self == null) {
      showCommunityMessage(
        context,
        'Nem található a tagságod ebben a csoportban.',
        isError: true,
      );
      return;
    }

    final confirmed = await confirmCommunityAction(
      context,
      title: 'Kilépés a csoportból',
      message: 'Biztosan kilépsz a(z) ${group.name} csoportból?',
      confirmLabel: 'KILÉPÉS',
    );

    if (!confirmed) {
      return;
    }

    await _run(
      () => _groupsService.removeMember(group.id, self.userId),
      'Kiléptél: ${group.name}',
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return ErrorRetryView(message: _error!, onRetry: _load);
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildCreateCard(),
          const SizedBox(height: 20),
          SectionTitle('Csoportjaim (${_groups.length})'),
          if (_groups.isEmpty)
            Card(
              color: Colors.white,
              elevation: 2,
              margin: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  'Még nincs csoportod. Hozz létre egyet, majd add hozzá '
                  'a barátaidat!',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            )
          else
            for (final group in _groups) ...[
              _GroupCard(
                group: group,
                busy: _busy,
                onAddMember: () => _addMember(group),
                onEdit: () => _editGroup(group),
                onDelete: () => _deleteGroup(group),
                onLeave: () => _leaveGroup(group),
                onRemoveMember: (member) => _removeMember(group, member),
              ),
              const SizedBox(height: 12),
            ],
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildCreateCard() {
    return Card(
      color: Colors.white,
      elevation: 2,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('ÚJ CSOPORT', style: sectionLabelStyle),
            const SizedBox(height: 8),
            Text(
              'Hozz létre egy motoros csapatot, majd add hozzá a barátaidat. '
              'A csoport adatai a szerveren tárolódnak.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                key: const Key('createGroupButton'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.black87,
                  side: const BorderSide(color: Colors.amber, width: 2),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: _busy ? null : _createGroup,
                icon: const Icon(Icons.group_add_outlined, size: 18),
                label: const Text(
                  'CSOPORT LÉTREHOZÁSA',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Egy csoport kártyája: adatok, tagok és a szerkesztő műveletek.
class _GroupCard extends StatelessWidget {
  const _GroupCard({
    required this.group,
    required this.busy,
    required this.onAddMember,
    required this.onEdit,
    required this.onDelete,
    required this.onLeave,
    required this.onRemoveMember,
  });

  final BikeGroup group;
  final bool busy;
  final VoidCallback onAddMember;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onLeave;
  final ValueChanged<GroupMember> onRemoveMember;

  @override
  Widget build(BuildContext context) {
    final description = (group.description ?? '').trim();
    final subtitle = description.isEmpty
        ? '${group.memberCount} tag'
        : '${group.memberCount} tag • $description';

    return Card(
      color: Colors.white,
      elevation: 2,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircleAvatar(
                  backgroundColor: Colors.amber,
                  child: Icon(Icons.groups, color: Colors.black),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        group.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (group.isOwner) ...[
              const SizedBox(height: 6),
              const Text(
                'Te vagy a csoport tulajdonosa – tagokat adhatsz hozzá.',
                style: TextStyle(fontSize: 11, color: Color(0xFF616161)),
              ),
            ],
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final member in group.members)
                  Chip(
                    key: Key('memberChip_${member.userId}'),
                    avatar: InitialsAvatar(
                      initials: member.initials,
                      radius: 11,
                    ),
                    label: Text(
                      member.isOwner
                          ? '${member.displayName} (tulajdonos)'
                          : member.displayName,
                      style: const TextStyle(fontSize: 11),
                    ),
                    deleteIcon: const Icon(Icons.close, size: 16),
                    onDeleted: group.isOwner && !member.isOwner
                        ? () => onRemoveMember(member)
                        : null,
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (group.isOwner) ...[
                  OutlinedButton.icon(
                    key: Key('addMember_${group.id}'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.black87,
                      side: const BorderSide(color: Colors.amber, width: 2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: busy ? null : onAddMember,
                    icon: const Icon(Icons.person_add_alt_1, size: 16),
                    label: const Text(
                      'Tag hozzáadása',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    key: Key('editGroup_${group.id}'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.black87,
                    ),
                    onPressed: busy ? null : onEdit,
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    label: const Text(
                      'Szerkesztés',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                  TextButton.icon(
                    key: Key('deleteGroup_${group.id}'),
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                    onPressed: busy ? null : onDelete,
                    icon: const Icon(Icons.delete_outline, size: 16),
                    label: const Text(
                      'Törlés',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ] else
                  OutlinedButton.icon(
                    key: Key('leaveGroup_${group.id}'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.black87,
                      side: const BorderSide(color: Colors.amber, width: 2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: busy ? null : onLeave,
                    icon: const Icon(Icons.logout, size: 16),
                    label: const Text(
                      'Kilépés',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}


