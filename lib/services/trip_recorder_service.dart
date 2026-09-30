import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/road_point.dart';
import '../models/voice_alert_event.dart';
import 'settings_service.dart';

class TripRecorderService {
  final Directory? customStorageDir;
  File? _gpxFile;
  File? _logFile;
  File? _lastCompletedLogFile;
  bool _isRecording = false;
  String _sessionIdentifier = '';

  TripRecorderService({this.customStorageDir});

  File? get lastCompletedLogFile => _lastCompletedLogFile;

  Future<Directory> _getStorageDirectory() async =>
      customStorageDir ?? await getApplicationDocumentsDirectory();

  Future<void> startRecording({
    bool recordGpx = true,
    bool recordLog = true,
    String? sessionTag,
    String? sourceDescription,
  }) async {
    if (_isRecording) return;
    if (!recordGpx && !recordLog) return;
    
    try {
      final dir = await _getStorageDirectory();
      final nowStr = DateTime.now().toIso8601String().replaceAll(':', '-').replaceAll('.', '-');
      _sessionIdentifier = (sessionTag != null && sessionTag.isNotEmpty)
          ? '${sessionTag}_$nowStr'
          : nowStr;
      
      if (recordGpx) {
        _gpxFile = File('${dir.path}/trip_$_sessionIdentifier.gpx');
        await _gpxFile!.writeAsString(
          '<?xml version="1.0" encoding="UTF-8"?>\n'
          '<gpx version="1.1" creator="RoadsVoiceAssistant">\n'
          '  <trk>\n'
          '    <name>Brauciens $_sessionIdentifier</name>\n'
          '    <trkseg>\n'
        );
      }

      if (recordLog) {
        _logFile = File('${dir.path}/alerts_$_sessionIdentifier.log');
        final headerInfo = sourceDescription != null && sourceDescription.isNotEmpty
            ? ' ($sourceDescription)'
            : '';
        await _logFile!.writeAsString('Brauciena brīdinājumi$headerInfo - $_sessionIdentifier\n\n');
      }

      _isRecording = true;
    } catch (e) {
      debugPrint('Failed to start recording: $e');
    }
  }

  Future<void> recordPoint(RoadPoint point) async {
    if (!_isRecording || _gpxFile == null) return;
    try {
      final timeStr = point.timestamp.toUtc().toIso8601String();
      final speedMs = (point.vehicleSpeedKmh / 3.6).toStringAsFixed(2);
      final gpxPoint = '''      <trkpt lat="${point.latitude}" lon="${point.longitude}">
        <time>$timeStr</time>
        <speed>$speedMs</speed>
        <desc>Iela: ${point.streetName}, Atļauts: ${point.maxSpeedLimitKmh} km/h, Reāls: ${point.vehicleSpeedKmh.toStringAsFixed(1)} km/h</desc>
      </trkpt>
''';
      
      await _gpxFile!.writeAsString(gpxPoint, mode: FileMode.append);
    } catch (e) {
      debugPrint('Failed to record GPX point: $e');
    }
  }

  Future<void> _logWriteQueue = Future.value();

  Future<void> recordAlert(VoiceAlertEvent event, {DateTime? customTime}) async {
    if (!_isRecording || _logFile == null) return;
    _logWriteQueue = _logWriteQueue.then((_) async {
      try {
        final timeToUse = customTime ?? event.timestamp;
        final timeStr = timeToUse.toLocal().toString().split('.').first;
        final logEntry = '[$timeStr] ${event.type.name.toUpperCase()} -> ${event.spokenText} (Iela: ${event.streetName})\n';
        await _logFile!.writeAsString(logEntry, mode: FileMode.append);
      } catch (e) {
        debugPrint('Failed to record alert log: $e');
      }
    });
    await _logWriteQueue;
  }

  Future<File?> stopRecording() async {
    if (!_isRecording) return _lastCompletedLogFile;
    try {
      if (_gpxFile != null) {
        await _gpxFile!.writeAsString(
          '''    </trkseg>
  </trk>
</gpx>
''',
          mode: FileMode.append,
        );
      }
      if (_logFile != null) {
        await _logWriteQueue;
        _lastCompletedLogFile = _logFile;
      }
    } catch (e) {
      debugPrint('Failed to finalize GPX: $e');
    } finally {
      _isRecording = false;
      _gpxFile = null;
      _logFile = null;
    }
    return _lastCompletedLogFile;
  }

