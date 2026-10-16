import 'package:flutter/material.dart';

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
