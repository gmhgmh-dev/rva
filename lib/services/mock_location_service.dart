import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:xml/xml.dart';
import '../models/road_point.dart';

/// Service simulating real GPS movement using a prepared GPX route through Ventspils streets.
/// Sequentially includes all 4 trigger scenarios:
/// 1. Lielais prospekts (50 km/h, two-way)
/// 2. Kuldīgas iela (30 km/h zone, two-way) -> Trigger 1: "Samazināts ātruma ierobežojums: 30 kilometri stundā."
/// 3. Sofijas iela (30 km/h, one-way) -> Trigger 3: "Jūs atrodaties uz vienvirziena ielas."
/// 4. Platā iela (30 km/h, two-way) -> Trigger 4: "Vienvirziena iela ir beigusies."
/// 5. Back to Lielais prospekts (50 km/h, two-way) -> Trigger 2: "Atruma ierobežojuma zona ir beigusies."
class MockLocationService {
  final List<RoadPoint> _waypoints = List.of(defaultVentspilsRoute);
  final StreamController<RoadPoint> _pointController = StreamController<RoadPoint>.broadcast();
  final StreamController<void> _simulationCompleteController = StreamController<void>.broadcast();
  Timer? _simulationTimer;
  int _currentIndex = 0;
  bool _isRunning = false;

  List<RoadPoint> get waypoints => List.unmodifiable(_waypoints);
  Stream<RoadPoint> get locationStream => _pointController.stream;
  Stream<void> get simulationCompleteStream => _simulationCompleteController.stream;
  bool get isRunning => _isRunning;
  int get currentIndex => _currentIndex;
  int get totalWaypoints => _waypoints.length;

  /// Default fallback waypoints in Ventspils if asset loading is not available (e.g. pure unit tests).
  static final List<RoadPoint> defaultVentspilsRoute = [
    RoadPoint(
      latitude: 57.391500,
      longitude: 21.564800,
      vehicleSpeedKmh: 45.0,
      maxSpeedLimitKmh: 50,
      isOneWay: false,
      streetName: 'Lielais prospekts',
      timestamp: DateTime.now(),
    ),
    RoadPoint(
      latitude: 57.392800,
      longitude: 21.562900,
      vehicleSpeedKmh: 48.0,
      maxSpeedLimitKmh: 50,
      isOneWay: false,
      streetName: 'Lielais prospekts',
      timestamp: DateTime.now(),
    ),
    // Trigger 1: 30 km/h zone
    RoadPoint(
      latitude: 57.393900,
      longitude: 21.560800,
      vehicleSpeedKmh: 28.0,
      maxSpeedLimitKmh: 30,
      isOneWay: false,
      streetName: 'Kuldīgas iela',
      timestamp: DateTime.now(),
    ),
    RoadPoint(
      latitude: 57.394800,
      longitude: 21.559200,
      vehicleSpeedKmh: 29.0,
      maxSpeedLimitKmh: 30,
      isOneWay: false,
      streetName: 'Kuldīgas iela',
      timestamp: DateTime.now(),
    ),
    // Trigger 3: One-way street
    RoadPoint(
      latitude: 57.395600,
      longitude: 21.557900,
      vehicleSpeedKmh: 26.0,
      maxSpeedLimitKmh: 30,
      isOneWay: true,
      streetName: 'Sofijas iela',
      timestamp: DateTime.now(),
    ),
    RoadPoint(
      latitude: 57.396400,
      longitude: 21.556800,
      vehicleSpeedKmh: 27.0,
      maxSpeedLimitKmh: 30,
      isOneWay: true,
      streetName: 'Sofijas iela',
      timestamp: DateTime.now(),
    ),
    // Trigger 4: Exiting one-way street
    RoadPoint(
      latitude: 57.397200,
      longitude: 21.555500,
      vehicleSpeedKmh: 28.0,
      maxSpeedLimitKmh: 30,
      isOneWay: false,
      streetName: 'Platā iela',
      timestamp: DateTime.now(),
    ),
    // Trigger 2: Exiting 30 km/h zone back to 50 km/h
    RoadPoint(
      latitude: 57.398200,
      longitude: 21.554200,
      vehicleSpeedKmh: 45.0,
      maxSpeedLimitKmh: 50,
      isOneWay: false,
      streetName: 'Lielais prospekts',
      timestamp: DateTime.now(),
    ),
    RoadPoint(
      latitude: 57.399500,
      longitude: 21.552800,
      vehicleSpeedKmh: 50.0,
      maxSpeedLimitKmh: 50,
      isOneWay: false,
      streetName: 'Lielais prospekts',
      timestamp: DateTime.now(),
    ),
  ];

