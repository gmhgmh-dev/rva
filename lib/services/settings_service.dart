import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum SpeedToleranceMode {
  fixed,
  percentage,
}

class SettingsService extends ChangeNotifier {
  static const String appVersion = '0.2.1';

  static const _keyUseDynamicPhrases = 'use_dynamic_phrases';
  static const _keyAnnounceStreetChanges = 'announce_street_changes';
  static const _keyIsMuted = 'is_muted';
  static const _keySpeedTolerance = 'speed_tolerance';
  static const _keySpeedToleranceMode = 'speed_tolerance_mode';
  static const _keySpeedTolerancePercentage = 'speed_tolerance_percentage';
  static const _keySpeedingBeepOnly = 'speeding_beep_only';
  static const _keySpeedWarningInterval = 'speed_warning_interval';
  static const _keyAutoStartGps = 'auto_start_gps';
  static const _keyKeepScreenOn = 'keep_screen_on';
  static const _keyRecordGpx = 'record_gpx';
  static const _keyRecordAlertLogs = 'record_alert_logs';
  static const _keyRoadSearchRadiusMeters = 'road_search_radius_meters';
  static const _keyCourtyardSearchRadiusMeters = 'courtyard_search_radius_meters';
  static const _keyStreetChangeDistanceMeters = 'street_change_distance_meters';
  static const _keyStreetChangeConfirmations = 'street_change_confirmations';
  static const _keySpeedRestorationConfirmations = 'speed_restoration_confirmations';
  static const _keyOneWayExitConfirmations = 'one_way_exit_confirmations';
  static const _keyFilterStaleGpsFixes = 'filter_stale_gps_fixes';
  static const _keyStaleGpsTimeoutSeconds = 'stale_gps_timeout_seconds';
  static const _keyPrioritizePedestrianAndCycleways = 'prioritize_pedestrian_cycleways';
  static const _keyAudioDucking = 'audio_ducking';
  static const _keyLookaheadAlerts = 'lookahead_alerts';
  static const _keyLookaheadDistanceMeters = 'lookahead_distance_meters';
  static const _keyTrafficCalmingAlerts = 'traffic_calming_alerts';
  static const _keySpeedCameraAlerts = 'speed_camera_alerts';

  bool _useDynamicPhrases = true;
  bool _announceStreetChanges = true;
  bool _isMuted = false;
  int _speedTolerance = 0; // +0 km/h default
  SpeedToleranceMode _speedToleranceMode = SpeedToleranceMode.fixed;
  double _speedTolerancePercentage = 5.0; // 5.0% default
  bool _speedingBeepOnly = false;
  int _speedWarningInterval = 10; // 10s default
  bool _autoStartGps = false;
  bool _keepScreenOn = false;
  bool _recordGpx = false;
  bool _recordAlertLogs = false;
  double _roadSearchRadiusMeters = 40.0; // Recommended default 40m
  double _courtyardSearchRadiusMeters = 15.0; // Recommended default 15m
  double _streetChangeDistanceMeters = 35.0; // Recommended default 35m for scooter & car
  int _streetChangeConfirmations = 4; // Recommended default: 4 points (~4s)
  int _speedRestorationConfirmations = 4; // Recommended default: 4 points (~4s)
  int _oneWayExitConfirmations = 3; // Recommended default: 3 points (~3s)
  bool _filterStaleGpsFixes = true; // Recommended default: true
  int _staleGpsTimeoutSeconds = 5; // Recommended default: 5s
  bool _prioritizePedestrianAndCycleways = false; // Recommended default: false (car mode)
  bool _audioDucking = true; // Recommended default: true
  bool _lookaheadAlerts = true; // Recommended default: true
  double _lookaheadDistanceMeters = 70.0; // Recommended default: 70m
  bool _trafficCalmingAlerts = true; // Recommended default: true
  bool _speedCameraAlerts = true; // Recommended default: true

