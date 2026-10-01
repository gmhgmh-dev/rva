import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import '../data/ventspils_traffic_nodes.dart';
import '../models/lookahead_event.dart';
import '../models/road_point.dart';
import '../models/voice_alert_event.dart';
import 'map_downloader_service.dart';
import 'mock_location_service.dart';
import 'pmtiles_service.dart';
import 'real_location_service.dart';
import 'tts_service.dart';
import 'voice_assistant_state_machine.dart';

import 'package:audioplayers/audioplayers.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'settings_service.dart';
import 'trip_recorder_service.dart';

enum DriveMode {
  idle,
  mockSimulation,
  realGps,
}

/// Orchestrator coordinating Location updates, State Machine transitions,
/// and Latvian Text-To-Speech announcements.
class DrivingAssistantManager extends ChangeNotifier {
  final SettingsService settingsService;
  late final VoiceAssistantStateMachine stateMachine;
  final MockLocationService mockLocationService;
  final RealLocationService realLocationService;
  final TtsService ttsService;
  final PMTilesService pmTilesService;
  final MapDownloaderService mapDownloaderService;
  final TripRecorderService tripRecorderService;
  AudioPlayer? _audioPlayer;
  AudioPlayer get audioPlayer => _audioPlayer ??= AudioPlayer();

  DriveMode _mode = DriveMode.idle;
  RoadPoint? _currentPoint;
  final List<VoiceAlertEvent> _alertHistory = [];
  StreamSubscription<RoadPoint>? _locationSubscription;
  StreamSubscription<void>? _simulationCompleteSub;
  final StreamController<File?> _simulationFinishedController = StreamController<File?>.broadcast();
  bool _isMuted = false;

  Stream<File?> get simulationFinishedStream => _simulationFinishedController.stream;

  DrivingAssistantManager({
    SettingsService? settingsService,
    VoiceAssistantStateMachine? stateMachine,
    MockLocationService? mockLocationService,
    RealLocationService? realLocationService,
    TtsService? ttsService,
    PMTilesService? pmTilesService,
    MapDownloaderService? mapDownloaderService,
    TripRecorderService? tripRecorderService,
  })  : settingsService = settingsService ?? SettingsService(),
        mockLocationService = mockLocationService ?? MockLocationService(),
        ttsService = ttsService ?? TtsService(),
        pmTilesService = pmTilesService ?? PMTilesService(),
        mapDownloaderService = mapDownloaderService ?? MapDownloaderService(),
        tripRecorderService = tripRecorderService ?? TripRecorderService(),
        realLocationService = realLocationService ?? RealLocationService(pmTilesService: pmTilesService ?? PMTilesService()) {
    this.stateMachine = stateMachine ??
        VoiceAssistantStateMachine(
          announceStreetChanges: this.settingsService.announceStreetChanges,
          useDynamicPhrases: this.settingsService.useDynamicPhrases,
          alertStyle: this.settingsService.voiceAlertStyle,
        );
        
    this.settingsService.addListener(_onSettingsChanged);

    _simulationCompleteSub = this.mockLocationService.simulationCompleteStream.listen((_) async {
      if (_mode == DriveMode.mockSimulation) {
        final logFile = await this.tripRecorderService.stopRecording();
        _mode = DriveMode.idle;
        _updateWakelock();
        _simulationFinishedController.add(logFile);
        notifyListeners();
      }
    });
  }

  void _onSettingsChanged() {
    stateMachine.announceStreetChanges = settingsService.announceStreetChanges;
    stateMachine.useDynamicPhrases = settingsService.useDynamicPhrases;
    stateMachine.alertStyle = settingsService.voiceAlertStyle;
    _isMuted = settingsService.isMuted;
    
    realLocationService.roadSearchRadiusMeters = settingsService.roadSearchRadiusMeters;
    realLocationService.courtyardSearchRadiusMeters = settingsService.courtyardSearchRadiusMeters;
    realLocationService.customLookaheadDistance = settingsService.lookaheadDistanceMeters;
    realLocationService.filterStaleGpsFixes = settingsService.filterStaleGpsFixes;
    realLocationService.staleGpsTimeoutSeconds = settingsService.staleGpsTimeoutSeconds;
    realLocationService.prioritizePedestrianAndCycleways = settingsService.prioritizePedestrianAndCycleways;

    ttsService.applySettings(
      engine: settingsService.ttsEngine,
      voiceName: settingsService.ttsVoiceName,
      voiceLocale: settingsService.ttsVoiceLocale,
      speechRate: settingsService.ttsSpeechRate,
      pitch: settingsService.ttsPitch,
      audioDucking: settingsService.audioDucking,
    );

    _updateWakelock();
    
    notifyListeners();
  }

