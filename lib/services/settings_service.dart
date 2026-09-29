import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum SpeedToleranceMode {
  fixed,
  percentage,
}

class SettingsService extends ChangeNotifier {
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
  static const _keyStreetChangeConfirmations = 'street_change_confirmations';
  static const _keySpeedRestorationConfirmations = 'speed_restoration_confirmations';
  static const _keyOneWayExitConfirmations = 'one_way_exit_confirmations';
  static const _keyFilterStaleGpsFixes = 'filter_stale_gps_fixes';
  static const _keyStaleGpsTimeoutSeconds = 'stale_gps_timeout_seconds';
  static const _keyPrioritizePedestrianAndCycleways = 'prioritize_pedestrian_cycleways';

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
  int _streetChangeConfirmations = 4; // Recommended default: 4 points (~4s)
  int _speedRestorationConfirmations = 4; // Recommended default: 4 points (~4s)
  int _oneWayExitConfirmations = 3; // Recommended default: 3 points (~3s)
  bool _filterStaleGpsFixes = true; // Recommended default: true
  int _staleGpsTimeoutSeconds = 5; // Recommended default: 5s
  bool _prioritizePedestrianAndCycleways = false; // Recommended default: false (car mode)

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
  int get streetChangeConfirmations => _streetChangeConfirmations;
  int get speedRestorationConfirmations => _speedRestorationConfirmations;
  int get oneWayExitConfirmations => _oneWayExitConfirmations;
  bool get filterStaleGpsFixes => _filterStaleGpsFixes;
  int get staleGpsTimeoutSeconds => _staleGpsTimeoutSeconds;
  bool get prioritizePedestrianAndCycleways => _prioritizePedestrianAndCycleways;

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
    _streetChangeConfirmations = (prefs.getInt(_keyStreetChangeConfirmations) ?? 4).clamp(1, 10);
    _speedRestorationConfirmations = (prefs.getInt(_keySpeedRestorationConfirmations) ?? 4).clamp(1, 10);
    _oneWayExitConfirmations = (prefs.getInt(_keyOneWayExitConfirmations) ?? 3).clamp(1, 10);
    _filterStaleGpsFixes = prefs.getBool(_keyFilterStaleGpsFixes) ?? true;
    _staleGpsTimeoutSeconds = (prefs.getInt(_keyStaleGpsTimeoutSeconds) ?? 5).clamp(1, 30);
    _prioritizePedestrianAndCycleways = prefs.getBool(_keyPrioritizePedestrianAndCycleways) ?? false;
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
}
