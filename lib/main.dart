import 'package:flutter/material.dart';

void main() {
  runApp(const MotorcycleConvoyApp());
}

class MotorcycleConvoyApp extends StatelessWidget {
  const MotorcycleConvoyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Motoros Konvoj',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.light().copyWith(
        scaffoldBackgroundColor: const Color(0xFFF5F5F5),
        colorScheme: const ColorScheme.light(
          primary: Colors.amber, // Jól látható, motoros témához illő sárga/narancs
          onPrimary: Colors.black,
          secondary: Colors.amberAccent,
          onSecondary: Colors.black,
          surface: Colors.white,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          elevation: 0,
        ),
      ),
      home: const MainNavigationScreen(),
    );
  }
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  // A 4 fő nézet, amiről a tématerv is szól
  final List<Widget> _screens = const [
    MapConvoyScreen(),
    TourPlannerScreen(),
    CommunityScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
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
            icon: Icon(Icons.navigation_rounded),
            label: 'Túra / Térkép',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.route_rounded),
            label: 'Tervezés (AI)',
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

// ---------------------------------------------------------------------------
// 1. KÉPERNYŐ: TÉRKÉP & GYORSGOMBOK (A legfontosabb motoros felület)
// ---------------------------------------------------------------------------
class MapConvoyScreen extends StatelessWidget {
  const MapConvoyScreen({super.key});

  void _showNotification(BuildContext context, String message, Color color) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        backgroundColor: color,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Aktív Konvoj: Balatoni Kanyarvadászat'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {},
          ),
        ],
      ),
      body: Stack(
        children: [
          // Térkép placeholder háttér
          Container(
            color: const Color(0xFFECEFF1),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.map_outlined, size: 80, color: Colors.grey.shade600),
                  const SizedBox(height: 12),
                  Text(
                    'Itt jelenik majd meg a Mapbox térkép',
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  const Chip(
                    avatar: Icon(Icons.people, color: Colors.black87),
                    label: Text('Konvoj létszám: 4 motoros', style: TextStyle(color: Colors.black87)),
                    backgroundColor: Colors.amber,
                  ),
                ],
              ),
            ),
          ),

          // ALSÓ SÁV: Motoros ergonómiájú nagy gombok (Kesztyűben is könnyű kezelés)
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.92),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'GYORSJELZÉSEK A CSAPATNAK',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2, color: Color(0xFF616161)),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _QuickButton(
                          label: 'LASSÍTÁS',
                          icon: Icons.arrow_downward_rounded,
                          color: Colors.orange.shade800,
                          onPressed: () => _showNotification(context, 'Jelzés elküldve: Lassítás kérése!', Colors.orange.shade800),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _QuickButton(
                          label: 'GYORSÍTÁS',
                          icon: Icons.arrow_upward_rounded,
                          color: Colors.blue.shade700,
                          onPressed: () => _showNotification(context, 'Jelzés elküldve: Tempó növelése!', Colors.blue.shade700),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _QuickButton(
                          label: 'PIHENŐ',
                          icon: Icons.local_gas_station_rounded,
                          color: Colors.teal.shade700,
                          onPressed: () => _showNotification(context, 'Jelzés elküldve: Megállás / Tankolás!', Colors.teal.shade700),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _QuickButton(
                          label: 'SOS / BAJ VAN',
                          icon: Icons.warning_amber_rounded,
                          color: Colors.red.shade800,
                          onPressed: () => _showNotification(context, 'VÉSZJELZÉS ELKÜLDVE A CSAPATNAK!', Colors.red.shade900),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  const _QuickButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 4,
      ),
      onPressed: onPressed,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 28),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 2. KÉPERNYŐ: TÚRATERVEZŐ ÉS AI AJÁNLÓ NÉZET
// ---------------------------------------------------------------------------
class TourPlannerScreen extends StatelessWidget {
  const TourPlannerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Túratervező & AI Asszisztens')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Útvonal: Budapest ➔ Mátra ➔ Eger', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text('Táv: 165 km | Becsült idő: 2 óra 45 perc', style: TextStyle(color: Colors.grey.shade700)),
                  const SizedBox(height: 14),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.black),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('AI elemzés futtatása a tervezett útvonalra...')),
                      );
                    },
                    icon: const Icon(Icons.auto_awesome),
                    label: const Text('Útvonal elemzése AI-val'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text('AI által javasolt motoros megállók:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          _RecommendationCard(
            title: 'Kékestető Kilátó & Parkoló',
            category: 'Látnivaló / Fotópont',
            rating: '4.8',
            distance: '+3 km kitérő',
            icon: Icons.photo_camera,
          ),
          _RecommendationCard(
            title: 'Motoros Pihenő & Büfé',
            category: 'Gasztronómia',
            rating: '4.6',
            distance: 'Útvonalon',
            icon: Icons.restaurant,
          ),
        ],
      ),
    );
  }
}

class _RecommendationCard extends StatelessWidget {
  final String title;
  final String category;
  final String rating;
  final String distance;
  final IconData icon;

  const _RecommendationCard({
    required this.title,
    required this.category,
    required this.rating,
    required this.distance,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(backgroundColor: Colors.amber, child: Icon(icon, color: Colors.black)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('$category • $distance'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.star, color: Colors.amber, size: 18),
            const SizedBox(width: 4),
            Text(rating),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 3. KÉPERNYŐ: KÖZÖSSÉG & CSAPAT
// ---------------------------------------------------------------------------
class CommunityScreen extends StatelessWidget {
  const CommunityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Közösség & Csapatok')),
      body: ListView(
        children: const [
          ListTile(
            leading: CircleAvatar(child: Text('BR')),
            title: Text('Betyár Riders Klub'),
            subtitle: Text('12 tag • 3 aktív túra'),
            trailing: Icon(Icons.arrow_forward_ios, size: 16),
          ),
          Divider(),
          ListTile(
            leading: CircleAvatar(child: Text('KÁ')),
            title: Text('Kovács Ádám'),
            subtitle: Text('Online • BMW R1250GS'),
            trailing: Icon(Icons.motorcycle),
          ),
          ListTile(
            leading: CircleAvatar(child: Text('NT')),
            title: Text('Nagy Tamás'),
            subtitle: Text('Offline • Yamaha MT-07'),
            trailing: Icon(Icons.motorcycle),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 4. KÉPERNYŐ: PROFIL
// ---------------------------------------------------------------------------
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profil')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            CircleAvatar(radius: 45, child: Icon(Icons.person, size: 50)),
            SizedBox(height: 16),
            Text('Lischka Áron', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text('Túravezető / Konvoj tag', style: TextStyle(color: Color(0xFF616161))),
          ],
        ),
      ),
    );
  }
}