  /// Loads the GPX route from assets or fallback list.
  Future<void> loadRoute({String assetPath = 'assets/routes/ventspils_route.gpx'}) async {
    try {
      final gpxString = await rootBundle.loadString(assetPath);
      final parsed = parseGpxString(gpxString);
      if (parsed.isNotEmpty) {
        _waypoints.clear();
        _waypoints.addAll(parsed);
      }
    } catch (_) {
      // Keep default route
    }
  }

  /// Loads the GPX route from a specific File with robust encoding fallback.
  Future<int> loadRouteFromFile(File file) async {
    try {
      final bytes = await file.readAsBytes();
      String gpxString;
      try {
        gpxString = utf8.decode(bytes);
      } catch (_) {
        gpxString = latin1.decode(bytes);
      }
      final parsed = parseGpxString(gpxString);
      if (parsed.isNotEmpty) {
        _waypoints.clear();
        _waypoints.addAll(parsed);
        _currentIndex = 0;
        return parsed.length;
      }
    } catch (e) {
      debugPrint('Error loading GPX from file: $e');
    }
    return 0;
  }

  /// Parses GPX XML string into a list of [RoadPoint].
  /// Supports trkpt, rtept, wpt elements as well as standard speed, time, desc, and extensions tags.
  List<RoadPoint> parseGpxString(String gpxContent) {
    final list = <RoadPoint>[];
    try {
      final document = XmlDocument.parse(gpxContent);
      var points = document.findAllElements('trkpt').toList();
      if (points.isEmpty) {
        points = document.findAllElements('rtept').toList();
      }
      if (points.isEmpty) {
        points = document.findAllElements('wpt').toList();
      }

      for (final pt in points) {
        final latStr = pt.getAttribute('lat') ?? '0.0';
        final lonStr = pt.getAttribute('lon') ?? '0.0';
        final lat = double.tryParse(latStr) ?? 0.0;
        final lon = double.tryParse(lonStr) ?? 0.0;

        String street = 'Pilsētas ceļš';
        int limit = 50;
        bool oneWay = false;
        double speed = 25.0;
        DateTime pointTime = DateTime.now();
        String? roadClass;
        bool isZone = false;
        bool isCycleway = false;
        bool isFootway = false;
        bool isPath = false;

        // 1. Time
        final timeElem = pt.findElements('time').firstOrNull;
        if (timeElem != null) {
          final dt = DateTime.tryParse(timeElem.innerText.trim());
          if (dt != null) pointTime = dt;
        }

        // 2. Speed (GPX standard is m/s, convert to km/h)
        final speedElem = pt.findElements('speed').firstOrNull;
        if (speedElem != null) {
          final speedMs = double.tryParse(speedElem.innerText.trim());
          if (speedMs != null) {
            speed = speedMs * 3.6;
          }
        }

        // 3. Desc parsing (e.g. "Iela: Katoļu iela, Atļauts: 50 km/h, Reāls: 0.3 km/h")
        final descElem = pt.findElements('desc').firstOrNull;
        if (descElem != null) {
          final descText = descElem.innerText.trim();
          final streetMatch = RegExp(r'Iela:\s*([^,]+)').firstMatch(descText);
          if (streetMatch != null) {
            final s = streetMatch.group(1)!.trim();
            if (s.isNotEmpty && s.toLowerCase() != 'null') street = s;
          }
          final limitMatch = RegExp(r'Atļauts:\s*(\d+)\s*km/h').firstMatch(descText);
          if (limitMatch != null) {
            limit = int.tryParse(limitMatch.group(1)!) ?? limit;
          }
          final realSpeedMatch = RegExp(r'Reāls:\s*([\d\.]+)\s*km/h').firstMatch(descText);
          if (realSpeedMatch != null) {
            final rs = double.tryParse(realSpeedMatch.group(1)!);
            if (rs != null) speed = rs;
          }
        }

        // 4. Name element
        final nameElem = pt.findElements('name').firstOrNull;
        if (nameElem != null && street == 'Pilsētas ceļš') {
          final n = nameElem.innerText.trim();
          if (n.isNotEmpty && n.toLowerCase() != 'null') street = n;
        }

        // 5. Extensions
        final extensions = pt.findElements('extensions').firstOrNull;
        if (extensions != null) {
          final streetElem = extensions.findElements('street_name').firstOrNull;
          if (streetElem != null) street = streetElem.innerText.trim();

          final limitElem = extensions.findElements('speed_limit').firstOrNull;
          if (limitElem != null) limit = int.tryParse(limitElem.innerText.trim()) ?? limit;

          final onewayElem = extensions.findElements('oneway').firstOrNull;
          if (onewayElem != null) {
            final val = onewayElem.innerText.trim();
            oneWay = (val == '1' || val.toLowerCase() == 'true');
          }

          final speedElem2 = extensions.findElements('vehicle_speed').firstOrNull;
          if (speedElem2 != null) {
            speed = double.tryParse(speedElem2.innerText.trim()) ?? speed;
          }

          final classElem = extensions.findElements('road_class').firstOrNull;
          if (classElem != null) roadClass = classElem.innerText.trim();

          final zoneElem = extensions.findElements('is_zone').firstOrNull;
          if (zoneElem != null) isZone = (zoneElem.innerText.trim().toLowerCase() == 'true');
        }

        // Check if bicycle or pedestrian way
        final lower = street.toLowerCase();
        if (lower.contains('velosipēd') || lower.contains('veloceļ')) {
          isCycleway = true;
          limit = 20;
        } else if (lower.contains('gājēj')) {
          isFootway = true;
          limit = 20;
        }

        list.add(
          RoadPoint(
            latitude: lat,
            longitude: lon,
            vehicleSpeedKmh: speed,
            maxSpeedLimitKmh: limit,
            isOneWay: oneWay,
            streetName: street,
            timestamp: pointTime,
            dataSource: 'Ierakstīts GPX maršruts',
            roadClass: roadClass,
            isZone: isZone,
            isCycleway: isCycleway,
            isFootway: isFootway,
            isPath: isPath,
          ),
        );
      }

      // Compute heading between consecutive points
      for (var i = 0; i < list.length; i++) {
        if (i < list.length - 1) {
          final p1 = list[i];
          final p2 = list[i + 1];
          final heading = _calculateBearing(p1.latitude, p1.longitude, p2.latitude, p2.longitude);
          list[i] = list[i].copyWith(heading: heading);
        } else if (list.length > 1) {
          list[i] = list[i].copyWith(heading: list[i - 1].heading);
        }
      }
    } catch (e) {
      debugPrint('GPX parse error: $e');
    }
    return list;
  }

