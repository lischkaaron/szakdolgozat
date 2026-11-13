import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/friend.dart';
import '../../models/friend_request.dart';
import '../../models/initials.dart';
import '../../models/user.dart';
import '../../services/api_client.dart';
import '../../services/friends_service.dart';
import '../../widgets/app_widgets.dart';
import 'community_dialogs.dart';

// ---------------------------------------------------------------------------
//  KÖZÖSSÉG -> BARÁTOK fül
//  Keresés, bejövő/kimenő barátkérések és a barátlista kezelése a backend
//  (`/api/users/search`, `/api/friends`, `/api/friends/requests`) segítségével.
// ---------------------------------------------------------------------------
class FriendsTab extends StatefulWidget {
  const FriendsTab({super.key});

  @override
  State<FriendsTab> createState() => _FriendsTabState();
}

class _FriendsTabState extends State<FriendsTab> {
  final TextEditingController _searchController = TextEditingController();

  List<Friend> _friends = const <Friend>[];
  List<FriendRequest> _requests = const <FriendRequest>[];
  List<User> _searchResults = const <User>[];

  bool _loading = true;
  bool _busy = false;
  bool _searching = false;
  String? _error;
  String? _searchHint;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  FriendsService get _service => context.read<FriendsService>();

  List<FriendRequest> get _incomingRequests =>
      _requests.where((request) => request.isIncoming).toList();

  List<FriendRequest> get _outgoingRequests =>
      _requests.where((request) => !request.isIncoming).toList();

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final friends = await _service.fetchFriends();
      final requests = await _service.fetchPendingRequests();

      if (!mounted) {
        return;
      }

      setState(() {
        _friends = friends;
        _requests = requests;
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

  /// Végrehajt egy módosító műveletet, majd újratölti a listákat.
  /// Visszatérés: igaz, ha a művelet sikeres volt.
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

  Future<void> _search() async {
    final term = _searchController.text.trim();

    if (term.length < 2) {
      showCommunityMessage(
        context,
        'Legalább 2 karaktert adj meg a kereséshez.',
      );
      return;
    }

    setState(() {
      _searching = true;
      _searchHint = null;
    });

    try {
      final users = await _service.searchUsers(term);
      if (!mounted) {
        return;
      }

      setState(() {
        _searchResults = users;
        _searchHint = users.isEmpty ? 'Nincs találat erre: „$term”.' : null;
        _searching = false;
      });
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _searchResults = const <User>[];
        _searchHint = error.message;
        _searching = false;
      });
    }
  }

  Future<void> _sendRequest(User user) async {
    final sent = await _run(
      () => _service.sendRequest(userId: user.id),
      'Barátkérés elküldve: ${user.displayName}',
    );

    if (!sent || !mounted) {
      return;
    }

    setState(() {
      _searchResults = _searchResults
          .where((item) => item.id != user.id)
          .toList();
    });
  }

