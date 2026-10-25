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
