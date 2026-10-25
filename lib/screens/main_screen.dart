import 'package:flutter/material.dart';

import '../widgets/app_widgets.dart';
import '../widgets/map_placeholder.dart';

// ---------------------------------------------------------------------------
// 1. KÉPERNYŐ: TÚRA KÉPERNYŐ – térkép, gyorsgombok és a honnan-hová útvonal.
//    Túra indítása után az alsó navigációs sáv eltűnik (lásd main.dart).
// ---------------------------------------------------------------------------
class MapConvoyScreen extends StatefulWidget {
  // A tervezőben kiválasztott útvonal, amit a felső sáv mutat.
  final String origin;
  final String destination;
  final VoidCallback onEndTour;

  const MapConvoyScreen({
    super.key,
    this.origin = 'Budapest',
    this.destination = 'Balatonfüred',
    required this.onEndTour,
  });

  @override
  State<MapConvoyScreen> createState() => _MapConvoyScreenState();
}

class _MapConvoyScreenState extends State<MapConvoyScreen> {
  /// A térkép jobb alsó sarkában lévő gombbal jelennek meg a gyorsgombok.
  bool _quickActionsVisible = false;

  List<MapPin> get _pins => [
    MapPin(left: 0.12, top: 0.82, label: widget.origin, type: MapPinType.start),
    const MapPin(left: 0.30, top: 0.62, label: 'KÁ'),
    const MapPin(left: 0.44, top: 0.66, label: 'NT'),
    const MapPin(left: 0.58, top: 0.44, label: 'SR'),
    MapPin(
      left: 0.70,
      top: 0.20,
      label: widget.destination,
      type: MapPinType.end,
    ),
  ];

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
      // Nincs AppBar: a felső sáv maga a honnan-hová útvonal,
      // az alsó sáv pedig a hátralévő távot és az érkezést mutatja.
      body: Stack(
        children: [
          Positioned.fill(
            child: MapPlaceholder(
              showRoute: true,
              pins: _pins,
              caption: 'Élő konvoj – 4 motoros a térképen',
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                child: _RouteSummaryCard(
                  origin: widget.origin,
                  destination: widget.destination,
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildQuickActionsButton(),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    alignment: Alignment.bottomCenter,
                    child: _quickActionsVisible
                        ? _buildQuickPanel(context)
                        : const SizedBox(width: double.infinity),
                  ),
                  _buildTourStatusBar(context),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // A térkép jobb alsó sarkában lebegő gomb: ezzel nyílnak ki a gyorsgombok.
  // Nagyobb átmérő (68 px), hogy motoron, kesztyűben is könnyen elérhető legyen.
  Widget _buildQuickActionsButton() {
    return Padding(
      padding: const EdgeInsets.only(right: 16, bottom: 12),
      child: Align(
        alignment: Alignment.centerRight,
        child: Material(
          color: Colors.amber,
          elevation: 4,
          shape: const CircleBorder(),
          child: IconButton(
            tooltip: _quickActionsVisible
                ? 'Gyorsgombok elrejtése'
                : 'Gyorsgombok megnyitása',
            iconSize: 32,
            padding: const EdgeInsets.all(18),
            constraints: const BoxConstraints.tightFor(width: 68, height: 68),
            color: Colors.black,
            onPressed: () {
              setState(() {
                _quickActionsVisible = !_quickActionsVisible;
              });
            },
            icon: Icon(
              _quickActionsVisible ? Icons.close_rounded : Icons.bolt_rounded,
            ),
          ),
        ),
      ),
    );
  }

  // Alsó sáv túra közben: csak a hátralévő táv és az érkezési idő.
  Widget _buildTourStatusBar(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 14,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.25),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.navigation_rounded,
              size: 22,
              color: Colors.black87,
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '69 km van hátra',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 2),
                Text(
                  'Érkezés: 12:15 • 1 ó 10 perc',
                  style: TextStyle(fontSize: 12.5, color: Color(0xFF616161)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Google Maps-szerű X gomb: megerősítés után fejezi be a túrát.
          Material(
            color: const Color(0xFFF1F3F4),
            shape: const CircleBorder(),
            child: IconButton(
              tooltip: 'Túra befejezése',
              onPressed: () => _confirmEndTour(context),
              icon: const Icon(Icons.close_rounded, color: Color(0xFF212121)),
            ),
          ),
        ],
      ),
    );
  }

  // Megerősítést kér, mielőtt a túra ténylegesen befejeződik.
  Future<void> _confirmEndTour(BuildContext context) async {
    final bool? shouldEnd = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Túra befejezése'),
          content: const Text('Biztosan be akarod fejezni a túrát?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('MÉGSE'),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red.shade800),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text(
                'TÚRA BEFEJEZÉSE',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );

    if (shouldEnd == true && mounted) {
      _endTour();
    }
  }

  // A megerősítés után ténylegesen lezárja a túrát.
  void _endTour() {
    setState(() {
      _quickActionsVisible = false;
    });
    widget.onEndTour();
  }

  // Gyorsgombok: csak a térkép jobb alsó gombjának megnyomása után jelennek meg.
  Widget _buildQuickPanel(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'GYORSJELZÉSEK A CSAPATNAK',
            textAlign: TextAlign.center,
            style: sectionLabelStyle,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _QuickButton(
                  label: 'LASSÍTÁS',
                  icon: Icons.arrow_downward_rounded,
                  color: Colors.orange.shade800,
                  onPressed: () => _showNotification(
                    context,
                    'Jelzés elküldve: Lassítás kérése!',
                    Colors.orange.shade800,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _QuickButton(
                  label: 'GYORSÍTÁS',
                  icon: Icons.arrow_upward_rounded,
                  color: Colors.blue.shade700,
                  onPressed: () => _showNotification(
                    context,
                    'Jelzés elküldve: Tempó növelése!',
                    Colors.blue.shade700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _QuickButton(
                  label: 'PIHENŐ',
                  icon: Icons.local_gas_station_rounded,
                  color: Colors.teal.shade700,
                  onPressed: () => _showNotification(
                    context,
                    'Jelzés elküldve: Megállás / Tankolás!',
                    Colors.teal.shade700,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _QuickButton(
                  label: 'SOS / BAJ VAN',
                  icon: Icons.warning_amber_rounded,
                  color: Colors.red.shade800,
                  onPressed: () => _showNotification(
                    context,
                    'VÉSZJELZÉS ELKÜLDVE A CSAPATNAK!',
                    Colors.red.shade900,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// Felső sáv: honnan, hová megyünk (Google Maps-szerű útvonal-sáv).
class _RouteSummaryCard extends StatelessWidget {
  final String origin;
  final String destination;

  const _RouteSummaryCard({required this.origin, required this.destination});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      elevation: 3,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('ÚTVONAL', style: sectionLabelStyle),
                const Spacer(),
                IconButton(
                  tooltip: 'Beállítások',
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                  constraints: const BoxConstraints(),
                  icon: const Icon(
                    Icons.settings_outlined,
                    size: 20,
                    color: Color(0xFF616161),
                  ),
                  onPressed: () {},
                ),
                const SizedBox(width: 6),
              ],
            ),
            const SizedBox(height: 4),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 6,
              runSpacing: 4,
              children: [
                _RoutePoint(color: Colors.amber, label: origin),
                const Icon(
                  Icons.arrow_forward_rounded,
                  size: 16,
                  color: Color(0xFF616161),
                ),
                _RoutePoint(color: const Color(0xFF212121), label: destination),
              ],
            ),
            const SizedBox(height: 8),
            const Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                InfoChip('165 km'),
                InfoChip('2 ó 45 perc'),
                InfoChip('4 motoros'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RoutePoint extends StatelessWidget {
  final Color color;
  final String label;

  const _RoutePoint({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
      ],
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
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 4,
      ),
      onPressed: onPressed,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 26),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