  void _updateWakelock() {
    try {
      if (settingsService.keepScreenOn && _mode != DriveMode.idle) {
        WakelockPlus.enable().catchError((_) {});
      } else {
        WakelockPlus.disable().catchError((_) {});
      }
    } catch (_) {}
  }


  DriveMode get mode => _mode;
  RoadPoint? get currentPoint => _currentPoint;
  List<VoiceAlertEvent> get alertHistory => List.unmodifiable(_alertHistory);
  bool get isMuted => _isMuted;
  int? get currentMaxSpeed => stateMachine.currentMaxSpeed;
  bool get isOneWay => stateMachine.isOneWay;
  bool get isInReducedSpeedZone => stateMachine.isInReducedSpeedZone;
  bool get isInLivingStreetZone => stateMachine.isInLivingStreetZone;
  bool get isIn30SpeedZone => stateMachine.isIn30SpeedZone;
  String? get currentStreetName => stateMachine.currentStreetName;
  bool get isInPedestrianOrBicycleWay => stateMachine.isInPedestrianOrBicycleWay;
  bool get isCycleway => _currentPoint?.isCycleway ?? false;
  bool get isFootway => (_currentPoint?.isFootway ?? false) || (_currentPoint?.isPath ?? false);
  bool get isOfflineMapLoaded => pmTilesService.isLoaded;

