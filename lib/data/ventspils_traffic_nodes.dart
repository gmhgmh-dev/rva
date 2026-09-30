// Offline catalog of Ventspils traffic control nodes (traffic signals, give way, stop signs)
// Sourced from OpenStreetMap for instant, offline lookahead safety alerts.

import 'dart:math';
import '../models/lookahead_event.dart';

class TrafficNode {
  final int id;
  final double lat;
  final double lon;
  final LookaheadEventType type;
  final String? direction;

  const TrafficNode({
    required this.id,
    required this.lat,
    required this.lon,
    required this.type,
    this.direction,
  });
}

class VentspilsTrafficNodes {
  static const List<TrafficNode> nodes = [
    TrafficNode(id: 29705222, lat: 57.387816, lon: 21.582507, type: LookaheadEventType.trafficLight, direction: null),
    TrafficNode(id: 29705226, lat: 57.389709, lon: 21.57412, type: LookaheadEventType.trafficLight, direction: null),
    TrafficNode(id: 29705229, lat: 57.389651, lon: 21.564548, type: LookaheadEventType.trafficLight, direction: null),
    TrafficNode(id: 29705231, lat: 57.389621, lon: 21.558811, type: LookaheadEventType.trafficLight, direction: null),
    TrafficNode(id: 29705232, lat: 57.389643, lon: 21.553943, type: LookaheadEventType.trafficLight, direction: null),
    TrafficNode(id: 30623642, lat: 57.390331, lon: 21.54718, type: LookaheadEventType.trafficLight, direction: null),
    TrafficNode(id: 30623649, lat: 57.384111, lon: 21.550297, type: LookaheadEventType.trafficLight, direction: null),
    TrafficNode(id: 30623650, lat: 57.383205, lon: 21.554462, type: LookaheadEventType.trafficLight, direction: null),
    TrafficNode(id: 30679326, lat: 57.403843, lon: 21.59047, type: LookaheadEventType.trafficLight, direction: null),
    TrafficNode(id: 30685042, lat: 57.391123, lon: 21.595946, type: LookaheadEventType.trafficLight, direction: null),
    TrafficNode(id: 31999624, lat: 57.381777, lon: 21.577291, type: LookaheadEventType.trafficLight, direction: null),
    TrafficNode(id: 32633336, lat: 57.391652, lon: 21.563378, type: LookaheadEventType.trafficLight, direction: null),
    TrafficNode(id: 32633337, lat: 57.391623, lon: 21.5639, type: LookaheadEventType.trafficLight, direction: null),
    TrafficNode(id: 32633368, lat: 57.393767, lon: 21.564715, type: LookaheadEventType.trafficLight, direction: null),
    TrafficNode(id: 32633610, lat: 57.402986, lon: 21.598185, type: LookaheadEventType.trafficLight, direction: null),
    TrafficNode(id: 32671958, lat: 57.396711, lon: 21.590064, type: LookaheadEventType.trafficLight, direction: null),
    TrafficNode(id: 32671959, lat: 57.396807, lon: 21.590523, type: LookaheadEventType.trafficLight, direction: null),
    TrafficNode(id: 32672998, lat: 57.389641, lon: 21.562751, type: LookaheadEventType.trafficLight, direction: null),
    TrafficNode(id: 33792730, lat: 57.391839, lon: 21.559915, type: LookaheadEventType.trafficLight, direction: null),
    TrafficNode(id: 55111128, lat: 57.382402, lon: 21.559988, type: LookaheadEventType.trafficLight, direction: null),
    TrafficNode(id: 55177145, lat: 57.381989, lon: 21.566497, type: LookaheadEventType.trafficLight, direction: null),
    TrafficNode(id: 55177555, lat: 57.380514, lon: 21.570439, type: LookaheadEventType.trafficLight, direction: null),
    TrafficNode(id: 55195191, lat: 57.394944, lon: 21.568983, type: LookaheadEventType.trafficLight, direction: null),
    TrafficNode(id: 253016497, lat: 57.395069, lon: 21.568886, type: LookaheadEventType.trafficLight, direction: null),
    TrafficNode(id: 278251646, lat: 57.391171, lon: 21.59615, type: LookaheadEventType.trafficLight, direction: null),
    TrafficNode(id: 12077333541, lat: 57.389492, lon: 21.564601, type: LookaheadEventType.trafficLight, direction: 'forward'),
    TrafficNode(id: 12077349497, lat: 57.393548, lon: 21.564572, type: LookaheadEventType.trafficLight, direction: 'forward'),
    TrafficNode(id: 1109629179, lat: 57.387116, lon: 21.585477, type: LookaheadEventType.giveWay, direction: null),
    TrafficNode(id: 8857668340, lat: 57.386812, lon: 21.586114, type: LookaheadEventType.giveWay, direction: null),
    TrafficNode(id: 12155477275, lat: 57.387227, lon: 21.586184, type: LookaheadEventType.giveWay, direction: null),
    TrafficNode(id: 12470865683, lat: 57.373315, lon: 21.565214, type: LookaheadEventType.giveWay, direction: 'forward'),
    TrafficNode(id: 12471085195, lat: 57.377409, lon: 21.557305, type: LookaheadEventType.giveWay, direction: 'backward'),
    TrafficNode(id: 12471085196, lat: 57.377963, lon: 21.557855, type: LookaheadEventType.giveWay, direction: 'backward'),
    TrafficNode(id: 12471124796, lat: 57.387229, lon: 21.542415, type: LookaheadEventType.giveWay, direction: 'backward'),
    TrafficNode(id: 12471124797, lat: 57.387217, lon: 21.541862, type: LookaheadEventType.giveWay, direction: 'backward'),
    TrafficNode(id: 12471129280, lat: 57.380849, lon: 21.553266, type: LookaheadEventType.giveWay, direction: 'backward'),
    TrafficNode(id: 12471129282, lat: 57.379744, lon: 21.558529, type: LookaheadEventType.giveWay, direction: 'forward'),
    TrafficNode(id: 12471129284, lat: 57.380075, lon: 21.556769, type: LookaheadEventType.giveWay, direction: 'forward'),
    TrafficNode(id: 12471129285, lat: 57.380178, lon: 21.556822, type: LookaheadEventType.giveWay, direction: 'backward'),
    TrafficNode(id: 12471129286, lat: 57.380468, lon: 21.554928, type: LookaheadEventType.giveWay, direction: 'forward'),
    TrafficNode(id: 12471129287, lat: 57.380563, lon: 21.554981, type: LookaheadEventType.giveWay, direction: 'backward'),
    TrafficNode(id: 12471129288, lat: 57.379188, lon: 21.558531, type: LookaheadEventType.giveWay, direction: 'forward'),
    TrafficNode(id: 12471129289, lat: 57.376387, lon: 21.559631, type: LookaheadEventType.giveWay, direction: 'backward'),
    TrafficNode(id: 12471129290, lat: 57.374732, lon: 21.562309, type: LookaheadEventType.giveWay, direction: 'forward'),
    TrafficNode(id: 12471129291, lat: 57.37402, lon: 21.563336, type: LookaheadEventType.giveWay, direction: 'backward'),
    TrafficNode(id: 12471129292, lat: 57.373228, lon: 21.565516, type: LookaheadEventType.giveWay, direction: 'backward'),
    TrafficNode(id: 12471138255, lat: 57.390217, lon: 21.542755, type: LookaheadEventType.giveWay, direction: 'forward'),
    TrafficNode(id: 12471138256, lat: 57.390112, lon: 21.54337, type: LookaheadEventType.giveWay, direction: 'backward'),
    TrafficNode(id: 12471138257, lat: 57.38965, lon: 21.54184, type: LookaheadEventType.giveWay, direction: 'backward'),
    TrafficNode(id: 12471138258, lat: 57.389551, lon: 21.54168, type: LookaheadEventType.giveWay, direction: 'forward'),
    TrafficNode(id: 12471138259, lat: 57.388545, lon: 21.544038, type: LookaheadEventType.giveWay, direction: 'backward'),
    TrafficNode(id: 12471138271, lat: 57.390913, lon: 21.544868, type: LookaheadEventType.giveWay, direction: 'forward'),
    TrafficNode(id: 12471138966, lat: 57.390715, lon: 21.542123, type: LookaheadEventType.giveWay, direction: 'forward'),
    TrafficNode(id: 12471138967, lat: 57.391413, lon: 21.543169, type: LookaheadEventType.giveWay, direction: 'backward'),
    TrafficNode(id: 12471268737, lat: 57.373442, lon: 21.564464, type: LookaheadEventType.giveWay, direction: 'backward'),
    TrafficNode(id: 12471085197, lat: 57.378028, lon: 21.55729, type: LookaheadEventType.stopSign, direction: 'forward'),
  ];

