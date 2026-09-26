import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

enum DownloadStatus {
  idle,
  downloading,
  completed,
  failed,
  cancelled,
}

/// Progress state for PMTiles map download.
class DownloadProgress {
  final DownloadStatus status;
  final double progress; // 0.0 to 1.0 (-1.0 if contentLength unknown)
  final int receivedBytes;
  final int totalBytes;
  final String? errorMessage;

  const DownloadProgress({
    this.status = DownloadStatus.idle,
    this.progress = 0.0,
    this.receivedBytes = 0,
    this.totalBytes = 0,
    this.errorMessage,
  });

  bool get isDownloading => status == DownloadStatus.downloading;
  bool get isCompleted => status == DownloadStatus.completed;
  bool get isFailed => status == DownloadStatus.failed;
  bool get isCancelled => status == DownloadStatus.cancelled;

  double get percentage => progress >= 0 ? (progress * 100).clamp(0.0, 100.0) : 0.0;

  String get formattedReceived => MapFileInfo.formatBytes(receivedBytes);
  String get formattedTotal => totalBytes > 0 ? MapFileInfo.formatBytes(totalBytes) : 'Nezināms';
}

/// Metadata about the local PMTiles map file.
class MapFileInfo {
  final String path;
  final int byteSize;
  final DateTime lastModified;

  const MapFileInfo({
    required this.path,
    required this.byteSize,
    required this.lastModified,
  });

  static String formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  String get formattedSize => formatBytes(byteSize);

  String get formattedDate {
    final y = lastModified.year.toString().padLeft(4, '0');
    final m = lastModified.month.toString().padLeft(2, '0');
    final d = lastModified.day.toString().padLeft(2, '0');
    final h = lastModified.hour.toString().padLeft(2, '0');
    final min = lastModified.minute.toString().padLeft(2, '0');
    return '$d.$m.$y $h:$min';
  }
}

/// Service responsible for downloading and managing the local latvia.pmtiles file.
class MapDownloaderService extends ChangeNotifier {
  static const String mapFileName = 'latvia.pmtiles';
  static const String defaultUrl = 'https://github.com/gmhgmh-dev/rva/releases/latest/download/latvia.pmtiles';

  final Future<Directory> Function()? _customDocDirResolver;
  final http.Client? _customHttpClient;

  DownloadProgress _progress = const DownloadProgress();
  bool _cancelRequested = false;

  MapDownloaderService({
    Future<Directory> Function()? docDirResolver,
    http.Client? httpClient,
  })  : _customDocDirResolver = docDirResolver,
        _customHttpClient = httpClient;

  DownloadProgress get progress => _progress;

  /// Returns the destination directory where offline maps are stored.
  Future<Directory> getStorageDirectory() async {
    if (_customDocDirResolver != null) {
      return await _customDocDirResolver();
    }
    return await getApplicationDocumentsDirectory();
  }

  /// Returns the target File for latvia.pmtiles.
  Future<File> getLocalMapFile() async {
    final dir = await getStorageDirectory();
    return File('${dir.path}/$mapFileName');
  }

  /// Checks whether latvia.pmtiles already exists and is non-empty.
  Future<bool> isMapDownloaded() async {
    final file = await getLocalMapFile();
    if (file.existsSync()) {
      return file.lengthSync() > 0;
    }
    return false;
  }

  /// Retrieves file size and last modified date of the local latvia.pmtiles file.
  Future<MapFileInfo?> getMapFileInfo() async {
    final file = await getLocalMapFile();
    if (file.existsSync()) {
      final stat = file.statSync();
      if (stat.size > 0) {
        return MapFileInfo(
          path: file.path,
          byteSize: stat.size,
          lastModified: stat.modified,
        );
      }
    }
    return null;
  }

  /// Downloads the Latvia PMTiles file from [url] to the application documents directory.
  /// Uses a temporary file and atomic rename to prevent partial/corrupt files.
  Future<File> downloadMap({
    String? url,
    void Function(DownloadProgress progress)? onProgress,
  }) async {
    final downloadUrl = (url != null && url.trim().isNotEmpty) ? url.trim() : defaultUrl;
    final targetFile = await getLocalMapFile();
    final tempFile = File('${targetFile.path}.tmp');

    _cancelRequested = false;
    _updateProgress(const DownloadProgress(
      status: DownloadStatus.downloading,
      progress: 0.0,
      receivedBytes: 0,
      totalBytes: 0,
    ), onProgress);

    final client = _customHttpClient ?? http.Client();
    final shouldCloseClient = _customHttpClient == null;

    IOSink? sink;
    try {
      final request = http.Request('GET', Uri.parse(downloadUrl));
      final response = await client.send(request);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException('Server returned HTTP ${response.statusCode}: ${response.reasonPhrase}');
      }

      final totalBytes = response.contentLength ?? -1;
      var receivedBytes = 0;

      // Ensure directory exists
      final parentDir = tempFile.parent;
      if (!await parentDir.exists()) {
        await parentDir.create(recursive: true);
      }

      if (await tempFile.exists()) {
        await tempFile.delete();
      }

      final fileSink = tempFile.openWrite();
      sink = fileSink;

      await for (final chunk in response.stream) {
        if (_cancelRequested) {
          await fileSink.close();
          sink = null;
          if (await tempFile.exists()) {
            await tempFile.delete();
          }
          _updateProgress(DownloadProgress(
            status: DownloadStatus.cancelled,
            progress: 0.0,
            receivedBytes: receivedBytes,
            totalBytes: totalBytes,
            errorMessage: 'Lejupielāde atcelta.',
          ), onProgress);
          throw Exception('Lejupielāde tika atcelta.');
        }

        fileSink.add(chunk);
        receivedBytes += chunk.length;

        final double prog = totalBytes > 0
            ? (receivedBytes / totalBytes).clamp(0.0, 1.0)
            : -1.0;

        _updateProgress(DownloadProgress(
          status: DownloadStatus.downloading,
          progress: prog,
          receivedBytes: receivedBytes,
          totalBytes: totalBytes,
        ), onProgress);
      }

      await fileSink.flush();
      await fileSink.close();
      sink = null;

      // Atomic rename
      if (await targetFile.exists()) {
        await targetFile.delete();
      }
      await tempFile.rename(targetFile.path);

      _updateProgress(DownloadProgress(
        status: DownloadStatus.completed,
        progress: 1.0,
        receivedBytes: receivedBytes,
        totalBytes: receivedBytes,
      ), onProgress);

      return targetFile;
    } catch (e) {
      if (sink != null) {
        await sink.close();
      }
      if (await tempFile.exists()) {
        try {
          await tempFile.delete();
        } catch (_) {}
      }

      if (!_cancelRequested) {
        _updateProgress(DownloadProgress(
          status: DownloadStatus.failed,
          progress: 0.0,
          errorMessage: e.toString(),
        ), onProgress);
      }
      rethrow;
    } finally {
      if (shouldCloseClient) {
        client.close();
      }
    }
  }

  /// Requests cancellation of the ongoing download.
  void cancelDownload() {
    _cancelRequested = true;
  }

  /// Deletes the local latvia.pmtiles file.
  Future<void> deleteMapFile() async {
    final file = await getLocalMapFile();
    if (await file.exists()) {
      await file.delete();
    }
    _progress = const DownloadProgress();
    notifyListeners();
  }

  void _updateProgress(DownloadProgress progress, [void Function(DownloadProgress)? onProgress]) {
    _progress = progress;
    onProgress?.call(progress);
    notifyListeners();
  }
}
