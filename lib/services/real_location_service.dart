import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import '../models/road_attributes.dart';
import '../models/road_point.dart';
import 'pmtiles_service.dart';

/// Service providing real-time GPS location updates from the device sensors.
/// Prioritizes local offline PMTiles vector maps, with automatic, real-time,
/// non-blocking Overpass API online queries and spatial caching when PMTiles
/// is not available.
class RealLocationService {
  final PMTilesService? pmTilesService;
  final http.Client _httpClient;

  final StreamController<RoadPoint> _pointController = StreamController<RoadPoint>.broadcast();
  StreamSubscription<Position>? _positionSubscription;
  bool _isTracking = false;

  // Spatial and temporal cache for Overpass online queries
  RoadAttributes? _lastKnownAttributes;
  double? _lastQueriedLat;
  double? _lastQueriedLon;
  DateTime? _lastQueryTime;
  bool _isOverpassQueryInFlight = false;

  /// Public Overpass API mirrors for high availability and failover
  static const List<String> overpassEndpoints = [
    'https://overpass-api.de/api/interpreter',
    'https://lz4.overpass-api.de/api/interpreter',
    'https://overpass.kumi.systems/api/interpreter',
  ];

  RealLocationService({
    this.pmTilesService,
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client();

  Stream<RoadPoint> get locationStream => _pointController.stream;
  bool get isTracking => _isTracking;
  RoadAttributes? get cachedAttributes => _lastKnownAttributes;

  /// Requests permissions and starts listening to GPS coordinates.
  Future<bool> startTracking() async {
    final hasPermission = await _checkAndRequestPermissions();
    if (!hasPermission) {
      return false;
    }

    await stopTracking();
    _isTracking = true;

    // Reset previous cached attributes so stale demo/old route data is not reused
    _lastKnownAttributes = null;
    _lastQueriedLat = null;
    _lastQueriedLon = null;
    _lastQueryTime = null;

    // Immediately query last known position or current position so the user
    // gets immediate feedback even if stationary in their vehicle.
    Geolocator.getLastKnownPosition().then((lastPos) {
      if (lastPos != null && _isTracking && _lastKnownAttributes == null) {
        _handlePositionUpdate(lastPos);
      }
    }).catchError((dynamic e) {
      debugPrint('Geolocator.getLastKnownPosition error: $e');
    });

    Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 4),
      ),
    ).then((currPos) {
      if (_isTracking) {
        _handlePositionUpdate(currPos);
      }
    }).catchError((dynamic e) {
      debugPrint('Geolocator.getCurrentPosition initial error: $e');
    });

    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 3,
    );

    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen((Position position) async {
      await _handlePositionUpdate(position);
    }, onError: (dynamic error) {
      debugPrint('Real GPS stream error: $error');
    });

    return true;
  }

  /// Stops tracking real GPS location.
  Future<void> stopTracking() async {
    await _positionSubscription?.cancel();
    _positionSubscription = null;
    _isTracking = false;
  }

  /// Handles incoming GPS position updates.
  /// Delivers updates with 0-latency to avoid UI freezing, while concurrently
  /// querying Overpass API in the background if offline map is absent.
  Future<void> _handlePositionUpdate(Position position) async {
    final speedKmh = position.speed > 0 ? (position.speed * 3.6) : 0.0;
    final lat = position.latitude;
    final lon = position.longitude;

    // 1. Try local offline PMTiles vector map first (instant, 0ms, fully offline)
    if (pmTilesService != null && pmTilesService!.isLoaded) {
      try {
        final roadAttrs = await pmTilesService!.getRoadAttributes(lat, lon);
        if (roadAttrs != null) {
          _updateCache(lat, lon, roadAttrs);
          _pointController.add(_createRoadPoint(
            lat: lat,
            lon: lon,
            speedKmh: speedKmh,
            attributes: roadAttrs,
            dataSource: 'PMTiles bezsaistes karte',
            timestamp: position.timestamp,
          ));
          return;
        }
      } catch (e) {
        debugPrint('Offline PMTiles lookup error: $e');
      }
    }

    // 2. If PMTiles is not loaded / file missing:
    // Check spatial cache (< 30m distance, < 20s old) -> instant emission without network roundtrip
    if (_isCacheValid(lat, lon)) {
      _pointController.add(_createRoadPoint(
        lat: lat,
        lon: lon,
        speedKmh: speedKmh,
        attributes: _lastKnownAttributes!,
        dataSource: 'Overpass kešatmiņa',
        timestamp: position.timestamp,
      ));
      return;
    }

    // 3. Cache is stale or new area: emit immediately with best available attributes
    // so the speedometer and driving assistant NEVER stutter or freeze ("bez aiztures")
    final initialAttrs = _lastKnownAttributes ?? _getLocalHeuristicAttributes(lat, lon);
    _pointController.add(_createRoadPoint(
      lat: lat,
      lon: lon,
      speedKmh: speedKmh,
      attributes: initialAttrs,
      dataSource: _lastKnownAttributes != null ? 'Pilsētas ceļš' : 'GPS meklē ceļu...',
      timestamp: position.timestamp,
    ));

    // 4. Concurrently query Overpass API to fetch up-to-date online attributes for this position
    _fetchOverpassAttributesConcurrently(lat, lon, position, speedKmh);
  }

  /// Concurrently fetches Overpass attributes without blocking the main GPS stream.
  Future<void> _fetchOverpassAttributesConcurrently(
    double lat,
    double lon,
    Position position,
    double speedKmh,
  ) async {
    if (_isOverpassQueryInFlight) return;
    _isOverpassQueryInFlight = true;

    try {
      final fetchedAttrs = await _fetchOsmRoadAttributes(lat, lon);
      if (fetchedAttrs != null) {
        _updateCache(lat, lon, fetchedAttrs);

        // Emit updated RoadPoint enriched with live Overpass online data
        _pointController.add(_createRoadPoint(
          lat: lat,
          lon: lon,
          speedKmh: speedKmh,
          attributes: fetchedAttrs,
          dataSource: 'Overpass API tiešsaiste',
          timestamp: position.timestamp,
        ));
      }
    } catch (e) {
      debugPrint('Overpass API concurrent lookup error: $e');
    } finally {
      _isOverpassQueryInFlight = false;
    }
  }

  /// Resolves road metadata synchronously or via direct await for a single coordinate.
  Future<RoadPoint> resolveRoadMetadata(Position position) async {
    final speedKmh = position.speed > 0 ? (position.speed * 3.6) : 0.0;
    final lat = position.latitude;
    final lon = position.longitude;

    // 1. Try local offline PMTiles
    if (pmTilesService != null && pmTilesService!.isLoaded) {
      try {
        final roadAttrs = await pmTilesService!.getRoadAttributes(lat, lon);
        if (roadAttrs != null) {
          _updateCache(lat, lon, roadAttrs);
          return _createRoadPoint(
            lat: lat,
            lon: lon,
            speedKmh: speedKmh,
            attributes: roadAttrs,
            dataSource: 'PMTiles bezsaistes karte',
            timestamp: position.timestamp,
          );
        }
      } catch (e) {
        debugPrint('Offline PMTiles lookup error: $e');
      }
    }

    // 2. Check spatial cache
    if (_isCacheValid(lat, lon)) {
      return _createRoadPoint(
        lat: lat,
        lon: lon,
        speedKmh: speedKmh,
        attributes: _lastKnownAttributes!,
        dataSource: 'Overpass kešatmiņa',
        timestamp: position.timestamp,
      );
    }

    // 3. Query Overpass API online
    try {
      final osmResult = await _fetchOsmRoadAttributes(lat, lon);
      if (osmResult != null) {
        _updateCache(lat, lon, osmResult);
        return _createRoadPoint(
          lat: lat,
          lon: lon,
          speedKmh: speedKmh,
          attributes: osmResult,
          dataSource: 'Overpass API tiešsaiste',
          timestamp: position.timestamp,
        );
      }
    } catch (e) {
      debugPrint('Overpass direct query error: $e');
    }

    // 4. Fallback to heuristic
    final fallbackAttrs = _lastKnownAttributes ?? _getLocalHeuristicAttributes(lat, lon);
    return _createRoadPoint(
      lat: lat,
      lon: lon,
      speedKmh: speedKmh,
      attributes: fallbackAttrs,
      dataSource: 'Pilsētas ceļš',
      timestamp: position.timestamp,
    );
  }

  /// Queries Overpass API across mirrors for the nearest drivable highway within 60m.
  Future<RoadAttributes?> _fetchOsmRoadAttributes(double lat, double lon) async {
    // Exclude pedestrian paths, sidewalks, footways, and cycle tracks
    final query =
        '[out:json][timeout:4];way(around:60,$lat,$lon)["highway"]["highway"!~"^(footway|path|cycleway|steps|pedestrian|track|corridor|bridleway)"];out tags 5;';
    final encodedQuery = Uri.encodeComponent(query);

    for (final endpoint in overpassEndpoints) {
      try {
        final url = Uri.parse('$endpoint?data=$encodedQuery');
        final response = await _httpClient.get(url).timeout(const Duration(milliseconds: 2500));
        if (response.statusCode == 200) {
          final bodyString = utf8.decode(response.bodyBytes);
          final data = json.decode(bodyString) as Map<String, dynamic>;
          final elements = data['elements'] as List<dynamic>?;
          if (elements != null && elements.isNotEmpty) {
            // Prioritize the highway that has an explicit street name or name:lv
            dynamic bestElement = elements.first;
            for (final el in elements) {
              final t = el['tags'] as Map<String, dynamic>?;
              if (t != null && (t.containsKey('name') || t.containsKey('name:lv'))) {
                bestElement = el;
                break;
              }
            }
            final tags = bestElement['tags'] as Map<String, dynamic>?;
            if (tags != null) {
              return _parseOsmTags(tags);
            }
          }
          return null;
        }
      } catch (e) {
        debugPrint('Overpass mirror $endpoint error: $e');
      }
    }
    return null;
  }

  /// Parses OpenStreetMap tags into [RoadAttributes], supporting Latvian speed limit conventions.
  RoadAttributes _parseOsmTags(Map<String, dynamic> tags) {
    int? maxspeed;
    final rawMaxspeed = tags['maxspeed']?.toString().trim();

    if (rawMaxspeed != null) {
      if (rawMaxspeed == 'LV:urban' || rawMaxspeed == 'urban') {
        maxspeed = 50;
      } else if (rawMaxspeed == 'LV:rural' || rawMaxspeed == 'rural') {
        maxspeed = 90;
      } else if (rawMaxspeed == 'LV:living_street' || rawMaxspeed == 'living_street') {
        maxspeed = 20;
      } else {
        final match = RegExp(r'\d+').firstMatch(rawMaxspeed);
        if (match != null) {
          maxspeed = int.tryParse(match.group(0)!);
        }
      }
    }

    // If maxspeed wasn't explicitly tagged, infer from highway classification
    final highway = tags['highway']?.toString().toLowerCase();
    if (maxspeed == null) {
      if (highway == 'living_street') {
        maxspeed = 20;
      } else if (highway == 'motorway') {
        maxspeed = 110;
      } else {
        maxspeed = 50;
      }
    }

    final rawOneway = tags['oneway']?.toString().toLowerCase();
    final isOneWay = rawOneway == 'yes' || rawOneway == '1' || rawOneway == '-1';

    final name = (tags['name'] ?? tags['name:lv'] ?? tags['ref'] ?? tags['loc_name'])?.toString();

    return RoadAttributes(
      maxspeed: maxspeed,
      isOneWay: isOneWay,
      name: name,
      roadClass: highway,
    );
  }

  /// Verifies if existing cached attributes are within valid distance and time.
  bool _isCacheValid(double lat, double lon) {
    if (_lastKnownAttributes == null || _lastQueriedLat == null || _lastQueriedLon == null || _lastQueryTime == null) {
      return false;
    }
    final distance = _distanceMeters(lat, lon, _lastQueriedLat!, _lastQueriedLon!);
    final isRecent = DateTime.now().difference(_lastQueryTime!).inSeconds < 20;
    return distance < 30.0 && isRecent;
  }

  void _updateCache(double lat, double lon, RoadAttributes attributes) {
    _lastKnownAttributes = attributes;
    _lastQueriedLat = lat;
    _lastQueriedLon = lon;
    _lastQueryTime = DateTime.now();
  }

  /// Fast local heuristic for generic Latvian roads fallback
  RoadAttributes _getLocalHeuristicAttributes(double lat, double lon) {
    int limit = 50;
    bool isOneWay = false;
    String streetName = 'Iela';

    // Ventspils historic center / quiet zone bounding box:
    if (lat >= 57.3930 && lat <= 57.3975 && lon >= 21.5540 && lon <= 21.5620) {
      limit = 30;
      streetName = 'Ventspils centrs';

      if (lat >= 57.3950 && lat <= 57.3968 && lon >= 21.5560 && lon <= 21.5590) {
        isOneWay = true;
        streetName = 'Sofijas iela';
      }
    } else {
      streetName = 'Pilsētas ceļš';
    }

    return RoadAttributes(
      maxspeed: limit,
      isOneWay: isOneWay,
      name: streetName,
      roadClass: 'residential',
    );
  }

  RoadPoint _createRoadPoint({
    required double lat,
    required double lon,
    required double speedKmh,
    required RoadAttributes attributes,
    required String dataSource,
    DateTime? timestamp,
  }) {
    return RoadPoint(
      latitude: lat,
      longitude: lon,
      vehicleSpeedKmh: speedKmh,
      maxSpeedLimitKmh: attributes.maxspeed ?? 50,
      isOneWay: attributes.isOneWay,
      streetName: attributes.name ?? 'Iela',
      timestamp: timestamp ?? DateTime.now(),
      dataSource: dataSource,
    );
  }

  /// Distance in meters using Haversine formula
  static double _distanceMeters(double lat1, double lon1, double lat2, double lon2) {
    const double p = 0.017453292519943295;
    final double a = 0.5 -
        math.cos((lat2 - lat1) * p) / 2 +
        math.cos(lat1 * p) * math.cos(lat2 * p) * (1 - math.cos((lon2 - lon1) * p)) / 2;
    return 12742000 * math.asin(math.sqrt(a));
  }

  /// Verifies GPS service status and requests runtime permissions.
  Future<bool> _checkAndRequestPermissions() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return false;
    }

    return true;
  }

  void dispose() {
    stopTracking();
    _httpClient.close();
    _pointController.close();
  }
}
