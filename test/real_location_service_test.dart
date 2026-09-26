import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rva/models/road_attributes.dart';
import 'package:rva/services/pmtiles_service.dart';
import 'package:rva/services/real_location_service.dart';

class FakePMTilesServiceLoaded extends PMTilesService {
  @override
  bool get isLoaded => true;

  @override
  Future<RoadAttributes?> getRoadAttributes(double lat, double lon, {int? targetZoom, double maxRadiusMeters = 60.0}) async {
    return const RoadAttributes(
      maxspeed: 30,
      isOneWay: true,
      name: 'Offline PMTiles Street',
      roadClass: 'residential',
    );
  }
}

Position _createPosition(double lat, double lon, {double speed = 10.0}) {
  return Position(
    latitude: lat,
    longitude: lon,
    timestamp: DateTime.now(),
    accuracy: 5.0,
    altitude: 10.0,
    altitudeAccuracy: 1.0,
    heading: 0.0,
    headingAccuracy: 1.0,
    speed: speed,
    speedAccuracy: 1.0,
  );
}

void main() {
  group('RealLocationService Overpass & Offline Fallback Tests', () {
    test('Prioritizes PMTiles offline map when loaded and available', () async {
      int httpCallsCount = 0;
      final mockClient = MockClient((request) async {
        httpCallsCount++;
        return http.Response('{"elements": []}', 200);
      });

      final service = RealLocationService(
        pmTilesService: FakePMTilesServiceLoaded(),
        httpClient: mockClient,
      );

      final point = await service.resolveRoadMetadata(_createPosition(57.3955, 21.5600));

      expect(point.streetName, equals('Offline PMTiles Street'));
      expect(point.maxSpeedLimitKmh, equals(30));
      expect(point.isOneWay, isTrue);
      expect(httpCallsCount, equals(0)); // Did not hit Overpass API
    });

    test('Queries Overpass API online when PMTiles is not loaded', () async {
      int httpCallsCount = 0;
      final mockClient = MockClient((request) async {
        httpCallsCount++;
        expect(request.url.queryParameters['data'], contains('highway'));
        return http.Response.bytes(
          utf8.encode(json.encode({
            'elements': [
              {
                'type': 'way',
                'tags': {
                  'highway': 'secondary',
                  'name': 'Kuldīgas iela',
                  'maxspeed': '50',
                  'oneway': 'no',
                }
              }
            ]
          })),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final service = RealLocationService(
        pmTilesService: null,
        httpClient: mockClient,
      );

      final point = await service.resolveRoadMetadata(_createPosition(57.3955, 21.5600));

      expect(point.streetName, equals('Kuldīgas iela'));
      expect(point.maxSpeedLimitKmh, equals(50));
      expect(point.isOneWay, isFalse);
      expect(httpCallsCount, equals(1));
    });

    test('Parses Latvian-specific OSM tags correctly (LV:rural, LV:living_street, name:lv)', () async {
      final mockClient = MockClient((request) async {
        return http.Response.bytes(
          utf8.encode(json.encode({
            'elements': [
              {
                'type': 'way',
                'tags': {
                  'highway': 'primary',
                  'name:lv': 'Ventspils - Rīga šoseja',
                  'maxspeed': 'LV:rural',
                  'oneway': 'yes',
                }
              }
            ]
          })),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final service = RealLocationService(
        pmTilesService: null,
        httpClient: mockClient,
      );

      final point = await service.resolveRoadMetadata(_createPosition(57.3500, 21.6500));

      expect(point.streetName, equals('Ventspils - Rīga šoseja'));
      expect(point.maxSpeedLimitKmh, equals(90));
      expect(point.isOneWay, isTrue);
    });

    test('Reuses spatial cache for locations within 30m without repeated HTTP requests', () async {
      int httpCallsCount = 0;
      final mockClient = MockClient((request) async {
        httpCallsCount++;
        return http.Response.bytes(
          utf8.encode(json.encode({
            'elements': [
              {
                'type': 'way',
                'tags': {
                  'highway': 'residential',
                  'name': 'Lielais prospekts',
                  'maxspeed': '50',
                  'oneway': 'no',
                }
              }
            ]
          })),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final service = RealLocationService(
        pmTilesService: null,
        httpClient: mockClient,
      );

      // Initial query at (57.3950, 21.5600)
      final point1 = await service.resolveRoadMetadata(_createPosition(57.3950, 21.5600));
      expect(point1.streetName, equals('Lielais prospekts'));
      expect(httpCallsCount, equals(1));

      // Second query moved ~11 meters (57.3951, 21.5600)
      final point2 = await service.resolveRoadMetadata(_createPosition(57.3951, 21.5600));
      expect(point2.streetName, equals('Lielais prospekts'));
      expect(httpCallsCount, equals(1)); // Cache hit! Zero additional HTTP calls
    });

    test('Gracefully falls back to heuristic if Overpass API returns 500 or times out', () async {
      final mockClient = MockClient((request) async {
        return http.Response('Server error', 500);
      });

      final service = RealLocationService(
        pmTilesService: null,
        httpClient: mockClient,
      );

      // In Ventspils old town coordinates
      final point = await service.resolveRoadMetadata(_createPosition(57.3955, 21.5570));

      expect(point.streetName, contains('Sofijas iela'));
      expect(point.maxSpeedLimitKmh, equals(30));
      expect(point.isOneWay, isTrue);
      expect(point.dataSource, equals('Pilsētas ceļš'));

      // Outside old town fallback does not say Lielais prospekts
      final pointGeneric = await service.resolveRoadMetadata(_createPosition(57.3800, 21.5400));
      expect(pointGeneric.streetName, equals('Pilsētas ceļš'));
      expect(pointGeneric.streetName, isNot(contains('Lielais prospekts')));
    });

    test('Resolves Sarkanmuižas dambis in Ventspils with Overpass API tiešsaiste dataSource', () async {
      final mockClient = MockClient((request) async {
        return http.Response.bytes(
          utf8.encode(json.encode({
            'elements': [
              {
                'type': 'way',
                'tags': {
                  'highway': 'secondary',
                  'name': 'Sarkanmuižas dambis',
                  'maxspeed': '50',
                  'oneway': 'no',
                }
              }
            ]
          })),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final service = RealLocationService(
        pmTilesService: null,
        httpClient: mockClient,
      );

      // User location on Sarkanmuižas dambis
      final point = await service.resolveRoadMetadata(_createPosition(57.3995, 21.5712));

      expect(point.streetName, equals('Sarkanmuižas dambis'));
      expect(point.maxSpeedLimitKmh, equals(50));
      expect(point.dataSource, equals('Overpass API tiešsaiste'));
    });

    test('Prioritizes Sarkanmuižas dambis over closer unnamed courtyard driveways (service roads)', () async {
      final mockClient = MockClient((request) async {
        return http.Response.bytes(
          utf8.encode(json.encode({
            'elements': [
              // Unnamed courtyard driveway first in list
              {
                'type': 'way',
                'tags': {
                  'highway': 'service',
                }
              },
              // Another unnamed driveway
              {
                'type': 'way',
                'tags': {
                  'highway': 'service',
                  'maxspeed': '20',
                }
              },
              // The main street nearby
              {
                'type': 'way',
                'tags': {
                  'highway': 'tertiary',
                  'name': 'Sarkanmuižas dambis',
                  'maxspeed': '50',
                  'oneway': 'no',
                }
              }
            ]
          })),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final service = RealLocationService(
        pmTilesService: null,
        httpClient: mockClient,
      );

      final point = await service.resolveRoadMetadata(_createPosition(57.3935, 21.5710));

      // Successfully picked named street despite unnamed driveways
      expect(point.streetName, equals('Sarkanmuižas dambis'));
      expect(point.maxSpeedLimitKmh, equals(50));
      expect(point.streetName, isNot(equals('Iela')));
    });

    test('Unnamed courtyard driveway falls back to Pagalma brauktuve instead of Iela', () async {
      final mockClient = MockClient((request) async {
        return http.Response.bytes(
          utf8.encode(json.encode({
            'elements': [
              {
                'type': 'way',
                'tags': {
                  'highway': 'service',
                }
              }
            ]
          })),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final service = RealLocationService(
        pmTilesService: null,
        httpClient: mockClient,
      );

      final point = await service.resolveRoadMetadata(_createPosition(57.3935, 21.5710));

      expect(point.streetName, equals('Pagalma brauktuve'));
      expect(point.streetName, isNot(equals('Iela')));
    });
  });
}
