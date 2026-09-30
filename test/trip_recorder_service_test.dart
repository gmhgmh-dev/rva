import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rva/models/voice_alert_event.dart';
import 'package:rva/services/driving_assistant_manager.dart';
import 'package:rva/services/settings_service.dart';
import 'package:rva/services/trip_recorder_service.dart';
import 'package:rva/services/mock_location_service.dart';
import 'package:rva/services/tts_service.dart';

class FakeTtsService extends TtsService {
  @override
  Future<void> init() async {}
  @override
  Future<void> speak(String text) async {}
  @override
  Future<void> stop() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late TripRecorderService tripRecorder;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    tempDir = await Directory.systemTemp.createTemp('rva_trip_test_');
    tripRecorder = TripRecorderService(customStorageDir: tempDir);
  });

  tearDown(() async {
    await tripRecorder.stopRecording();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('TripRecorderService records virtual simulation alerts log with custom tag and header', () async {
    await tripRecorder.startRecording(
      recordGpx: false,
      recordLog: true,
      sessionTag: 'sim_test_route',
      sourceDescription: 'GPX simulācija: Mans_GPX_Brauciens.gpx',
    );

    expect(tripRecorder.isRecording, true);

    final simulatedTimestamp = DateTime(2026, 9, 30, 14, 30, 45);
    final alert = VoiceAlertEvent(
      timestamp: simulatedTimestamp,
      type: VoiceAlertType.speedReduced,
      spokenText: 'Ierobežojums 30 kilometri stundā.',
      speedLimitKmh: 30,
      streetName: 'Lielā iela',
    );

    tripRecorder.recordAlert(alert, customTime: simulatedTimestamp);

    final logFile = await tripRecorder.stopRecording();
    expect(logFile, isNotNull);
    expect(tripRecorder.isRecording, false);
    expect(tripRecorder.lastCompletedLogFile?.path, logFile!.path);

    expect(logFile.existsSync(), true);
    expect(logFile.path.contains('alerts_sim_test_route_'), true);

    final content = await logFile.readAsString();
    expect(content.contains('Brauciena brīdinājumi (GPX simulācija: Mans_GPX_Brauciens.gpx)'), true);
    expect(content.contains('[2026-09-30 14:30:45]'), true);
    expect(content.contains('Ierobežojums 30 kilometri stundā.'), true);
  });

  test('MockLocationService triggers simulationCompleteStream when route finishes', () async {
    final mockService = MockLocationService();
    bool completedFired = false;

    mockService.simulationCompleteStream.listen((_) {
      completedFired = true;
    });

    // Start with short interval and advance quickly
    await mockService.startSimulation(interval: const Duration(milliseconds: 10));

    // Wait briefly for all waypoints to be traversed
    int attempts = 0;
    while (!completedFired && attempts < 50) {
      await Future.delayed(const Duration(milliseconds: 30));
      attempts++;
    }

    expect(completedFired, true);
    expect(mockService.isRunning, false);
    mockService.dispose();
  });

  test('DrivingAssistantManager logs alerts during simulation and returns log file upon completion', () async {
    final settings = SettingsService();
    await settings.setRecordAlertLogs(true);
    await settings.setRecordVirtualAlertLogs(true);

    final manager = DrivingAssistantManager(
      settingsService: settings,
      tripRecorderService: tripRecorder,
      ttsService: FakeTtsService(),
    );

    await manager.startVentspilsTestRoute(interval: const Duration(milliseconds: 10));
    expect(manager.mode, DriveMode.mockSimulation);
    expect(tripRecorder.isRecording, true);

    // Wait for simulation to run and log
    await Future.delayed(const Duration(milliseconds: 150));
    final stoppedLog = await manager.stop();

    expect(stoppedLog, isNotNull);
    expect(stoppedLog!.existsSync(), true);
    final content = await stoppedLog.readAsString();
    expect(content.contains('Simulācija: Ventspils testa maršruts'), true);
    manager.dispose();
  });
}
