import 'package:flutter/material.dart';

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