  Future<void> init({bool loadAsset = true}) async {
    try {
      await ttsService.init();
    } catch (e) {
      debugPrint('Warning: Initial TTS init error (non-fatal): $e');
    }

    try {
      await settingsService.loadSettings();
    } catch (e) {
      debugPrint('Warning: Settings load error (non-fatal): $e');
    }

    try {
      _onSettingsChanged(); // Apply initial settings to stateMachine and TTS
    } catch (e) {
      debugPrint('Warning: _onSettingsChanged error (non-fatal): $e');
    }

    if (loadAsset) {
      try {
        await mockLocationService.loadRoute();
      } catch (e) {
        debugPrint('Warning: mockLocationService loadRoute error: $e');
      }
    }

    try {
      await tryLoadOfflineMap();
    } catch (e) {
      debugPrint('Warning: tryLoadOfflineMap error: $e');
    }
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

  /// Announces current street name and speed limit dynamically via TTS.
  void announceCurrentStreetInfo() {
    if (_currentPoint != null && !_isMuted) {
      final text = VoiceAssistantStateMachine.formatStreetAnnouncement(
        streetName: _currentPoint!.streetName,
        maxSpeed: _currentPoint!.maxSpeedLimitKmh,
      );
      ttsService.speak(text);
    }
  }

  /// Starts the Ventspils Mock Test Route simulation covering all 4 triggers sequentially.
  Future<void> startVentspilsTestRoute({Duration interval = const Duration(seconds: 2)}) async {
    await stop();
    _currentPoint = null;
    stateMachine.reset();
    _alertHistory.clear();
    _mode = DriveMode.mockSimulation;
    _updateWakelock();

    if (settingsService.recordAlertLogs && settingsService.recordVirtualAlertLogs) {
      await tripRecorderService.startRecording(
        recordGpx: false,
        recordLog: true,
        sessionTag: 'sim_ventspils',
        sourceDescription: 'Simulācija: Ventspils testa maršruts',
      );
    }

    notifyListeners();

    _locationSubscription = mockLocationService.locationStream.listen(_onNewRoadPoint);
    await mockLocationService.startSimulation(interval: interval);
  }

  /// Starts a simulation from a specific GPX File
  Future<int> startSimulationFromFile(File file, {Duration interval = const Duration(seconds: 1)}) async {
    await stop();
    _currentPoint = null;
    stateMachine.reset();
    _alertHistory.clear();
    _mode = DriveMode.mockSimulation;
    _updateWakelock();

    final count = await mockLocationService.loadRouteFromFile(file);

    if (settingsService.recordAlertLogs && settingsService.recordVirtualAlertLogs) {
      final fileName = file.path.split(Platform.pathSeparator).last;
      final cleanBase = fileName.replaceAll('.gpx', '').replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
      await tripRecorderService.startRecording(
        recordGpx: false,
        recordLog: true,
        sessionTag: 'sim_$cleanBase',
        sourceDescription: 'GPX simulācija: $fileName',
      );
    }

    notifyListeners();

    _locationSubscription = mockLocationService.locationStream.listen(_onNewRoadPoint);
    await mockLocationService.startSimulation(interval: interval);
    return count;
  }

  /// Manually advance one waypoint in the simulation (helpful for testing or stepping through).
  void stepNextMockPoint() {
    if (_mode != DriveMode.mockSimulation) {
      stateMachine.reset();
      _alertHistory.clear();
      _mode = DriveMode.mockSimulation;
      _locationSubscription?.cancel();
      _locationSubscription = mockLocationService.locationStream.listen(_onNewRoadPoint);
      if (settingsService.recordAlertLogs && settingsService.recordVirtualAlertLogs) {
        tripRecorderService.startRecording(
          recordGpx: false,
          recordLog: true,
          sessionTag: 'sim_manual',
          sourceDescription: 'Manuāla pārbaude pa soļiem',
        );
      }
      notifyListeners();
    }
    mockLocationService.nextStep();
  }

  bool _firstRealPointAnnounced = false;

  /// Starts tracking using the device's real GPS sensors.
  Future<bool> startRealGps() async {
    await stop();
    _currentPoint = null;
    stateMachine.reset();
    _alertHistory.clear();
    _firstRealPointAnnounced = false;

    // Apply latest user-configured search radii and filters
    realLocationService.roadSearchRadiusMeters = settingsService.roadSearchRadiusMeters;
    realLocationService.courtyardSearchRadiusMeters = settingsService.courtyardSearchRadiusMeters;
    realLocationService.customLookaheadDistance = settingsService.lookaheadDistanceMeters;
    realLocationService.filterStaleGpsFixes = settingsService.filterStaleGpsFixes;
    realLocationService.staleGpsTimeoutSeconds = settingsService.staleGpsTimeoutSeconds;
    realLocationService.prioritizePedestrianAndCycleways = settingsService.prioritizePedestrianAndCycleways;

    final started = await realLocationService.startTracking();
    if (started) {
      _mode = DriveMode.realGps;
      await tripRecorderService.startRecording(
        recordGpx: settingsService.recordGpx,
        recordLog: settingsService.recordAlertLogs,
      );
      _locationSubscription = realLocationService.locationStream.listen(_onNewRoadPoint);
      _updateWakelock();
      notifyListeners();
      return true;
    } else {
      _mode = DriveMode.idle;
      _updateWakelock();
      notifyListeners();
      return false;
    }
  }

  /// Stops any active driving mode and speech.
  Future<File?> stop() async {
    _locationSubscription?.cancel();
    _locationSubscription = null;
    mockLocationService.stopSimulation();
    await realLocationService.stopTracking();
    final logFile = await tripRecorderService.stopRecording();
    await ttsService.stop();
    _currentPoint = null;
    _firstRealPointAnnounced = false;
    _mode = DriveMode.idle;
    _updateWakelock();
    notifyListeners();
    return logFile;
  }

  /// Central point handler: feeds state machine, triggers voice, and logs event.
  void _onNewRoadPoint(RoadPoint point) async {
    // Keep real location service settings in sync with current street & radius preferences
    realLocationService.roadSearchRadiusMeters = settingsService.roadSearchRadiusMeters;
    realLocationService.courtyardSearchRadiusMeters = settingsService.courtyardSearchRadiusMeters;
    realLocationService.customLookaheadDistance = settingsService.lookaheadDistanceMeters;
    realLocationService.filterStaleGpsFixes = settingsService.filterStaleGpsFixes;
    realLocationService.staleGpsTimeoutSeconds = settingsService.staleGpsTimeoutSeconds;
    realLocationService.prioritizePedestrianAndCycleways = settingsService.prioritizePedestrianAndCycleways;
    realLocationService.currentRoadName = stateMachine.currentStreetName;

    RoadPoint effectivePoint = point;

    // During GPX file simulation, ground coordinates in PMTiles offline vector map
    // so real offline map attributes (streets, limits, one-way, bike/foot paths) are evaluated.
    if (_mode == DriveMode.mockSimulation && pmTilesService.isLoaded) {
      try {
        final roadAttr = await pmTilesService.getRoadAttributes(
          point.latitude,
          point.longitude,
          maxRadiusMeters: settingsService.roadSearchRadiusMeters,
          courtyardRadiusMeters: settingsService.courtyardSearchRadiusMeters,
          currentRoadName: stateMachine.currentStreetName,
          vehicleHeading: point.heading,
          vehicleSpeedKmh: point.vehicleSpeedKmh,
          prioritizePedestrianAndCycleways: settingsService.prioritizePedestrianAndCycleways,
        );
        if (roadAttr != null) {
          effectivePoint = point.copyWith(
            streetName: roadAttr.name ?? point.streetName,
            maxSpeedLimitKmh: roadAttr.maxspeed ?? point.maxSpeedLimitKmh,
            isOneWay: roadAttr.isOneWay,
            roadClass: roadAttr.roadClass ?? point.roadClass,
            isZone: roadAttr.isZone,
            isCycleway: roadAttr.isCycleway,
            isFootway: roadAttr.isFootway,
            isPath: roadAttr.isPath,
            hasTrafficCalmingAhead: roadAttr.hasTrafficCalming,
            trafficCalmingAheadType: roadAttr.trafficCalmingType,
          );
        }

        if (point.heading != null && point.vehicleSpeedKmh >= 8.0) {
          final lookaheadDist = settingsService.lookaheadDistanceMeters;
          final projectedCoord = PMTilesService.calculateLookaheadCoordinate(
            point.latitude,
            point.longitude,
            point.heading!,
            lookaheadDist,
          );
          final lookaheadAttrs = await pmTilesService.getLookaheadRoadAttributes(
            point.latitude,
            point.longitude,
            heading: point.heading!,
            speedKmh: point.vehicleSpeedKmh,
            customLookaheadDistance: lookaheadDist,
            currentRoadName: roadAttr?.name ?? stateMachine.currentStreetName,
          );
          int? lookaheadMaxSpeed;
          if (lookaheadAttrs != null) {
            lookaheadMaxSpeed = RealLocationService.resolveSpeedLimit(
              lat: projectedCoord.lat,
              lon: projectedCoord.lon,
              explicitMaxspeed: lookaheadAttrs.maxspeed,
              streetName: lookaheadAttrs.name,
              roadClass: lookaheadAttrs.roadClass,
            );
          }

          final lookaheadEvents = await pmTilesService.getLookaheadEvents(
            point.latitude,
            point.longitude,
            heading: point.heading!,
            speedKmh: point.vehicleSpeedKmh,
            customLookaheadDistance: lookaheadDist,
            currentRoadName: stateMachine.currentStreetName,
          );
          final offlineNodes = VentspilsTrafficNodes.findUpcomingNodes(
            lat: point.latitude,
            lon: point.longitude,
            heading: point.heading!,
            lookaheadDist: lookaheadDist,
            includeTrafficLights: settingsService.lookaheadTrafficLights,
            includeGiveWay: settingsService.lookaheadGiveWay,
            includeTrafficCalming: settingsService.trafficCalmingAlerts,
            includePedestrianCrossings: settingsService.lookaheadPedestrianCrossings,
          );
          final allEvents = [...lookaheadEvents, ...offlineNodes];

          final hasTrafficCalming = (roadAttr?.hasTrafficCalming ?? false) ||
              (lookaheadAttrs?.hasTrafficCalming ?? false) ||
              allEvents.any((n) => n.type == LookaheadEventType.trafficCalming);
          final trafficCalmingType = roadAttr?.trafficCalmingType ??
              lookaheadAttrs?.trafficCalmingType ??
              (allEvents.any((n) => n.type == LookaheadEventType.trafficCalming) ? 'bump' : null);

          effectivePoint = effectivePoint.copyWith(
            lookaheadMaxSpeed: lookaheadMaxSpeed,
            lookaheadDistanceMeters: lookaheadDist,
            lookaheadEvents: allEvents,
            hasTrafficCalmingAhead: hasTrafficCalming,
            trafficCalmingAheadType: trafficCalmingType,
          );
        }
      } catch (e) {
        debugPrint('PMTiles lookup error during simulation: $e');
      }
    }

    _currentPoint = effectivePoint;

    // Record the point for GPX
    if (_mode == DriveMode.realGps) {
      tripRecorderService.recordPoint(effectivePoint);
    }

    final events = stateMachine.processRoadPoint(
      effectivePoint,
      speedTolerance: settingsService.speedTolerance,
      toleranceMode: settingsService.speedToleranceMode,
      speedTolerancePercentage: settingsService.speedTolerancePercentage,
      speedWarningInterval: settingsService.speedWarningInterval,
      streetChangeDistanceMeters: settingsService.streetChangeDistanceMeters,
      streetChangeConfirmations: settingsService.streetChangeConfirmations,
      speedRestorationConfirmations: settingsService.speedRestorationConfirmations,
      oneWayExitConfirmations: settingsService.oneWayExitConfirmations,
      lookaheadAlertsEnabled: settingsService.lookaheadAlerts,
      lookaheadTrafficLights: settingsService.lookaheadTrafficLights,
      lookaheadGiveWay: settingsService.lookaheadGiveWay,
      lookaheadIntersections: settingsService.lookaheadIntersections,
      trafficCalmingAlertsEnabled: settingsService.trafficCalmingAlerts,
      speedCameraAlertsEnabled: settingsService.speedCameraAlerts,
      lookaheadPedestrianCrossings: settingsService.lookaheadPedestrianCrossings,
      enableSpeedAdaptiveDistance: settingsService.enableSpeedAdaptiveDistance,
    );

    // Announce initial street and limit when acquiring the first real GPS fix
    if (_mode == DriveMode.realGps && !_firstRealPointAnnounced && !_isMuted) {
      _firstRealPointAnnounced = true;
      if (events.isEmpty) {
        final text = VoiceAssistantStateMachine.formatStreetAnnouncement(
          streetName: effectivePoint.streetName,
          maxSpeed: effectivePoint.maxSpeedLimitKmh,
        );
        ttsService.speak(text);
      }
    }

    for (final event in events) {
      _alertHistory.insert(0, event);
      if (_mode == DriveMode.realGps || _mode == DriveMode.mockSimulation) {
        tripRecorderService.recordAlert(event);
      }
      if (!_isMuted) {
        if (event.type == VoiceAlertType.speedingWarning && settingsService.speedingBeepOnly) {
          audioPlayer.play(AssetSource('beep.wav'));
        } else {
          ttsService.speak(event.spokenText);
        }
      }
    }

    notifyListeners();
  }

  @override
  void dispose() {
    settingsService.removeListener(_onSettingsChanged);
    _simulationCompleteSub?.cancel();
    _simulationFinishedController.close();
    _locationSubscription?.cancel();
    _locationSubscription = null;
    mockLocationService.stopSimulation();
    realLocationService.stopTracking();
    tripRecorderService.stopRecording();
    ttsService.stop();
    _mode = DriveMode.idle;
    _updateWakelock();
    mockLocationService.dispose();
    realLocationService.dispose();
    ttsService.dispose();
    pmTilesService.close();
    mapDownloaderService.dispose();
    _audioPlayer?.dispose();
    super.dispose();
  }
}
