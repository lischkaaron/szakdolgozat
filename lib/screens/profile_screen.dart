import 'package:flutter/material.dart';

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
