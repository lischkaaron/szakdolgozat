import 'package:flutter/material.dart';

import '../widgets/app_widgets.dart';

// ---------------------------------------------------------------------------
// 4. KÉPERNYŐ: PROFIL – a felhasználó adatai és a barátok száma
// ---------------------------------------------------------------------------
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profil')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircleAvatar(
                radius: 46,
                backgroundColor: Colors.amber,
                child: Icon(Icons.person, size: 52, color: Colors.black),
              ),
              const SizedBox(height: 16),
              const Text(
                'Lischka Áron',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                'Túravezető • Konvoj tag',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
              ),
              const SizedBox(height: 28),
              // Barátok száma: csak egy szám, lista nélkül.
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  vertical: 20,
                  horizontal: 24,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Column(
                  children: [
                    Text('BARÁTOK', style: sectionLabelStyle),
                    SizedBox(height: 6),
                    Text(
                      '12',
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
