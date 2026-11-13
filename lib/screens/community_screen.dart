import 'package:flutter/material.dart';

import 'community/friends_tab.dart';
import 'community/groups_tab.dart';

// ---------------------------------------------------------------------------
//  KÖZÖSSÉG & CSAPATOK képernyő
//  Két fül:
//   - Barátok: keresés, barátkérések (elfogadás / elutasítás / visszavonás)
//     és a barátlista kezelése.
//   - Csoportok: motoros csapatok létrehozása, szerkesztése, törlése,
//     tagok hozzáadása és eltávolítása.
//  Minden adat a backendről érkezik (GET /api/friends, /api/groups, ...).
// ---------------------------------------------------------------------------
class CommunityScreen extends StatelessWidget {
  const CommunityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Közösség & Csapatok'),
          bottom: const TabBar(
            indicatorColor: Colors.amber,
            indicatorWeight: 3,
            labelColor: Colors.black,
            unselectedLabelColor: Colors.grey,
            tabs: [
              Tab(icon: Icon(Icons.people_alt_outlined), text: 'Barátok'),
              Tab(icon: Icon(Icons.groups_outlined), text: 'Csoportok'),
            ],
          ),
        ),
        body: const TabBarView(children: [FriendsTab(), GroupsTab()]),
      ),
    );
  }
}
