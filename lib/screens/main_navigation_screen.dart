import 'package:flutter/material.dart';

import 'community_screen.dart';
import 'main_screen.dart';
import 'planner_screen.dart';
import 'profile_screen.dart';

// A 3 fő képernyőt összefogó alsó navigáció (bejelentkezés után).
class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  // Túra közben csak a túra képernyő látszik, alsó navigáció nélkül.
  bool _tourActive = false;

  // A tervezőből indított túra útvonala (a túra képernyő felső sávjához).
  String _tourOrigin = 'Budapest';
  String _tourDestination = 'Balatonfüred';

  // A tervező "TÚRA INDÍTÁSA" gombja hívja meg.
  void _startTour(String origin, String destination) {
    setState(() {
      _tourOrigin = origin;
      _tourDestination = destination;
      _tourActive = true;
    });
  }

  void _endTour() {
    setState(() {
      _tourActive = false;
      _currentIndex = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Túra közben eltűnik az alsó navigációs sáv.
    if (_tourActive) {
      return MapConvoyScreen(
        origin: _tourOrigin,
        destination: _tourDestination,
        onEndTour: _endTour,
      );
    }

    // A 3 fő nézet: tervezés, közösség és profil.
    final List<Widget> screens = <Widget>[
      TourPlannerScreen(onStartTour: _startTour),
      const CommunityScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      body: screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: Colors.amber,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.route_rounded),
            label: 'Tervezés',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.group_rounded),
            label: 'Közösség',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_rounded),
            label: 'Profil',
          ),
        ],
      ),
    );
  }
}