  Future<void> _removeFriend(Friend friend) async {
    final confirmed = await confirmCommunityAction(
      context,
      title: 'Barát eltávolítása',
      message:
          'Biztosan eltávolítod ${friend.displayName} felhasználót a barátaid közül?',
      confirmLabel: 'ELTÁVOLÍTÁS',
    );

    if (!confirmed) {
      return;
    }

    await _run(
      () => _service.removeFriend(friend.id),
      '${friend.displayName} eltávolítva a barátok közül.',
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
          _buildSearchCard(),
          const SizedBox(height: 20),
          if (_incomingRequests.isNotEmpty) ...[
            SectionTitle('Bejövő barátkérések (${_incomingRequests.length})'),
            _buildIncomingRequestsCard(),
            const SizedBox(height: 20),
          ],
          if (_outgoingRequests.isNotEmpty) ...[
            SectionTitle('Elküldött kérések (${_outgoingRequests.length})'),
            _buildOutgoingRequestsCard(),
            const SizedBox(height: 20),
          ],
          SectionTitle('Barátaim (${_friends.length})'),
          _buildFriendsCard(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildSearchCard() {
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
            const Text('BARÁT KERESÉSE', style: sectionLabelStyle),
            const SizedBox(height: 10),
            TextField(
              key: const Key('friendSearchField'),
              controller: _searchController,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _search(),
              decoration: InputDecoration(
                hintText: 'Név vagy e-mail cím',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: const Color(0xFFF5F5F5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                key: const Key('friendSearchButton'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.black87,
                  side: const BorderSide(color: Colors.amber, width: 2),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: _searching ? null : _search,
                icon: const Icon(Icons.search, size: 18),
                label: const Text(
                  'KERESÉS',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
            if (_searching) ...[
              const SizedBox(height: 12),
              const LinearProgressIndicator(minHeight: 2),
            ],
            if (_searchHint != null) ...[
              const SizedBox(height: 12),
              Text(
                _searchHint!,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
              ),
            ],
            for (final user in _searchResults) ...[
              const Divider(height: 16),
              ListTile(
                key: Key('searchResult_${user.id}'),
                contentPadding: EdgeInsets.zero,
                leading: InitialsAvatar(initials: user.initials),
                title: Text(user.displayName),
                subtitle: Text(
                  user.email,
                  style: const TextStyle(fontSize: 11),
                ),
                trailing: TextButton(
                  key: Key('sendRequest_${user.id}'),
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.amber,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: _busy ? null : () => _sendRequest(user),
                  child: const Text(
                    'HOZZÁADÁS',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildIncomingRequestsCard() {
    return Card(
      color: Colors.white,
      elevation: 2,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          for (int i = 0; i < _incomingRequests.length; i++) ...[
            if (i > 0) const Divider(height: 1),
            _buildIncomingRequestTile(_incomingRequests[i]),
          ],
        ],
      ),
    );
  }

  Widget _buildIncomingRequestTile(FriendRequest request) {
    return ListTile(
      key: Key('incomingRequest_${request.id}'),
      leading: InitialsAvatar(
        initials: initialsFromName(request.otherDisplayName),
      ),
      title: Text(
        request.otherDisplayName,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: const Text(
        'Szeretne a barátod lenni',
        style: TextStyle(fontSize: 11),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            key: Key('acceptRequest_${request.id}'),
            tooltip: 'Elfogadás',
            icon: const Icon(Icons.check_circle, color: Color(0xFF2E7D32)),
            onPressed: _busy
                ? null
                : () => _run(
                    () => _service.acceptRequest(request.id),
                    '${request.otherDisplayName} mostantól a barátod.',
                  ),
          ),
          IconButton(
            key: Key('declineRequest_${request.id}'),
            tooltip: 'Elutasítás',
            icon: const Icon(Icons.cancel_outlined, color: Color(0xFFB3261E)),
            onPressed: _busy
                ? null
                : () => _run(
                    () => _service.declineRequest(request.id),
                    'Barátkérés elutasítva: ${request.otherDisplayName}',
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildOutgoingRequestsCard() {
    return Card(
      color: Colors.white,
      elevation: 2,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          for (int i = 0; i < _outgoingRequests.length; i++) ...[
            if (i > 0) const Divider(height: 1),
            _buildOutgoingRequestTile(_outgoingRequests[i]),
          ],
        ],
      ),
    );
  }

  Widget _buildOutgoingRequestTile(FriendRequest request) {
    return ListTile(
      key: Key('outgoingRequest_${request.id}'),
      leading: InitialsAvatar(
        initials: initialsFromName(request.otherDisplayName),
      ),
      title: Text(
        request.otherDisplayName,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: const Text(
        'Barátkérés elküldve, válaszra vár',
        style: TextStyle(fontSize: 11),
      ),
      trailing: TextButton(
        key: Key('cancelRequest_${request.id}'),
        onPressed: _busy
            ? null
            : () => _run(
                () => _service.cancelRequest(request.id),
                'Barátkérés visszavonva: ${request.otherDisplayName}',
              ),
        child: const Text(
          'VISSZAVONÁS',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
        ),
      ),
    );
  }

  Widget _buildFriendsCard() {
    return Card(
      color: Colors.white,
      elevation: 2,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: _friends.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                'Még nincs barátod. Keresd meg őket a fenti mezővel, '
                'és küldj barátkérést!',
                style: TextStyle(fontSize: 12),
              ),
            )
          : Column(
              children: [
                for (int i = 0; i < _friends.length; i++) ...[
                  if (i > 0) const Divider(height: 1),
                  _buildFriendTile(_friends[i]),
                ],
              ],
            ),
    );
  }

  Widget _buildFriendTile(Friend friend) {
    final details = <String>[
      if ((friend.email ?? '').isNotEmpty) friend.email!,
      if ((friend.motorcycle ?? '').isNotEmpty) friend.motorcycle!,
    ].join(' • ');

    return ListTile(
      key: Key('friendTile_${friend.id}'),
      leading: InitialsAvatar(initials: friend.initials),
      title: Text(
        friend.displayName,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: details.isEmpty
          ? null
          : Text(details, style: const TextStyle(fontSize: 12)),
      trailing: IconButton(
        key: Key('removeFriend_${friend.id}'),
        tooltip: 'Barát eltávolítása',
        icon: const Icon(
          Icons.person_remove_outlined,
          color: Color(0xFF616161),
        ),
        onPressed: _busy ? null : () => _removeFriend(friend),
      ),
    );
  }
}


