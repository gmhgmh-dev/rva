import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/road_point.dart';
import '../models/voice_alert_event.dart';
import 'map_downloader_service.dart';
import 'mock_location_service.dart';
import 'pmtiles_service.dart';
import 'real_location_service.dart';
import 'tts_service.dart';
import 'voice_assistant_state_machine.dart';

enum DriveMode {
  idle,
  mockSimulation,
  realGps,
}

/// Orchestrator coordinating Location updates, State Machine transitions,
/// and Latvian Text-To-Speech announcements.
class DrivingAssistantManager extends ChangeNotifier {
  final VoiceAssistantStateMachine stateMachine;
  final MockLocationService mockLocationService;
  final RealLocationService realLocationService;
  final TtsService ttsService;
  final PMTilesService pmTilesService;
  final MapDownloaderService mapDownloaderService;

  DriveMode _mode = DriveMode.idle;
  RoadPoint? _currentPoint;
  final List<VoiceAlertEvent> _alertHistory = [];
  StreamSubscription<RoadPoint>? _locationSubscription;
  bool _isMuted = false;

  DrivingAssistantManager({
    VoiceAssistantStateMachine? stateMachine,
    MockLocationService? mockLocationService,
    RealLocationService? realLocationService,
    TtsService? ttsService,
    PMTilesService? pmTilesService,
    MapDownloaderService? mapDownloaderService,
  }) : this._internal(
          stateMachine: stateMachine ?? VoiceAssistantStateMachine(),
          mockLocationService: mockLocationService ?? MockLocationService(),
          ttsService: ttsService ?? TtsService(),
          pmTilesService: pmTilesService ?? PMTilesService(),
          mapDownloaderService: mapDownloaderService ?? MapDownloaderService(),
          realLocationService: realLocationService,
        );

  DrivingAssistantManager._internal({
    required this.stateMachine,
    required this.mockLocationService,
    required this.ttsService,
    required this.pmTilesService,
    required this.mapDownloaderService,
    RealLocationService? realLocationService,
  }) : realLocationService = realLocationService ??
            RealLocationService(pmTilesService: pmTilesService);

  DriveMode get mode => _mode;
  RoadPoint? get currentPoint => _currentPoint;
  List<VoiceAlertEvent> get alertHistory => List.unmodifiable(_alertHistory);
  bool get isMuted => _isMuted;
  int? get currentMaxSpeed => stateMachine.currentMaxSpeed;
  bool get isOneWay => stateMachine.isOneWay;
  bool get isInReducedSpeedZone => stateMachine.isInReducedSpeedZone;
  bool get isOfflineMapLoaded => pmTilesService.isLoaded;

  Future<void> init({bool loadAsset = true}) async {
    await ttsService.init();
    if (loadAsset) {
      await mockLocationService.loadRoute();
    }
    await tryLoadOfflineMap();
  }

  /// Attempts to open the local latvia.pmtiles file if downloaded.
  Future<bool> tryLoadOfflineMap() async {
    try {
      if (await mapDownloaderService.isMapDownloaded()) {
        final file = await mapDownloaderService.getLocalMapFile();
        await pmTilesService.openArchive(file);
        notifyListeners();
        return true;
      }
    } catch (e) {
      debugPrint('Failed to load local PMTiles map: $e');
    }
    return false;
  }

  void toggleMute() {
    _isMuted = !_isMuted;
    notifyListeners();
  }

  /// Starts the Ventspils Mock Test Route simulation covering all 4 triggers sequentially.
  Future<void> startVentspilsTestRoute({Duration interval = const Duration(seconds: 2)}) async {
    await stop();
    _currentPoint = null;
    stateMachine.reset();
    _alertHistory.clear();
    _mode = DriveMode.mockSimulation;
    notifyListeners();

    _locationSubscription = mockLocationService.locationStream.listen(_onNewRoadPoint);
    await mockLocationService.startSimulation(interval: interval);
  }

  /// Manually advance one waypoint in the simulation (helpful for testing or stepping through).
  void stepNextMockPoint() {
    if (_mode != DriveMode.mockSimulation) {
      stateMachine.reset();
      _alertHistory.clear();
      _mode = DriveMode.mockSimulation;
      _locationSubscription?.cancel();
      _locationSubscription = mockLocationService.locationStream.listen(_onNewRoadPoint);
      notifyListeners();
    }
    mockLocationService.nextStep();
  }

  /// Starts tracking using the device's real GPS sensors.
  Future<bool> startRealGps() async {
    await stop();
    _currentPoint = null;
    stateMachine.reset();
    _alertHistory.clear();

    final started = await realLocationService.startTracking();
    if (started) {
      _mode = DriveMode.realGps;
      _locationSubscription = realLocationService.locationStream.listen(_onNewRoadPoint);
      notifyListeners();
      return true;
    } else {
      _mode = DriveMode.idle;
      notifyListeners();
      return false;
    }
  }

  /// Stops any active driving mode and speech.
  Future<void> stop() async {
    _locationSubscription?.cancel();
    _locationSubscription = null;
    mockLocationService.stopSimulation();
    await realLocationService.stopTracking();
    await ttsService.stop();
    _currentPoint = null;
    _mode = DriveMode.idle;
    notifyListeners();
  }

  /// Central point handler: feeds state machine, triggers voice, and logs event.
  void _onNewRoadPoint(RoadPoint point) {
    _currentPoint = point;

    final events = stateMachine.processRoadPoint(point);
    for (final event in events) {
      _alertHistory.insert(0, event);
      if (!_isMuted) {
        ttsService.speak(event.spokenText);
      }
    }

    notifyListeners();
  }

  @override
  void dispose() {
    stop();
    mockLocationService.dispose();
    realLocationService.dispose();
    ttsService.dispose();
    pmTilesService.close();
    mapDownloaderService.dispose();
    super.dispose();
  }
}
