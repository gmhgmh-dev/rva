import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/road_point.dart';
import '../models/voice_alert_event.dart';

class TripRecorderService {
  File? _gpxFile;
  File? _logFile;
  bool _isRecording = false;
  String _sessionIdentifier = '';

  Future<void> startRecording({bool recordGpx = true, bool recordLog = true}) async {
    if (_isRecording) return;
    if (!recordGpx && !recordLog) return;
    
    try {
      final dir = await getApplicationDocumentsDirectory();
      _sessionIdentifier = DateTime.now().toIso8601String().replaceAll(':', '-').replaceAll('.', '-');
      
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
        await _logFile!.writeAsString('Brauciena brīdinājumi - $_sessionIdentifier\n\n');
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

  Future<void> recordAlert(VoiceAlertEvent event) async {
    if (!_isRecording || _logFile == null) return;
    try {
      final timeStr = DateTime.now().toLocal().toString().split('.').first;
      final logEntry = '[$timeStr] ${event.type.name.toUpperCase()} -> ${event.spokenText} (Iela: ${event.streetName})\n';
      await _logFile!.writeAsString(logEntry, mode: FileMode.append);
    } catch (e) {
      debugPrint('Failed to record alert log: $e');
    }
  }

  Future<void> stopRecording() async {
    if (!_isRecording) return;
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
    } catch (e) {
      debugPrint('Failed to finalize GPX: $e');
    } finally {
      _isRecording = false;
      _gpxFile = null;
      _logFile = null;
    }
  }

  bool get isRecording => _isRecording;
  Future<List<File>> getRecordedFiles() async {
    final dir = await getApplicationDocumentsDirectory();
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
}
