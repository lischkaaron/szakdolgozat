import 'package:flutter/material.dart';

/// A térképen megjelenő jelölő típusa.
enum MapPinType { start, waypoint, end, member }

/// Egy jelölő a térkép-placeholderben.
/// A [left] és [top] arányos pozíció (0..1) a térkép méretéhez viszonyítva.
class MapPin {
  final double left;
  final double top;
  final String label;
  final MapPinType type;

  const MapPin({
    required this.left,
    required this.top,
    required this.label,
    this.type = MapPinType.member,
  });
}

/// Egyszerű térkép-placeholder (a Mapbox térkép helye a prototípusban).
class MapPlaceholder extends StatelessWidget {
  final bool showRoute;
  final List<MapPin> pins;
  final String caption;
  final BorderRadius borderRadius;

  const MapPlaceholder({
    super.key,
    this.showRoute = false,
    this.pins = const <MapPin>[],
    this.caption = 'Itt jelenik majd meg a Mapbox térkép',
    this.borderRadius = BorderRadius.zero,
  });

  /// Az útvonal arányos töréspontjai (a jelölők ehhez igazodnak).
  static const List<Offset> routePoints = <Offset>[
    Offset(0.12, 0.82),
    Offset(0.30, 0.62),
    Offset(0.44, 0.66),
    Offset(0.58, 0.44),
    Offset(0.70, 0.20),
  ];

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius,
      child: ColoredBox(
        color: const Color(0xFFE8EDF1),
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            return Stack(
              children: <Widget>[
                Positioned.fill(
                  child: CustomPaint(
                    painter: _MapPainter(showRoute: showRoute),
                  ),
                ),
                for (final MapPin pin in pins)
                  Positioned(
                    left: pin.left * constraints.maxWidth,
                    top: pin.top * constraints.maxHeight,
                    child: FractionalTranslation(
                      translation: const Offset(-0.5, -1.0),
                      child: _MapPinWidget(pin: pin),
                    ),
                  ),
                Positioned(
                  left: 12,
                  bottom: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(
                          Icons.map_outlined,
                          size: 14,
                          color: Colors.grey.shade700,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          caption,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _MapPinWidget extends StatelessWidget {
  final MapPin pin;

  const _MapPinWidget({required this.pin});

  @override
  Widget build(BuildContext context) {
    if (pin.type == MapPinType.member) {
      return Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: CircleAvatar(
          radius: 13,
          backgroundColor: Colors.amber,
          child: Text(
            pin.label,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
        ),
      );
    }

    Color dotColor = Colors.amber;
    switch (pin.type) {
      case MapPinType.start:
        dotColor = Colors.amber;
        break;
      case MapPinType.waypoint:
        dotColor = const Color(0xFF9E9E9E);
        break;
      case MapPinType.end:
        dotColor = const Color(0xFF212121);
        break;
      case MapPinType.member:
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            pin.label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Color(0xFF212121),
            ),
          ),
        ],
      ),
    );
  }
}

class _MapPainter extends CustomPainter {
  final bool showRoute;

  const _MapPainter({required this.showRoute});

  @override
  void paint(Canvas canvas, Size size) {
    final Paint gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.7)
      ..strokeWidth = 1;

    const double step = 34;
    for (double x = step; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = step; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    if (!showRoute) {
      return;
    }

    final Path path = Path();
    final List<Offset> points = MapPlaceholder.routePoints;
    for (int i = 0; i < points.length; i++) {
      final Offset point = Offset(
        points[i].dx * size.width,
        points[i].dy * size.height,
      );
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }

    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFFFFB300)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant _MapPainter oldDelegate) =>
      oldDelegate.showRoute != showRoute;
}


