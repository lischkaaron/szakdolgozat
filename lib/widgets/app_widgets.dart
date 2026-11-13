import 'package:flutter/material.dart';

/// A projekt egységes, kis nagybetűs szekció-felirat stílusa.
const TextStyle sectionLabelStyle = TextStyle(
  fontSize: 11,
  fontWeight: FontWeight.bold,
  letterSpacing: 1.2,
  color: Color(0xFF616161),
);

/// Képernyő-szekció cím (pl. "Barátaim", "AI által javasolt megállók:").
class SectionTitle extends StatelessWidget {
  final String text;

  const SectionTitle(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
      ),
    );
  }
}

/// Kis információs címke (pl. "165 km", "4 motoros").
class InfoChip extends StatelessWidget {
  final String text;

  const InfoChip(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F3F4),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 11, color: Color(0xFF616161)),
      ),
    );
  }
}

/// Kezdőbetűs avatar (barátlistához és csoporttagokhoz).
class InitialsAvatar extends StatelessWidget {
  final String initials;
  final double radius;

  const InitialsAvatar({super.key, required this.initials, this.radius = 20});

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: Colors.amber,
      child: Text(
        initials,
        style: TextStyle(
          fontSize: radius * 0.6,
          fontWeight: FontWeight.bold,
          color: Colors.black,
        ),
      ),
    );
  }
}

/// Hibaüzenet újrapróbálkozás gombbal (hálózati / szerverhiba esetén).
class ErrorRetryView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const ErrorRetryView({
    super.key,
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, size: 40, color: Color(0xFF9E9E9E)),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('ÚJRAPRÓBÁLKOZÁS'),
            ),
          ],
        ),
      ),
    );
  }
}

