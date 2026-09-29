import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rva/screens/settings_screen.dart';
import 'package:rva/services/driving_assistant_manager.dart';
import 'package:rva/services/map_downloader_service.dart';
import 'package:rva/services/pmtiles_service.dart';
import 'package:rva/services/tts_service.dart';

class TestTtsService extends TtsService {
  @override
  Future<void> init() async {}
  @override
  Future<void> speak(String text) async {}
  @override
  Future<void> stop() async {}
  @override
  Future<List<String>> getAvailableEngines() async => ['com.google.android.tts', 'lv.tilde.balss'];
  @override
  Future<List<Map<String, String>>> getLatvianVoices() async => [
    {'name': 'lv-lv-x-jva-local', 'locale': 'lv-LV'},
  ];
  @override
  Future<void> applySettings({
    String? engine,
    String? voiceName,
    String? voiceLocale,
    double? speechRate,
    double? pitch,
    bool? audioDucking,
  }) async {}
}

class FakePMTilesService extends PMTilesService {
  bool _mockLoaded = false;

  @override
  bool get isLoaded => _mockLoaded;

  @override
  Future<void> openArchive(File file) async {
    _mockLoaded = true;
  }

  @override
  Future<void> close() async {
    _mockLoaded = false;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('settings_screen_test_');
  });

  tearDown(() {
    try {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    } catch (_) {}
  });

  testWidgets('SettingsScreen displays initial not downloaded state and button', (tester) async {
    final downloader = MapDownloaderService(
      docDirResolver: () async => tempDir,
    );
    final manager = DrivingAssistantManager(
      mapDownloaderService: downloader,
      ttsService: TestTtsService(),
    );

    await tester.runAsync(() async {
      await tester.pumpWidget(
        MaterialApp(
          home: SettingsScreen(assistantManager: manager),
        ),
      );
      await Future.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump();

    // Verify title and status
    expect(find.text('Iestatījumi • Bezsaistes karte'), findsOneWidget);
    expect(find.text('Latvijas PMTiles bezsaistes karte'), findsOneWidget);
    expect(find.text('Karte nav lejupielādēta'), findsOneWidget);

    // Verify button text requested in prompt
    expect(
      find.text('Lejupielādēt / Atjaunināt Latvijas bezsaistes karti'),
      findsOneWidget,
    );
  });

  testWidgets('SettingsScreen displays file size and date when map file exists', (tester) async {
    final mapFile = File('${tempDir.path}/${MapDownloaderService.mapFileName}');
    mapFile.writeAsStringSync('hello world');

    final downloader = MapDownloaderService(
      docDirResolver: () async => tempDir,
    );
    final fakePMTiles = FakePMTilesService();
    final manager = DrivingAssistantManager(
      mapDownloaderService: downloader,
      pmTilesService: fakePMTiles,
      ttsService: TestTtsService(),
    );

    await tester.runAsync(() async {
      await manager.tryLoadOfflineMap();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: SettingsScreen(assistantManager: manager),
      ),
    );

    await tester.runAsync(() async {
      await Future.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump(const Duration(milliseconds: 50));

    // Verify status is active
    expect(find.text('Aktīva & gatava bezsaistei'), findsOneWidget);
    expect(find.text('Faila izmērs: '), findsOneWidget);
    expect(find.text('11 B'), findsOneWidget);
    expect(find.text('Pēdējoreiz atjaunināts: '), findsOneWidget);
    expect(find.text('Dzēst lokālo kartes failu'), findsOneWidget);
  });

  testWidgets('SettingsScreen downloads map and triggers progress updates', (tester) async {
    final sampleData = utf8.encode('DUMMY PMTILES CONTENT FOR TESTS');

    final mockClient = MockClient((request) async {
      return http.Response.bytes(
        sampleData,
        200,
        headers: {'content-length': sampleData.length.toString()},
      );
    });

    final downloader = MapDownloaderService(
      docDirResolver: () async => tempDir,
      httpClient: mockClient,
    );
    final fakePMTiles = FakePMTilesService();
    final manager = DrivingAssistantManager(
      mapDownloaderService: downloader,
      pmTilesService: fakePMTiles,
      ttsService: TestTtsService(),
    );

    await tester.runAsync(() async {
      await tester.pumpWidget(
        MaterialApp(
          home: SettingsScreen(assistantManager: manager),
        ),
      );
      await Future.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump();

    // Tap download button
    final downloadButton = find.text('Lejupielādēt / Atjaunināt Latvijas bezsaistes karti');
    expect(downloadButton, findsOneWidget);

    await tester.runAsync(() async {
      await tester.tap(downloadButton);
      await Future.delayed(const Duration(milliseconds: 400));
    });
    await tester.pumpAndSettle();

    // After download completed, verify file is created and active
    final file = File('${tempDir.path}/${MapDownloaderService.mapFileName}');
    expect(file.existsSync(), isTrue);
    expect(find.text('Aktīva & gatava bezsaistei'), findsOneWidget);
  });
}
