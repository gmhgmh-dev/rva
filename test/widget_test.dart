import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:rva/main.dart';
import 'package:rva/services/driving_assistant_manager.dart';
import 'package:rva/services/tts_service.dart';

class FakeTtsService extends TtsService {
  final List<String> spokenTexts = [];
  final StreamController<String> _fakeStream = StreamController<String>.broadcast();

  @override
  Stream<String> get spokenTextStream => _fakeStream.stream;

  @override
  Future<void> init() async {}

  @override
  Future<void> speak(String text) async {
    spokenTexts.add(text);
    _fakeStream.add(text);
  }

  @override
  Future<void> stop() async {
    spokenTexts.clear();
  }

  @override
  Future<void> applySettings({
    String? engine,
    String? voiceName,
    String? voiceLocale,
    double? speechRate,
    double? pitch,
    bool? audioDucking,
  }) async {}

  @override
  void dispose() {
    _fakeStream.close();
  }
}

void main() {
  testWidgets('Dashboard UI renders buttons, signs, and handles test drive', (WidgetTester tester) async {
    final fakeTts = FakeTtsService();
    final manager = DrivingAssistantManager(ttsService: fakeTts);

    await tester.pumpWidget(RoadsVoiceAssistantApp(assistantManager: manager));
    await tester.pump();

    // Verify Title
    expect(find.text('Roads Voice Assistant'), findsOneWidget);

    // Verify Action Buttons
    expect(find.text('Sākt reālo GPS'), findsOneWidget);
    expect(find.text('Testa brauciens'), findsOneWidget);

    // Verify Default Sign values (50 km/h)
    expect(find.text('50'), findsOneWidget);
    expect(find.text('STANDARTA ZONA'), findsOneWidget);
    expect(find.text('DIVVIRZIENU IELA'), findsOneWidget);
    expect(find.textContaining('Datu avots: Gaidīšanas režīms'), findsOneWidget);

    // Step manually along the Ventspils route:
    // Index 0 is initial Lielais prospekts
    // Step to Index 1 (Lielais prospekts 2)
    manager.stepNextMockPoint();
    await tester.pump();
    expect(find.textContaining('Demo simulācija'), findsOneWidget);

    // Step to Index 2 (Kuldīgas iela 1, 30 km/h) -> Trigger 1
    manager.stepNextMockPoint();
    await tester.pump();

    // Verify UI reflects 30 km/h zone
    expect(find.text('30'), findsOneWidget);
    expect(find.text('30 KM/H ZONA'), findsOneWidget);
    expect(find.text('Kuldīgas iela'), findsOneWidget);

    // Verify Latvian voice announcement was spoken for dynamic street & speed limit announcement
    expect(
      fakeTts.spokenTexts,
      contains('Atrodaties uz Kuldīgas iela. Atļautais ātrums 30 kilometri stundā.'),
    );

    // Step to Index 3 (Kuldīgas iela 2)
    manager.stepNextMockPoint();
    await tester.pump();

    // Step to Index 4 (Sofijas iela, oneway: true) -> Trigger 3
    manager.stepNextMockPoint();
    await tester.pump();

    expect(find.text('VIENVIRZIENA IELA'), findsOneWidget);
    expect(find.text('Sofijas iela'), findsOneWidget);
    expect(
      fakeTts.spokenTexts,
      contains('Sofijas iela. Vienvirziena, 30 kilometri stundā.'),
    );

    await manager.stop();
    await tester.pump();

    // Verify that stop() clears currentPoint and restores idle status
    expect(manager.currentPoint, isNull);
    expect(find.textContaining('Datu avots: Gaidīšanas režīms'), findsOneWidget);
  });
}
