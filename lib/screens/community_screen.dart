import 'package:flutter/material.dart';

import '../widgets/app_widgets.dart';

// ---------------------------------------------------------------------------
// 3. KÉPERNYŐ: KÖZÖSSÉG & CSAPATOK
//    Barátok hozzáadása, valamint barátok hozzáadása csoportokhoz.
// ---------------------------------------------------------------------------
class CommunityScreen extends StatelessWidget {
  const CommunityScreen({super.key});

  static const List<_Person> _friends = [
    _Person(
      name: 'Kovács Ádám',
      initials: 'KÁ',
      status: 'Online • BMW R1250GS',
    ),
    _Person(
      name: 'Nagy Tamás',
      initials: 'NT',
      status: 'Offline • Yamaha MT-07',
    ),
    _Person(
      name: 'Szabó Réka',
      initials: 'SR',
      status: 'Online • Honda CB650R',
    ),
  ];

  static const List<_Person> _suggestions = [
    _Person(
      name: 'Tóth Bence',
      initials: 'TB',
      status: 'Közös ismerős: Nagy Tamás',
    ),
    _Person(
      name: 'Varga Eszter',
      initials: 'VE',
      status: 'Közös ismerős: Kovács Ádám',
    ),
  ];

  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  // Barát hozzáadása: kereső + javasolt ismerősök.
  void _showAddFriendDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Barát hozzáadása',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          contentPadding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
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
              const SizedBox(height: 8),
              for (final _Person person in _suggestions)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: _InitialsAvatar(initials: person.initials),
                  title: Text(person.name),
                  subtitle: Text(
                    person.status,
                    style: const TextStyle(fontSize: 11),
                  ),
                  trailing: const Icon(Icons.person_add_alt_1),
                  onTap: () {
                    Navigator.of(dialogContext).pop();
                    _showMessage(
                      context,
                      'Barátkérés elküldve: ${person.name}',
                    );
                  },
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Bezárás'),
            ),
          ],
        );
      },
    );
  }

  // Barát hozzáadása egy adott csoporthoz.
  void _showAddFriendToGroupDialog(BuildContext context, String groupName) {
    showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'Barát hozzáadása – $groupName',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),
          contentPadding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final _Person friend in _friends)
                  ListTile(
                    leading: _InitialsAvatar(initials: friend.initials),
                    title: Text(friend.name),
                    subtitle: Text(
                      friend.status,
                      style: const TextStyle(fontSize: 11),
                    ),
                    trailing: const Icon(
                      Icons.add_circle_outline,
                      color: Color(0xFF616161),
                    ),
                    onTap: () {
                      Navigator.of(dialogContext).pop();
                      _showMessage(
                        context,
                        '${friend.name} hozzáadva: $groupName',
                      );
                    },
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Kész'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Közösség & Csapatok'),
        actions: [
          IconButton(
            tooltip: 'Barát hozzáadása',
            icon: const Icon(Icons.person_add_alt_1),
            onPressed: () => _showAddFriendDialog(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Barát keresése / hozzáadása
          Card(
            color: Colors.white,
            elevation: 2,
            margin: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('BARÁT HOZZÁADÁSA', style: sectionLabelStyle),
                  const SizedBox(height: 10),
                  TextField(
                    decoration: InputDecoration(
                      hintText: 'Barát keresése név vagy e-mail alapján',
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: const Color(0xFFF5F5F5),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.black87,
                        side: const BorderSide(color: Colors.amber, width: 2),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: () => _showAddFriendDialog(context),
                      icon: const Icon(Icons.person_add_alt_1, size: 18),
                      label: const Text(
                        'Barát hozzáadása',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          const SectionTitle('Ismerősök'),
          Card(
            color: Colors.white,
            elevation: 2,
            margin: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                for (int i = 0; i < _suggestions.length; i++) ...[
                  if (i > 0) const Divider(height: 1),
                  ListTile(
                    leading: _InitialsAvatar(
                      initials: _suggestions[i].initials,
                    ),
                    title: Text(
                      _suggestions[i].name,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      _suggestions[i].status,
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: TextButton(
                      style: TextButton.styleFrom(
                        backgroundColor: Colors.amber,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: () => _showMessage(
                        context,
                        'Barátkérés elküldve: ${_suggestions[i].name}',
                      ),
                      child: const Text(
                        'Hozzáadás',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
          const SectionTitle('Barátaim (12)'),
          Card(
            color: Colors.white,
            elevation: 2,
            margin: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                for (int i = 0; i < _friends.length; i++) ...[
                  if (i > 0) const Divider(height: 1),
                  ListTile(
                    leading: _InitialsAvatar(initials: _friends[i].initials),
                    title: Text(
                      _friends[i].name,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      _friends[i].status,
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: const Icon(
                      Icons.motorcycle_outlined,
                      color: Color(0xFF616161),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
          const SectionTitle('Csoportjaim'),
          _GroupCard(
            name: 'Betyár Riders Klub',
            subtitle: '12 tag • 3 aktív túra',
            members: const ['KÁ', 'NT', 'SR', 'TB'],
            extraMembers: 8,
            onAddFriend: () =>
                _showAddFriendToGroupDialog(context, 'Betyár Riders Klub'),
          ),
          const SizedBox(height: 12),
          _GroupCard(
            name: 'Hétvégi Motorosok',
            subtitle: '5 tag • 1 aktív túra',
            members: const ['KÁ', 'SR'],
            extraMembers: 3,
            onAddFriend: () =>
                _showAddFriendToGroupDialog(context, 'Hétvégi Motorosok'),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

/// Egy csoport kártya: tagok és "barát hozzáadása a csoporthoz" gomb.
class _GroupCard extends StatelessWidget {
  final String name;
  final String subtitle;
  final List<String> members;
  final int extraMembers;
  final VoidCallback onAddFriend;

  const _GroupCard({
    required this.name,
    required this.subtitle,
    required this.members,
    required this.extraMembers,
    required this.onAddFriend,
  });

  @override
  Widget build(BuildContext context) {
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
                        name,
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
            const SizedBox(height: 14),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final String member in members)
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: const Color(0xFFF1F3F4),
                    child: Text(
                      member,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF212121),
                      ),
                    ),
                  ),
                if (extraMembers > 0)
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: Colors.amber,
                    child: Text(
                      '+$extraMembers',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.black87,
                  side: const BorderSide(color: Colors.amber, width: 2),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: onAddFriend,
                icon: const Icon(Icons.person_add_alt_1, size: 18),
                label: const Text(
                  'Barát hozzáadása a csoporthoz',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Kezdőbetűs avatar a barátlistához.
class _InitialsAvatar extends StatelessWidget {
  final String initials;

  const _InitialsAvatar({required this.initials});

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      backgroundColor: Colors.amber,
      child: Text(
        initials,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.black,
        ),
      ),
    );
  }
}

/// Egy barát / ismerős adatai.
class _Person {
  final String name;
  final String initials;
  final String status;

  const _Person({
    required this.name,
    required this.initials,
    required this.status,
  });
}

