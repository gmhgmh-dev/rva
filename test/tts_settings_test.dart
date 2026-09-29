import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rva/screens/settings_screen.dart';
import 'package:rva/services/driving_assistant_manager.dart';
import 'package:rva/services/settings_service.dart';
import 'package:rva/services/tts_service.dart';

class MockTtsServiceForTest extends TtsService {
  final List<String> spokenTexts = [];
  bool applySettingsCalled = false;

  @override
  Future<void> init() async {}

  @override
  Future<void> speak(String text) async {
    spokenTexts.add(text);
  }

  @override
  Future<void> testVoice({String? phrase}) async {
    spokenTexts.add(phrase ?? 'Balss asistents ir gatavs darbam. Ātruma ierobežojums piecdesmit kilometri stundā.');
  }

  @override
  Future<List<String>> getAvailableEngines() async => [
    'com.google.android.tts',
    'lv.tilde.balss',
    'com.samsung.SMT',
  ];

  @override
  Future<List<Map<String, String>>> getLatvianVoices() async => [
    {'name': 'lv-lv-x-jva-local', 'locale': 'lv-LV'},
    {'name': 'lv-lv-x-jvb-network', 'locale': 'lv-LV'},
  ];

  @override
  Future<void> applySettings({
    String? engine,
    String? voiceName,
    String? voiceLocale,
    double? speechRate,
    double? pitch,
    bool? audioDucking,
  }) async {
    applySettingsCalled = true;
    await super.applySettings(
      engine: engine,
      voiceName: voiceName,
      voiceLocale: voiceLocale,
      speechRate: speechRate,
      pitch: pitch,
      audioDucking: audioDucking,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('TtsService Engine and Voice Filtering Tests', () {
    test('formatEngineName formats well-known and generic packages', () {
      expect(
        TtsService.formatEngineName('com.google.android.tts'),
        'Google Runas pakalpojumi (Ieteicams)',
      );
      expect(
        TtsService.formatEngineName('lv.tilde.balss'),
        'Tildes Balss (Izcila LV kvalitāte)',
      );
      expect(
        TtsService.formatEngineName('com.samsung.SMT'),
        'Samsung Runas dzinējs',
      );
      expect(
        TtsService.formatEngineName('org.example.customtts'),
        'Customtts (org.example.customtts)',
      );
    });

    test('applySettings updates internal properties and clamps values', () async {
      final tts = TtsService();
      await tts.applySettings(
        engine: 'lv.tilde.balss',
        voiceName: 'lv-lv-x-jva-local',
        voiceLocale: 'lv-LV',
        speechRate: 0.75,
        pitch: 1.25,
        audioDucking: false,
      );

      expect(tts.currentEngine, 'lv.tilde.balss');
      expect(tts.currentVoiceName, 'lv-lv-x-jva-local');
      expect(tts.currentVoiceLocale, 'lv-LV');
      expect(tts.currentSpeechRate, 0.75);
      expect(tts.currentPitch, 1.25);
      expect(tts.audioDucking, false);
    });
  });

  group('SettingsService TTS Settings Persistence Tests', () {
    test('default TTS values are properly initialized', () async {
      final settings = SettingsService();
      await settings.loadSettings();

      expect(settings.ttsEngine, isNull);
      expect(settings.ttsVoiceName, isNull);
      expect(settings.ttsVoiceLocale, isNull);
      expect(settings.ttsSpeechRate, 0.5);
      expect(settings.ttsPitch, 1.0);
    });

    test('setters update state and notify listeners', () async {
      final settings = SettingsService();
      await settings.loadSettings();

      int notifications = 0;
      settings.addListener(() => notifications++);

      await settings.setTtsEngine('lv.tilde.balss');
      expect(settings.ttsEngine, 'lv.tilde.balss');
      expect(notifications, 1);

      await settings.setTtsVoice(name: 'lv-voice-1', locale: 'lv-LV');
      expect(settings.ttsVoiceName, 'lv-voice-1');
      expect(settings.ttsVoiceLocale, 'lv-LV');
      expect(notifications, 2);

      await settings.setTtsSpeechRate(0.6);
      expect(settings.ttsSpeechRate, 0.6);
      expect(notifications, 3);

      await settings.setTtsPitch(1.2);
      expect(settings.ttsPitch, 1.2);
      expect(notifications, 4);

      // Verify persistence after reload
      final reloaded = SettingsService();
      await reloaded.loadSettings();
      expect(reloaded.ttsEngine, 'lv.tilde.balss');
      expect(reloaded.ttsVoiceName, 'lv-voice-1');
      expect(reloaded.ttsVoiceLocale, 'lv-LV');
      expect(reloaded.ttsSpeechRate, 0.6);
      expect(reloaded.ttsPitch, 1.2);
    });
  });

  group('SettingsScreen TTS UI Widget Tests', () {
    testWidgets('renders TTS card with engine, voice, sliders and test button', (tester) async {
      final mockTts = MockTtsServiceForTest();
      final settings = SettingsService();
      await settings.loadSettings();

      final manager = DrivingAssistantManager(
        ttsService: mockTts,
        settingsService: settings,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SettingsScreen(assistantManager: manager),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify TTS card title and elements
      expect(find.text('Runas sintēze un balss (TTS)'), findsOneWidget);
      expect(find.text('TTS Runas dzinējs'), findsOneWidget);
      expect(find.text('Latviešu valodas balss'), findsOneWidget);
      expect(find.text('Runas ātrums'), findsOneWidget);
      expect(find.text('Balss tonis (Pitch)'), findsOneWidget);
      expect(find.text('Pārbaudīt balsi'), findsOneWidget);
      expect(find.byIcon(Icons.volume_up_rounded), findsOneWidget);
      expect(find.byIcon(Icons.refresh_rounded), findsWidgets);

      // Verify recommendation box
      expect(find.textContaining('Tildes Balss'), findsWidgets);

      // Scroll until "Pārbaudīt balsi" button is visible
      final buttonFinder = find.text('Pārbaudīt balsi');
      await tester.ensureVisible(buttonFinder);
      await tester.pumpAndSettle();

      // Tap "Pārbaudīt balsi" button
      await tester.tap(buttonFinder);
      await tester.pumpAndSettle();

      // Verify testVoice was called
      expect(mockTts.spokenTexts.isNotEmpty, true);
      expect(mockTts.spokenTexts.first, contains('Balss asistents ir gatavs'));
    });
  });
}