  /// Scans offline nodes ahead of vehicle within [lookaheadDist] along vehicle [heading].
  static List<LookaheadEvent> findUpcomingNodes({
    required double lat,
    required double lon,
    required double heading,
    required double lookaheadDist,
    double minDistance = 15.0,
  }) {
    final results = <LookaheadEvent>[];
    for (final node in nodes) {
      final d = _calculateDistance(lat, lon, node.lat, node.lon);
      if (d >= minDistance && d <= lookaheadDist) {
        final bearing = _calculateBearing(lat, lon, node.lat, node.lon);
        double diff = (heading - bearing).abs() % 360.0;
        if (diff > 180.0) diff = 360.0 - diff;
        if (diff <= 35.0) {
          results.add(
            LookaheadEvent(
              type: node.type,
              distanceMeters: d,
              latitude: node.lat,
              longitude: node.lon,
            ),
          );
        }
      }
    }
    return results;
  }

  static double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371000.0;
    final dLat = (lat2 - lat1) * pi / 180.0;
    final dLon = (lon2 - lon1) * pi / 180.0;
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * pi / 180.0) * cos(lat2 * pi / 180.0) * sin(dLon / 2) * sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return r * c;
  }

  static double _calculateBearing(double lat1, double lon1, double lat2, double lon2) {
    final phi1 = lat1 * pi / 180.0;
    final phi2 = lat2 * pi / 180.0;
    final deltaLambda = (lon2 - lon1) * pi / 180.0;
    final y = sin(deltaLambda) * cos(phi2);
    final x = cos(phi1) * sin(phi2) - sin(phi1) * cos(phi2) * cos(deltaLambda);
    final theta = atan2(y, x);
    return (theta * 180.0 / pi + 360.0) % 360.0;
  }
}