  bool get useDynamicPhrases => _useDynamicPhrases;
  bool get announceStreetChanges => _announceStreetChanges;
  bool get isMuted => _isMuted;
  int get speedTolerance => _speedTolerance;
  SpeedToleranceMode get speedToleranceMode => _speedToleranceMode;
  double get speedTolerancePercentage => _speedTolerancePercentage;
  bool get speedingBeepOnly => _speedingBeepOnly;
  int get speedWarningInterval => _speedWarningInterval;
  bool get autoStartGps => _autoStartGps;
  bool get keepScreenOn => _keepScreenOn;
  bool get recordGpx => _recordGpx;
  bool get recordAlertLogs => _recordAlertLogs;
  double get roadSearchRadiusMeters => _roadSearchRadiusMeters;
  double get courtyardSearchRadiusMeters => _courtyardSearchRadiusMeters;
  double get streetChangeDistanceMeters => _streetChangeDistanceMeters;
  int get streetChangeConfirmations => _streetChangeConfirmations;
  int get speedRestorationConfirmations => _speedRestorationConfirmations;
  int get oneWayExitConfirmations => _oneWayExitConfirmations;
  bool get filterStaleGpsFixes => _filterStaleGpsFixes;
  int get staleGpsTimeoutSeconds => _staleGpsTimeoutSeconds;
  bool get prioritizePedestrianAndCycleways => _prioritizePedestrianAndCycleways;
  bool get audioDucking => _audioDucking;
  bool get lookaheadAlerts => _lookaheadAlerts;
  double get lookaheadDistanceMeters => _lookaheadDistanceMeters;
  bool get trafficCalmingAlerts => _trafficCalmingAlerts;
  bool get speedCameraAlerts => _speedCameraAlerts;

  /// Returns the effective speed tolerance in km/h for a given road speed limit.
  double calculateEffectiveTolerance(int speedLimitKmh) {
    if (_speedToleranceMode == SpeedToleranceMode.percentage) {
      return speedLimitKmh * (_speedTolerancePercentage / 100.0);
    }
    return _speedTolerance.toDouble();
  }

  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _useDynamicPhrases = prefs.getBool(_keyUseDynamicPhrases) ?? true;
    _announceStreetChanges = prefs.getBool(_keyAnnounceStreetChanges) ?? true;
    _isMuted = prefs.getBool(_keyIsMuted) ?? false;
    _speedTolerance = prefs.getInt(_keySpeedTolerance) ?? 0;
    
    final modeStr = prefs.getString(_keySpeedToleranceMode);
    if (modeStr == SpeedToleranceMode.percentage.name) {
      _speedToleranceMode = SpeedToleranceMode.percentage;
    } else {
      _speedToleranceMode = SpeedToleranceMode.fixed;
    }
    _speedTolerancePercentage = prefs.getDouble(_keySpeedTolerancePercentage) ?? 5.0;