  /// Calculates navigation bearing between two GPS coordinates in degrees [0, 360)
  static double _calculateBearing(double lat1, double lon1, double lat2, double lon2) {
    const p = math.pi / 180.0;
    final phi1 = lat1 * p;
    final phi2 = lat2 * p;
    final deltaLambda = (lon2 - lon1) * p;
    final y = math.sin(deltaLambda) * math.cos(phi2);
    final x = math.cos(phi1) * math.sin(phi2) -
        math.sin(phi1) * math.cos(phi2) * math.cos(deltaLambda);
    final bearing = math.atan2(y, x) * 180.0 / math.pi;
    return (bearing + 360.0) % 360.0;
  }

  /// Starts the simulated GPS route playback.
  Future<void> startSimulation({Duration interval = const Duration(seconds: 2)}) async {
    if (_waypoints.isEmpty) {
      await loadRoute();
    }
    stopSimulation();

    _isRunning = true;
    _currentIndex = 0;

    // Emit first waypoint immediately
    if (_waypoints.isNotEmpty) {
      _pointController.add(_waypoints[_currentIndex]);
    }

    _simulationTimer = Timer.periodic(interval, (timer) {
      if (!_isRunning) {
        timer.cancel();
        return;
      }

      _currentIndex++;
      if (_currentIndex >= _waypoints.length) {
        // Route complete
        stopSimulation();
        _simulationCompleteController.add(null);
        return;
      }

      _pointController.add(_waypoints[_currentIndex]);
    });
  }

  /// Advances a single step manually (useful for testing or fast-forward).
  void nextStep() {
    if (_waypoints.isEmpty) {
      _waypoints.addAll(defaultVentspilsRoute);
    }
    if (_currentIndex < _waypoints.length - 1) {
      _currentIndex++;
    } else {
      _currentIndex = 0;
    }
    _pointController.add(_waypoints[_currentIndex]);
  }

  /// Stops the current simulation.
  void stopSimulation() {
    _simulationTimer?.cancel();
    _simulationTimer = null;
    _isRunning = false;
  }

  void dispose() {
    stopSimulation();
    _pointController.close();
    _simulationCompleteController.close();
  }
}
