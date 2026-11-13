import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:moto_konvoj/screens/main_navigation_screen.dart';

void main() {
  testWidgets('Az alsó navigáció 3 fület mutat, a tervezés térképpel indul', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: MainNavigationScreen()));

    // Három fül: tervezés, közösség, profil.
    expect(find.text('Tervezés'), findsOneWidget);
    expect(find.text('Közösség'), findsOneWidget);
    expect(find.text('Profil'), findsOneWidget);
    expect(find.text('Túra / Térkép'), findsNothing);

    // A tervezés első lépése csak térkép + úti cél keresősáv.
    expect(find.text('Hová szeretnél menni?'), findsOneWidget);
    expect(find.text('HONNAN INDULUNK?'), findsNothing);
    expect(find.text('TÚRA INDÍTÁSA'), findsNothing);
  });

  testWidgets('Úti cél után indulás választható, majd elindítható a túra', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: MainNavigationScreen()));

    // Úti cél keresése a felső keresősávban.
    await tester.tap(find.byKey(const Key('destinationSearchField')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('destinationSearchField')),
      'Eger',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Eger'));
    await tester.pumpAndSettle();

    // Megjelenik a honnan választó, alapból a jelenlegi tartózkodási hely.
    expect(find.text('HONNAN INDULUNK?'), findsOneWidget);
    expect(find.text('Jelenlegi tartózkodási hely'), findsOneWidget);
    expect(find.text('TOVÁBB A TERVEZÉSHEZ'), findsOneWidget);

    await tester.tap(find.text('TOVÁBB A TERVEZÉSHEZ'));
    await tester.pumpAndSettle();

    // Az útvonal a kiválasztott indulással és úti céllal jelenik meg.
    expect(find.text('KIVÁLASZTOTT ÚTVONAL'), findsOneWidget);
    expect(find.text('Jelenlegi hely ➔ Mátra ➔ Eger'), findsOneWidget);

    // AI elemzés, majd a túra indítása a tervezés végén.
    await tester.scrollUntilVisible(
      find.text('ÚTVONAL AI ELEMZÉSE'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('ÚTVONAL AI ELEMZÉSE'));
    await tester.pumpAndSettle();
    expect(find.text('AI által javasolt megállók:'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('TÚRA INDÍTÁSA'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('TÚRA INDÍTÁSA'));
    await tester.pumpAndSettle();

    // Túra közben eltűnik az alsó navigáció, a felső sáv az útvonalat mutatja.
    expect(find.text('Tervezés'), findsNothing);
    expect(find.text('69 km van hátra'), findsOneWidget);
    expect(find.text('Érkezés: 12:15 • 1 ó 10 perc'), findsOneWidget);
    expect(find.text('Jelenlegi hely'), findsWidgets);
    expect(find.text('Eger'), findsWidgets);

    // Az X gomb megerősítést kér; MÉGSE esetén a túra folytatódik.
    await tester.tap(find.byTooltip('Túra befejezése'));
    await tester.pumpAndSettle();
    expect(find.text('Biztosan be akarod fejezni a túrát?'), findsOneWidget);

    await tester.tap(find.text('MÉGSE'));
    await tester.pumpAndSettle();
    expect(find.text('69 km van hátra'), findsOneWidget);

    // Megerősítés után visszatér a tervezéshez (térkép + keresősáv).
    await tester.tap(find.byTooltip('Túra befejezése'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('TÚRA BEFEJEZÉSE'));
    await tester.pumpAndSettle();

    expect(find.text('Tervezés'), findsOneWidget);
    expect(find.text('Hová szeretnél menni?'), findsOneWidget);
    expect(find.text('69 km van hátra'), findsNothing);
  });

  testWidgets('Az úti cél utólag is módosítható a keresősávból', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: MainNavigationScreen()));

    await tester.tap(find.byKey(const Key('destinationSearchField')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('destinationSearchField')),
      'Eger',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Eger'));
    await tester.pumpAndSettle();

    expect(find.text('Úti cél: Eger'), findsOneWidget);
    expect(find.text('HONNAN INDULUNK?'), findsOneWidget);

    // Újabb koppintás a keresősávra: a találatok a lap fölött jelennek meg.
    await tester.tap(find.byKey(const Key('destinationSearchField')));
    await tester.pumpAndSettle();

    expect(find.text('TALÁLATOK'), findsOneWidget);
    expect(find.text('NÉPSZERŰ ÚTI CÉLOK'), findsNothing);

    await tester.enterText(
      find.byKey(const Key('destinationSearchField')),
      'Tokaj',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Tokaj'));
    await tester.pumpAndSettle();

    // Az új úti cél jelenik meg a lapon, a korábbi eltűnik.
    expect(find.text('Úti cél: Tokaj'), findsOneWidget);
    expect(find.text('Úti cél: Eger'), findsNothing);
  });

  testWidgets('Kis kijelzőn is elfér a tervező, billentyűzettel együtt', (
    WidgetTester tester,
  ) async {
    // Tipikus telefonos kijelző.
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);

    await tester.pumpWidget(const MaterialApp(home: MainNavigationScreen()));

    await tester.tap(find.byKey(const Key('destinationSearchField')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('destinationSearchField')),
      'Eger',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Eger'));
    await tester.pumpAndSettle();

    expect(find.text('HONNAN INDULUNK?'), findsOneWidget);

    // Billentyűzet: a lapnak ilyenkor is görgethetőnek kell maradnia.
    tester.view.viewInsets = const FakeViewPadding(bottom: 280);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('originSearchField')),
      'Budapest',
    );
    await tester.pumpAndSettle();

    // Billentyűzet elrejtése, majd tovább a tervezésre.
    tester.view.resetViewInsets();
    await tester.pumpAndSettle();

    await tester.tap(find.text('TOVÁBB A TERVEZÉSHEZ'));
    await tester.pumpAndSettle();

    expect(find.text('KIVÁLASZTOTT ÚTVONAL'), findsOneWidget);
    expect(find.text('Budapest ➔ Mátra ➔ Eger'), findsOneWidget);
  });
}