    _speedingBeepOnly = prefs.getBool(_keySpeedingBeepOnly) ?? false;
    _speedWarningInterval = prefs.getInt(_keySpeedWarningInterval) ?? 10;
    _autoStartGps = prefs.getBool(_keyAutoStartGps) ?? false;
    _keepScreenOn = prefs.getBool(_keyKeepScreenOn) ?? false;
    _recordGpx = prefs.getBool(_keyRecordGpx) ?? false;
    _recordAlertLogs = prefs.getBool(_keyRecordAlertLogs) ?? false;
    _roadSearchRadiusMeters = (prefs.getDouble(_keyRoadSearchRadiusMeters) ?? 40.0).clamp(10.0, 150.0);
    _courtyardSearchRadiusMeters = (prefs.getDouble(_keyCourtyardSearchRadiusMeters) ?? 15.0).clamp(5.0, 40.0);
    _streetChangeDistanceMeters = (prefs.getDouble(_keyStreetChangeDistanceMeters) ?? 35.0).clamp(15.0, 100.0);
    _streetChangeConfirmations = (prefs.getInt(_keyStreetChangeConfirmations) ?? 4).clamp(1, 10);
    _speedRestorationConfirmations = (prefs.getInt(_keySpeedRestorationConfirmations) ?? 4).clamp(1, 10);
    _oneWayExitConfirmations = (prefs.getInt(_keyOneWayExitConfirmations) ?? 3).clamp(1, 10);
    _filterStaleGpsFixes = prefs.getBool(_keyFilterStaleGpsFixes) ?? true;
    _staleGpsTimeoutSeconds = (prefs.getInt(_keyStaleGpsTimeoutSeconds) ?? 5).clamp(1, 30);
    _prioritizePedestrianAndCycleways = prefs.getBool(_keyPrioritizePedestrianAndCycleways) ?? false;
    _audioDucking = prefs.getBool(_keyAudioDucking) ?? true;
    _lookaheadAlerts = prefs.getBool(_keyLookaheadAlerts) ?? true;
    _lookaheadDistanceMeters = (prefs.getDouble(_keyLookaheadDistanceMeters) ?? 70.0).clamp(30.0, 150.0);
    _trafficCalmingAlerts = prefs.getBool(_keyTrafficCalmingAlerts) ?? true;
    _speedCameraAlerts = prefs.getBool(_keySpeedCameraAlerts) ?? true;
    notifyListeners();
  }

  Future<void> setUseDynamicPhrases(bool value) async {
    _useDynamicPhrases = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyUseDynamicPhrases, value);
    notifyListeners();
  }

  Future<void> setAnnounceStreetChanges(bool value) async {
    _announceStreetChanges = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyAnnounceStreetChanges, value);
    notifyListeners();
  }

  Future<void> setIsMuted(bool value) async {
    _isMuted = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyIsMuted, value);
    notifyListeners();
  }

  Future<void> setSpeedTolerance(int value) async {
    _speedTolerance = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keySpeedTolerance, value);
    notifyListeners();
  }

  Future<void> setSpeedToleranceMode(SpeedToleranceMode value) async {
    _speedToleranceMode = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keySpeedToleranceMode, value.name);
    notifyListeners();
  }

  Future<void> setSpeedTolerancePercentage(double value) async {
    _speedTolerancePercentage = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keySpeedTolerancePercentage, value);
    notifyListeners();
  }

  Future<void> setSpeedingBeepOnly(bool value) async {
    _speedingBeepOnly = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keySpeedingBeepOnly, value);
    notifyListeners();
  }

  Future<void> setSpeedWarningInterval(int value) async {
    _speedWarningInterval = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keySpeedWarningInterval, value);
    notifyListeners();
  }

  Future<void> setAutoStartGps(bool value) async {
    _autoStartGps = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyAutoStartGps, value);
    notifyListeners();
  }

  Future<void> setKeepScreenOn(bool value) async {
    _keepScreenOn = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyKeepScreenOn, value);
    notifyListeners();
  }

  Future<void> setRecordGpx(bool value) async {
    _recordGpx = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyRecordGpx, value);
    notifyListeners();
  }

  Future<void> setRecordAlertLogs(bool value) async {
    _recordAlertLogs = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyRecordAlertLogs, value);
    notifyListeners();
  }

  Future<void> setRoadSearchRadiusMeters(double value) async {
    _roadSearchRadiusMeters = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyRoadSearchRadiusMeters, value);
    notifyListeners();
  }

  Future<void> setCourtyardSearchRadiusMeters(double value) async {
    _courtyardSearchRadiusMeters = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyCourtyardSearchRadiusMeters, value);
    notifyListeners();
  }

  Future<void> setStreetChangeDistanceMeters(double value) async {
    _streetChangeDistanceMeters = value.clamp(15.0, 100.0);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyStreetChangeDistanceMeters, _streetChangeDistanceMeters);
    notifyListeners();
  }

  Future<void> setStreetChangeConfirmations(int value) async {
    _streetChangeConfirmations = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyStreetChangeConfirmations, value);
    notifyListeners();
  }

  Future<void> setSpeedRestorationConfirmations(int value) async {
    _speedRestorationConfirmations = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keySpeedRestorationConfirmations, value);
    notifyListeners();
  }

  Future<void> setOneWayExitConfirmations(int value) async {
    _oneWayExitConfirmations = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyOneWayExitConfirmations, value);
    notifyListeners();
  }

  Future<void> setFilterStaleGpsFixes(bool value) async {
    _filterStaleGpsFixes = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyFilterStaleGpsFixes, value);
    notifyListeners();
  }

  Future<void> setStaleGpsTimeoutSeconds(int value) async {
    _staleGpsTimeoutSeconds = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyStaleGpsTimeoutSeconds, value);
    notifyListeners();
  }

  Future<void> setPrioritizePedestrianAndCycleways(bool value) async {
    _prioritizePedestrianAndCycleways = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyPrioritizePedestrianAndCycleways, value);
    notifyListeners();
  }

  Future<void> setAudioDucking(bool value) async {
    _audioDucking = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyAudioDucking, value);
    notifyListeners();
  }

  Future<void> setLookaheadAlerts(bool value) async {
    _lookaheadAlerts = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyLookaheadAlerts, value);
    notifyListeners();
  }

  Future<void> setLookaheadDistanceMeters(double value) async {
    _lookaheadDistanceMeters = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyLookaheadDistanceMeters, value);
    notifyListeners();
  }

  Future<void> setTrafficCalmingAlerts(bool value) async {
    _trafficCalmingAlerts = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyTrafficCalmingAlerts, value);
    notifyListeners();
  }

  Future<void> setSpeedCameraAlerts(bool value) async {
    _speedCameraAlerts = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keySpeedCameraAlerts, value);
    notifyListeners();
  }

  /// Exports all current user settings as a Map
  Map<String, dynamic> exportSettings() {
    return {
      _keyUseDynamicPhrases: _useDynamicPhrases,
      _keyAnnounceStreetChanges: _announceStreetChanges,
      _keyIsMuted: _isMuted,
      _keySpeedTolerance: _speedTolerance,
      _keySpeedToleranceMode: _speedToleranceMode.name,
      _keySpeedTolerancePercentage: _speedTolerancePercentage,
      _keySpeedingBeepOnly: _speedingBeepOnly,
      _keySpeedWarningInterval: _speedWarningInterval,
      _keyAutoStartGps: _autoStartGps,
      _keyKeepScreenOn: _keepScreenOn,
      _keyRecordGpx: _recordGpx,
      _keyRecordAlertLogs: _recordAlertLogs,
      _keyRoadSearchRadiusMeters: _roadSearchRadiusMeters,
      _keyCourtyardSearchRadiusMeters: _courtyardSearchRadiusMeters,
      _keyStreetChangeDistanceMeters: _streetChangeDistanceMeters,
      _keyStreetChangeConfirmations: _streetChangeConfirmations,
      _keySpeedRestorationConfirmations: _speedRestorationConfirmations,
      _keyOneWayExitConfirmations: _oneWayExitConfirmations,
      _keyFilterStaleGpsFixes: _filterStaleGpsFixes,
      _keyStaleGpsTimeoutSeconds: _staleGpsTimeoutSeconds,
      _keyPrioritizePedestrianAndCycleways: _prioritizePedestrianAndCycleways,
      _keyAudioDucking: _audioDucking,
      _keyLookaheadAlerts: _lookaheadAlerts,
      _keyLookaheadDistanceMeters: _lookaheadDistanceMeters,
      _keyTrafficCalmingAlerts: _trafficCalmingAlerts,
      _keySpeedCameraAlerts: _speedCameraAlerts,
      'exported_at': DateTime.now().toIso8601String(),
      'app_version': appVersion,
    };
  }

  /// Exports settings as a formatted JSON string
  String exportJsonString() {
    return const JsonEncoder.withIndent('  ').convert(exportSettings());
  }

  /// Imports settings from a JSON map and persists them to SharedPreferences
  Future<bool> importSettings(Map<String, dynamic> map) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      if (map.containsKey(_keyUseDynamicPhrases)) {
        _useDynamicPhrases = map[_keyUseDynamicPhrases] == true;
        await prefs.setBool(_keyUseDynamicPhrases, _useDynamicPhrases);
      }
      if (map.containsKey(_keyAnnounceStreetChanges)) {
        _announceStreetChanges = map[_keyAnnounceStreetChanges] == true;
        await prefs.setBool(_keyAnnounceStreetChanges, _announceStreetChanges);
      }
      if (map.containsKey(_keyIsMuted)) {
        _isMuted = map[_keyIsMuted] == true;
        await prefs.setBool(_keyIsMuted, _isMuted);
      }
      if (map.containsKey(_keySpeedTolerance)) {
        _speedTolerance = (map[_keySpeedTolerance] as num).toInt();
        await prefs.setInt(_keySpeedTolerance, _speedTolerance);
      }
      if (map.containsKey(_keySpeedToleranceMode)) {
        final modeStr = map[_keySpeedToleranceMode]?.toString();
        _speedToleranceMode = modeStr == 'percentage'
            ? SpeedToleranceMode.percentage
            : SpeedToleranceMode.fixed;
        await prefs.setString(_keySpeedToleranceMode, _speedToleranceMode.name);
      }
      if (map.containsKey(_keySpeedTolerancePercentage)) {
        _speedTolerancePercentage = (map[_keySpeedTolerancePercentage] as num).toDouble();
        await prefs.setDouble(_keySpeedTolerancePercentage, _speedTolerancePercentage);
      }
      if (map.containsKey(_keySpeedingBeepOnly)) {
        _speedingBeepOnly = map[_keySpeedingBeepOnly] == true;
        await prefs.setBool(_keySpeedingBeepOnly, _speedingBeepOnly);
      }
      if (map.containsKey(_keySpeedWarningInterval)) {
        _speedWarningInterval = (map[_keySpeedWarningInterval] as num).toInt();
        await prefs.setInt(_keySpeedWarningInterval, _speedWarningInterval);
      }
      if (map.containsKey(_keyAutoStartGps)) {
        _autoStartGps = map[_keyAutoStartGps] == true;
        await prefs.setBool(_keyAutoStartGps, _autoStartGps);
      }
      if (map.containsKey(_keyKeepScreenOn)) {
        _keepScreenOn = map[_keyKeepScreenOn] == true;
        await prefs.setBool(_keyKeepScreenOn, _keepScreenOn);
      }
      if (map.containsKey(_keyRecordGpx)) {
        _recordGpx = map[_keyRecordGpx] == true;
        await prefs.setBool(_keyRecordGpx, _recordGpx);
      }
      if (map.containsKey(_keyRecordAlertLogs)) {
        _recordAlertLogs = map[_keyRecordAlertLogs] == true;
        await prefs.setBool(_keyRecordAlertLogs, _recordAlertLogs);
      }
      if (map.containsKey(_keyRoadSearchRadiusMeters)) {
        _roadSearchRadiusMeters = (map[_keyRoadSearchRadiusMeters] as num).toDouble();
        await prefs.setDouble(_keyRoadSearchRadiusMeters, _roadSearchRadiusMeters);
      }
      if (map.containsKey(_keyCourtyardSearchRadiusMeters)) {
        _courtyardSearchRadiusMeters = (map[_keyCourtyardSearchRadiusMeters] as num).toDouble();
        await prefs.setDouble(_keyCourtyardSearchRadiusMeters, _courtyardSearchRadiusMeters);
      }
      if (map.containsKey(_keyStreetChangeDistanceMeters)) {
        _streetChangeDistanceMeters = (map[_keyStreetChangeDistanceMeters] as num).toDouble();
        await prefs.setDouble(_keyStreetChangeDistanceMeters, _streetChangeDistanceMeters);
      }
      if (map.containsKey(_keyStreetChangeConfirmations)) {
        _streetChangeConfirmations = (map[_keyStreetChangeConfirmations] as num).toInt();
        await prefs.setInt(_keyStreetChangeConfirmations, _streetChangeConfirmations);
      }
      if (map.containsKey(_keySpeedRestorationConfirmations)) {
        _speedRestorationConfirmations = (map[_keySpeedRestorationConfirmations] as num).toInt();
        await prefs.setInt(_keySpeedRestorationConfirmations, _speedRestorationConfirmations);
      }
      if (map.containsKey(_keyOneWayExitConfirmations)) {
        _oneWayExitConfirmations = (map[_keyOneWayExitConfirmations] as num).toInt();
        await prefs.setInt(_keyOneWayExitConfirmations, _oneWayExitConfirmations);
      }
      if (map.containsKey(_keyFilterStaleGpsFixes)) {
        _filterStaleGpsFixes = map[_keyFilterStaleGpsFixes] == true;
        await prefs.setBool(_keyFilterStaleGpsFixes, _filterStaleGpsFixes);
      }
      if (map.containsKey(_keyStaleGpsTimeoutSeconds)) {
        _staleGpsTimeoutSeconds = (map[_keyStaleGpsTimeoutSeconds] as num).toInt();
        await prefs.setInt(_keyStaleGpsTimeoutSeconds, _staleGpsTimeoutSeconds);
      }
      if (map.containsKey(_keyPrioritizePedestrianAndCycleways)) {
        _prioritizePedestrianAndCycleways = map[_keyPrioritizePedestrianAndCycleways] == true;
        await prefs.setBool(_keyPrioritizePedestrianAndCycleways, _prioritizePedestrianAndCycleways);
      }
      if (map.containsKey(_keyAudioDucking)) {
        _audioDucking = map[_keyAudioDucking] == true;
        await prefs.setBool(_keyAudioDucking, _audioDucking);
      }
      if (map.containsKey(_keyLookaheadAlerts)) {
        _lookaheadAlerts = map[_keyLookaheadAlerts] == true;
        await prefs.setBool(_keyLookaheadAlerts, _lookaheadAlerts);
      }
      if (map.containsKey(_keyLookaheadDistanceMeters)) {
        _lookaheadDistanceMeters = (map[_keyLookaheadDistanceMeters] as num).toDouble();
        await prefs.setDouble(_keyLookaheadDistanceMeters, _lookaheadDistanceMeters);
      }
      if (map.containsKey(_keyTrafficCalmingAlerts)) {
        _trafficCalmingAlerts = map[_keyTrafficCalmingAlerts] == true;
        await prefs.setBool(_keyTrafficCalmingAlerts, _trafficCalmingAlerts);
      }
      if (map.containsKey(_keySpeedCameraAlerts)) {
        _speedCameraAlerts = map[_keySpeedCameraAlerts] == true;
        await prefs.setBool(_keySpeedCameraAlerts, _speedCameraAlerts);
      }

      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Failed to import settings: $e');
      return false;
    }
  }

  /// Imports settings from a JSON string
  Future<bool> importJsonString(String jsonString) async {
    try {
      final decoded = jsonDecode(jsonString);
      if (decoded is Map<String, dynamic>) {
        return await importSettings(decoded);
      } else if (decoded is Map) {
        return await importSettings(Map<String, dynamic>.from(decoded));
      }
      return false;
    } catch (e) {
      debugPrint('Invalid JSON string for settings: $e');
      return false;
    }
  }
}
