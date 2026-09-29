import 'package:flutter_test/flutter_test.dart';
import 'package:rva/models/road_attributes.dart';
import 'package:rva/services/pmtiles_service.dart';
import 'package:vector_tile/vector_tile.dart';

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

    test('parseIntValue parses Latvian and living street conventions correctly', () {
      expect(PMTilesService.parseIntValue('LV:living_street'), equals(20));
      expect(PMTilesService.parseIntValue('living_street'), equals(20));
      expect(PMTilesService.parseIntValue('20'), equals(20));
      expect(PMTilesService.parseIntValue('LV:zone30'), equals(30));
      expect(PMTilesService.parseIntValue('zone30'), equals(30));
      expect(PMTilesService.parseIntValue('LV:urban'), equals(50));
      expect(PMTilesService.parseIntValue('LV:rural'), equals(90));
      expect(PMTilesService.parseIntValue(50), equals(50));
    });

    test('extractRoadAttributes sets maxspeed=20 for highway=living_street even if maxspeed tag is omitted', () {
      final service = PMTilesService();
      final props = <String, VectorTileValue>{
        'highway': VectorTileValue(stringValue: 'living_street'),
      };

      final road = service.extractRoadAttributesForTesting(props, 5.0);
      expect(road.maxspeed, equals(20));
      expect(road.name, equals('Dzīvojamā zona'));
      expect(road.roadClass, equals('living_street'));
    });

    test('extractRoadAttributes extracts zone:maxspeed=20 and custom street name', () {
      final service = PMTilesService();
      final props = <String, VectorTileValue>{
        'highway': VectorTileValue(stringValue: 'residential'),
        'zone:maxspeed': VectorTileValue(stringValue: '20'),
        'name': VectorTileValue(stringValue: 'Ziedu iela'),
      };

      final road = service.extractRoadAttributesForTesting(props, 3.2);
      expect(road.maxspeed, equals(20));
      expect(road.name, equals('Ziedu iela'));
      expect(road.roadClass, equals('residential'));
      expect(road.isZone, isTrue);
    });

    test('extractRoadAttributes sets isZone=true when zone:maxspeed=30 is present', () {
      final service = PMTilesService();
      final props = <String, VectorTileValue>{
        'highway': VectorTileValue(stringValue: 'residential'),
        'zone:maxspeed': VectorTileValue(stringValue: '30'),
        'name': VectorTileValue(stringValue: 'Katoļu iela'),
      };

      final road = service.extractRoadAttributesForTesting(props, 2.0);
      expect(road.maxspeed, equals(30));
      expect(road.isZone, isTrue);
      expect(road.name, equals('Katoļu iela'));
    });

    test('extractRoadAttributes classifies cycleway correctly', () {
      final service = PMTilesService();
      final props = <String, VectorTileValue>{
        'highway': VectorTileValue(stringValue: 'cycleway'),
        'name': VectorTileValue(stringValue: 'Lielais prospekts veloceliņš'),
      };

      final road = service.extractRoadAttributesForTesting(props, 2.0);
      expect(road.isCycleway, isTrue);
      expect(road.isPedestrianOrBicycle, isTrue);
      expect(road.name, equals('Lielais prospekts veloceliņš'));
      expect(road.maxspeed, equals(20));
    });

    test('extractRoadAttributes classifies footway correctly', () {
      final service = PMTilesService();
      final props = <String, VectorTileValue>{
        'highway': VectorTileValue(stringValue: 'footway'),
      };

      final road = service.extractRoadAttributesForTesting(props, 2.0);
      expect(road.isFootway, isTrue);
      expect(road.isPedestrianOrBicycle, isTrue);
      expect(road.name, equals('Gājēju ceļš'));
    });

    test('calculateSegmentBearing calculates correct navigation bearings', () {
      // In tile coordinates: dx positive East, dy positive South
      // Segment going North: dx = 0, dy = -10 -> 0 degrees
      expect(PMTilesService.calculateSegmentBearing(0.0, -10.0), closeTo(0.0, 0.01));

      // Segment going East: dx = 10, dy = 0 -> 90 degrees
      expect(PMTilesService.calculateSegmentBearing(10.0, 0.0), closeTo(90.0, 0.01));

      // Segment going South: dx = 0, dy = 10 -> 180 degrees
      expect(PMTilesService.calculateSegmentBearing(0.0, 10.0), closeTo(180.0, 0.01));

      // Segment going West (like Jūras iela): dx = -10, dy = 0 -> 270 degrees
      expect(PMTilesService.calculateSegmentBearing(-10.0, 0.0), closeTo(270.0, 0.01));
    });

    test('angleDifference computes undirected difference [0, 90] degrees', () {
      // Vehicle driving West (272 deg) along Jūras iela (270 deg) -> diff = 2 deg (parallel)
      expect(PMTilesService.angleDifference(272.0, 270.0), closeTo(2.0, 0.01));

      // Vehicle driving West (272 deg) crossing Aleksandra iela (180 deg) -> diff = 88 deg (perpendicular)
      expect(PMTilesService.angleDifference(272.0, 180.0), closeTo(88.0, 0.01));

      // Opposite direction on same road: vehicle 270 deg, road 90 deg -> diff = 0 deg (same line axis)
      expect(PMTilesService.angleDifference(270.0, 90.0), closeTo(0.0, 0.01));
    });

    test('calculateLookaheadCoordinate projects coordinate forward in heading direction', () {
      const lat = 57.3950;
      const lon = 21.5600;

      // Project 100 meters North (heading = 0)
      final northProj = PMTilesService.calculateLookaheadCoordinate(lat, lon, 0.0, 100.0);
      expect(northProj.lat, greaterThan(lat));
      expect(northProj.lon, closeTo(lon, 0.00001));

      // Project 100 meters East (heading = 90)
      final eastProj = PMTilesService.calculateLookaheadCoordinate(lat, lon, 90.0, 100.0);
      expect(eastProj.lat, closeTo(lat, 0.00001));
      expect(eastProj.lon, greaterThan(lon));
    });

    test('calculateDynamicLookaheadDistance scales with speed and clamps between 35m and 120m', () {
      // < 15 km/h -> 0.0 (inactive)
      expect(PMTilesService.calculateDynamicLookaheadDistance(0.0), equals(0.0));
      expect(PMTilesService.calculateDynamicLookaheadDistance(10.0), equals(0.0));

      // 20 km/h = 5.56 m/s * 4.5s = 25m -> clamped to 35m minimum
      expect(PMTilesService.calculateDynamicLookaheadDistance(20.0), equals(35.0));

      // 50 km/h = 13.89 m/s * 4.5s = ~62.5m
      expect(PMTilesService.calculateDynamicLookaheadDistance(50.0), closeTo(62.5, 1.0));

      // 90 km/h = 25 m/s * 4.5s = ~112.5m
      expect(PMTilesService.calculateDynamicLookaheadDistance(90.0), closeTo(112.5, 1.0));

      // 150 km/h -> clamped to 120m maximum
      expect(PMTilesService.calculateDynamicLookaheadDistance(150.0), equals(120.0));
    });

    test('extractRoadAttributes extracts traffic_calming and speed_camera tags', () {
      final service = PMTilesService();
      final props = <String, VectorTileValue>{
        'highway': VectorTileValue(stringValue: 'residential'),
        'traffic_calming': VectorTileValue(stringValue: 'bump'),
        'name': VectorTileValue(stringValue: 'Kuldīgas iela'),
      };

      final road = service.extractRoadAttributesForTesting(props, 2.0);
      expect(road.hasTrafficCalming, isTrue);
      expect(road.trafficCalmingType, equals('bump'));

      final cameraProps = <String, VectorTileValue>{
        'highway': VectorTileValue(stringValue: 'speed_camera'),
        'maxspeed': VectorTileValue(stringValue: '50'),
      };
      final cameraRoad = service.extractRoadAttributesForTesting(cameraProps, 2.0);
      expect(cameraRoad.hasSpeedCamera, isTrue);
      expect(cameraRoad.speedCameraLimit, equals(50));
    });
  });
}
