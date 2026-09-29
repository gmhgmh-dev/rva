import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rva/screens/about_screen.dart';

void main() {
  testWidgets('AboutScreen renders version, features, and attributions', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: AboutScreen(),
      ),
    );

    expect(find.text('Par lietotni'), findsOneWidget);
    expect(find.text('Roads Voice Assistant'), findsOneWidget);
    expect(find.textContaining('Versija 0.2.1'), findsOneWidget);
    expect(find.text('Apraksts un mērķis'), findsOneWidget);
    expect(find.text('Galvenās funkcijas'), findsOneWidget);
    expect(find.text('Kartes un atvērtā koda datu avoti', skipOffstage: false), findsOneWidget);
    expect(find.text('Privātums un datu drošība', skipOffstage: false), findsOneWidget);
    expect(find.text('Izstrāde un licences', skipOffstage: false), findsOneWidget);
    expect(find.text('Atvērtā koda licences', skipOffstage: false), findsOneWidget);
  });
}
