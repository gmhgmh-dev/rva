import 'dart:io';
import 'dart:async';
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
  Timer? _simulationTimer;
  int _currentIndex = 0;
  bool _isRunning = false;

  List<RoadPoint> get waypoints => List.unmodifiable(_waypoints);
  Stream<RoadPoint> get locationStream => _pointController.stream;
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

  /// Loads the GPX route from a specific File.
  Future<void> loadRouteFromFile(File file) async {
    try {
      final gpxString = await file.readAsString();
      final parsed = parseGpxString(gpxString);
      if (parsed.isNotEmpty) {
        _waypoints.clear();
        _waypoints.addAll(parsed);
      }
    } catch (_) {
      // Ignore and keep what we have
    }
  }

  /// Parses GPX XML string into a list of [RoadPoint].
  List<RoadPoint> parseGpxString(String gpxContent) {
    final list = <RoadPoint>[];
    try {
      final document = XmlDocument.parse(gpxContent);
      final trkpts = document.findAllElements('trkpt');

      for (final trkpt in trkpts) {
        final latStr = trkpt.getAttribute('lat') ?? '0.0';
        final lonStr = trkpt.getAttribute('lon') ?? '0.0';
        final lat = double.tryParse(latStr) ?? 0.0;
        final lon = double.tryParse(lonStr) ?? 0.0;

        String street = 'Ventspils';
        int limit = 50;
        bool oneWay = false;
        double speed = 40.0;

        final extensions = trkpt.findElements('extensions').firstOrNull;
        if (extensions != null) {
          final streetElem = extensions.findElements('street_name').firstOrNull;
          if (streetElem != null) street = streetElem.innerText.trim();

          final limitElem = extensions.findElements('speed_limit').firstOrNull;
          if (limitElem != null) limit = int.tryParse(limitElem.innerText.trim()) ?? 50;

          final onewayElem = extensions.findElements('oneway').firstOrNull;
          if (onewayElem != null) {
            final val = onewayElem.innerText.trim();
            oneWay = (val == '1' || val.toLowerCase() == 'true');
          }

          final speedElem = extensions.findElements('vehicle_speed').firstOrNull;
          if (speedElem != null) {
            speed = double.tryParse(speedElem.innerText.trim()) ?? 40.0;
          }
        }

        list.add(
          RoadPoint(
            latitude: lat,
            longitude: lon,
            vehicleSpeedKmh: speed,
            maxSpeedLimitKmh: limit,
            isOneWay: oneWay,
            streetName: street,
            timestamp: DateTime.now(),
          ),
        );
      }
    } catch (e) {
      // If parsing fails, list will be empty
    }
    return list;
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
  }
}