  bool get isRecording => _isRecording;
  Future<List<File>> getRecordedFiles() async {
    final dir = await _getStorageDirectory();
    final files = dir.listSync().whereType<File>().where((f) {
      final name = f.path.split(Platform.pathSeparator).last;
      return name.startsWith('trip_') || name.startsWith('alerts_');
    }).toList();
    return files;
  }

  Future<void> shareRecordedFiles() async {
    final files = await getRecordedFiles();
    if (files.isEmpty) return;
    
    final xFiles = files.map((f) => XFile(f.path)).toList();
    await Share.shareXFiles(xFiles, text: 'Mani braucienu dati no Roads Voice Assistant');
  }

  /// Exports current settings and the latest GPX/Log trip files as a single bundle for analysis
  Future<void> exportDiagnosticBundle(SettingsService settingsService) async {
    final dir = await _getStorageDirectory();
    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').replaceAll('.', '-');
    final settingsFile = File('${dir.path}/settings_$timestamp.json');
    await settingsFile.writeAsString(settingsService.exportJsonString());

    final recorded = await getRecordedFiles();
    // Sort descending by last modified
    recorded.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));

    File? latestGpx;
    File? latestLog;

    for (final f in recorded) {
      final name = f.path.split(Platform.pathSeparator).last;
      if (latestGpx == null && name.startsWith('trip_') && name.endsWith('.gpx')) {
        latestGpx = f;
      }
      if (latestLog == null && name.startsWith('alerts_') && name.endsWith('.log')) {
        latestLog = f;
      }
      if (latestGpx != null && latestLog != null) break;
    }

    final filesToShare = <XFile>[
      XFile(settingsFile.path),
    ];
    if (latestGpx != null) filesToShare.add(XFile(latestGpx.path));
    if (latestLog != null) filesToShare.add(XFile(latestLog.path));

    await Share.shareXFiles(
      filesToShare,
      text: 'RVA Diagnostikas pakotne (GPX, Brīdinājumu žurnāls un Iestatījumi)',
    );
  }

  /// Exports current settings JSON only and opens share sheet
  Future<void> exportSettingsFile(SettingsService settingsService) async {
    final dir = await _getStorageDirectory();
    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').replaceAll('.', '-');
    final settingsFile = File('${dir.path}/rva_settings_$timestamp.json');
    await settingsFile.writeAsString(settingsService.exportJsonString());

    await Share.shareXFiles(
      [XFile(settingsFile.path)],
      text: 'Roads Voice Assistant iestatījumu konfigurācija (.json)',
    );
  }

  Future<void> deleteAllRecordedFiles() async {
    final files = await getRecordedFiles();
    for (var file in files) {
      try {
        await file.delete();
      } catch (e) {
        debugPrint('Failed to delete file: $e');
      }
    }
    _gpxFile = null;
    _logFile = null;
  }

  /// Imports a GPX file from an external path or copied content into app documents.
  Future<File?> importGpxFile(File sourceFile) async {
    try {
      final dir = await _getStorageDirectory();
      String originalName = sourceFile.path.split(Platform.pathSeparator).last;
      if (!originalName.toLowerCase().endsWith('.gpx')) {
        originalName = '$originalName.gpx';
      }
      if (!originalName.startsWith('trip_')) {
        originalName = 'trip_$originalName';
      }
      final targetPath = '${dir.path}/$originalName';
      final importedFile = await sourceFile.copy(targetPath);
      return importedFile;
    } catch (e) {
      debugPrint('Failed to import GPX file: $e');
      return null;
    }
  }

  /// Saves raw GPX XML string into app documents directory.
  Future<File?> importGpxFromString(String gpxContent, {String? customName}) async {
    try {
      final dir = await _getStorageDirectory();
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').replaceAll('.', '-');
      final fileName = customName != null && customName.isNotEmpty
          ? (customName.startsWith('trip_') ? customName : 'trip_$customName')
          : 'trip_imported_$timestamp.gpx';
      final file = File('${dir.path}/$fileName');
      await file.writeAsString(gpxContent);
      return file;
    } catch (e) {
      debugPrint('Failed to save imported GPX content: $e');
      return null;
    }
  }
}

