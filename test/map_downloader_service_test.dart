import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rva/services/map_downloader_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('map_downloader_test_');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('MapDownloaderService', () {
    test('initial state has no file and idle progress', () async {
      final service = MapDownloaderService(
        docDirResolver: () async => tempDir,
      );

      expect(await service.isMapDownloaded(), isFalse);
      expect(await service.getMapFileInfo(), isNull);
      expect(service.progress.status, equals(DownloadStatus.idle));
    });

    test('downloads file successfully with progress notifications', () async {
      final sampleData = utf8.encode('MOCK PMTILES DATA CONTENT FOR LATVIA');

      final mockClient = MockClient((request) async {
        return http.Response.bytes(
          sampleData,
          200,
          headers: {'content-length': sampleData.length.toString()},
        );
      });

      final service = MapDownloaderService(
        docDirResolver: () async => tempDir,
        httpClient: mockClient,
      );

      final progressList = <DownloadProgress>[];
      final file = await service.downloadMap(
        onProgress: (p) => progressList.add(p),
      );

      expect(await file.exists(), isTrue);
      expect(await file.length(), equals(sampleData.length));
      expect(await service.isMapDownloaded(), isTrue);

      final fileInfo = await service.getMapFileInfo();
      expect(fileInfo, isNotNull);
      expect(fileInfo!.byteSize, equals(sampleData.length));
      expect(fileInfo.formattedSize, contains('B'));
      expect(fileInfo.formattedDate, isNotEmpty);

      expect(progressList.any((p) => p.isDownloading), isTrue);
      expect(service.progress.isCompleted, isTrue);
      expect(service.progress.percentage, equals(100.0));
    });

    test('deletes map file and resets state', () async {
      final targetFile = File('${tempDir.path}/${MapDownloaderService.mapFileName}');
      await targetFile.writeAsString('Dummy data');

      final service = MapDownloaderService(
        docDirResolver: () async => tempDir,
      );

      expect(await service.isMapDownloaded(), isTrue);
      await service.deleteMapFile();
      expect(await service.isMapDownloaded(), isFalse);
      expect(await targetFile.exists(), isFalse);
    });

    test('handles HTTP server error gracefully', () async {
      final mockClient = MockClient((request) async {
        return http.Response('Server Error', 500);
      });

      final service = MapDownloaderService(
        docDirResolver: () async => tempDir,
        httpClient: mockClient,
      );

      expect(
        () => service.downloadMap(),
        throwsA(isA<HttpException>()),
      );
    });
  });
}
