import 'package:flutter_test/flutter_test.dart';
import 'package:rva/models/road_attributes.dart';
import 'package:rva/services/pmtiles_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PMTilesService', () {
    test('initial state is not loaded and returns null for queries', () async {
      final service = PMTilesService();
      expect(service.isLoaded, isFalse);
      expect(service.loadedFile, isNull);

      final result = await service.getRoadAttributes(57.3950, 21.5600);
      expect(result, isNull);
    });

    test('RoadAttributes holds road information correctly', () {
      const road = RoadAttributes(
        maxspeed: 30,
        isOneWay: true,
        name: 'Sofijas iela',
        distanceMeters: 4.5,
        roadClass: 'residential',
      );

      expect(road.maxspeed, equals(30));
      expect(road.isOneWay, isTrue);
      expect(road.name, equals('Sofijas iela'));
      expect(road.distanceMeters, equals(4.5));
      expect(road.roadClass, equals('residential'));
      expect(road.toString(), contains('Sofijas iela'));
    });
  });
}
