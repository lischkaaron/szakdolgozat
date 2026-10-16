import 'package:flutter_test/flutter_test.dart';

import 'package:moto_konvoj/main.dart';

void main() {
  testWidgets('A Motoros Konvoj app elindul és megjeleníti a fő navigációt',
      (WidgetTester tester) async {
    // Építsük fel az alkalmazást és rendereljünk egy frame-et.
    await tester.pumpWidget(const MotorcycleConvoyApp());

    // Az alsó navigáció mind a 4 füle megjelenik.
    expect(find.text('Túra / Térkép'), findsOneWidget);
    expect(find.text('Tervezés (AI)'), findsOneWidget);
    expect(find.text('Közösség'), findsOneWidget);
    expect(find.text('Profil'), findsOneWidget);

    // Alapértelmezett képernyő az aktív konvoj térkép nézet.
    expect(find.text('Aktív Konvoj: Balatoni Kanyarvadászat'), findsOneWidget);
  });
}

