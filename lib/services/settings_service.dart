import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsService extends ChangeNotifier {
  static const _keyUseDynamicPhrases = 'use_dynamic_phrases';
  static const _keyAnnounceStreetChanges = 'announce_street_changes';
  static const _keyIsMuted = 'is_muted';
  static const _keySpeedTolerance = 'speed_tolerance';
  static const _keySpeedingBeepOnly = 'speeding_beep_only';
  static const _keySpeedWarningInterval = 'speed_warning_interval';
  static const _keyAutoStartGps = 'auto_start_gps';
  static const _keyKeepScreenOn = 'keep_screen_on';
  static const _keyRecordGpx = 'record_gpx';
  static const _keyRecordAlertLogs = 'record_alert_logs';

  bool _useDynamicPhrases = true;
  bool _announceStreetChanges = true;
  bool _isMuted = false;
  int _speedTolerance = 0; // +0 km/h default
  bool _speedingBeepOnly = false;
  int _speedWarningInterval = 10; // 10s default
  bool _autoStartGps = false;
  bool _keepScreenOn = false;
  bool _recordGpx = false;
  bool _recordAlertLogs = false;

  bool get useDynamicPhrases => _useDynamicPhrases;
  bool get announceStreetChanges => _announceStreetChanges;
  bool get isMuted => _isMuted;
  int get speedTolerance => _speedTolerance;
  bool get speedingBeepOnly => _speedingBeepOnly;
  int get speedWarningInterval => _speedWarningInterval;
  bool get autoStartGps => _autoStartGps;
  bool get keepScreenOn => _keepScreenOn;
  bool get recordGpx => _recordGpx;
  bool get recordAlertLogs => _recordAlertLogs;

  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _useDynamicPhrases = prefs.getBool(_keyUseDynamicPhrases) ?? true;
    _announceStreetChanges = prefs.getBool(_keyAnnounceStreetChanges) ?? true;
    _isMuted = prefs.getBool(_keyIsMuted) ?? false;
    _speedTolerance = prefs.getInt(_keySpeedTolerance) ?? 0;
    _speedingBeepOnly = prefs.getBool(_keySpeedingBeepOnly) ?? false;
    _speedWarningInterval = prefs.getInt(_keySpeedWarningInterval) ?? 10;
    _autoStartGps = prefs.getBool(_keyAutoStartGps) ?? false;
    _keepScreenOn = prefs.getBool(_keyKeepScreenOn) ?? false;
    _recordGpx = prefs.getBool(_keyRecordGpx) ?? false;
    _recordAlertLogs = prefs.getBool(_keyRecordAlertLogs) ?? false;
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
}
