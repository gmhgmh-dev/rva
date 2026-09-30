import 'lookahead_event.dart';

/// Model representing a GPS waypoint with road attributes such as speed limit
/// and whether the street is one-way.
class RoadPoint {
  final double latitude;
  final double longitude;
  final double vehicleSpeedKmh;
  final int maxSpeedLimitKmh;
  final bool isOneWay;
  final String streetName;
  final DateTime timestamp;
  final String dataSource;
  final String? roadClass;
  final bool isZone;
  final bool isCycleway;
  final bool isFootway;
  final bool isPath;
  final double? heading;
  final int? lookaheadMaxSpeed;
  final double? lookaheadDistanceMeters;
  final bool hasTrafficCalmingAhead;
  final String? trafficCalmingAheadType;
  final bool hasSpeedCameraAhead;
  final int? speedCameraLimitAhead;
  final List<LookaheadEvent> lookaheadEvents;

  const RoadPoint({
    required this.latitude,
    required this.longitude,
    required this.vehicleSpeedKmh,
    required this.maxSpeedLimitKmh,
    required this.isOneWay,
    required this.streetName,
    required this.timestamp,
    this.dataSource = 'Demo simulācija',
    this.roadClass,
    this.isZone = false,
    this.isCycleway = false,
    this.isFootway = false,
    this.isPath = false,
    this.heading,
    this.lookaheadMaxSpeed,
    this.lookaheadDistanceMeters,
    this.hasTrafficCalmingAhead = false,
    this.trafficCalmingAheadType,
    this.hasSpeedCameraAhead = false,
    this.speedCameraLimitAhead,
    this.lookaheadEvents = const [],
  });

  bool get isPedestrianOrBicycle => isCycleway || isFootway || isPath;

  RoadPoint copyWith({
    double? latitude,
    double? longitude,
    double? vehicleSpeedKmh,
    int? maxSpeedLimitKmh,
    bool? isOneWay,
    String? streetName,
    DateTime? timestamp,
    String? dataSource,
    String? roadClass,
    bool? isZone,
    bool? isCycleway,
    bool? isFootway,
    bool? isPath,
    double? heading,
    int? lookaheadMaxSpeed,
    double? lookaheadDistanceMeters,
    bool? hasTrafficCalmingAhead,
    String? trafficCalmingAheadType,
    bool? hasSpeedCameraAhead,
    int? speedCameraLimitAhead,
    List<LookaheadEvent>? lookaheadEvents,
  }) {
    return RoadPoint(
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      vehicleSpeedKmh: vehicleSpeedKmh ?? this.vehicleSpeedKmh,
      maxSpeedLimitKmh: maxSpeedLimitKmh ?? this.maxSpeedLimitKmh,
      isOneWay: isOneWay ?? this.isOneWay,
      streetName: streetName ?? this.streetName,
      timestamp: timestamp ?? this.timestamp,
      dataSource: dataSource ?? this.dataSource,
      roadClass: roadClass ?? this.roadClass,
      isZone: isZone ?? this.isZone,
      isCycleway: isCycleway ?? this.isCycleway,
      isFootway: isFootway ?? this.isFootway,
      isPath: isPath ?? this.isPath,
      heading: heading ?? this.heading,
      lookaheadMaxSpeed: lookaheadMaxSpeed ?? this.lookaheadMaxSpeed,
      lookaheadDistanceMeters: lookaheadDistanceMeters ?? this.lookaheadDistanceMeters,
      hasTrafficCalmingAhead: hasTrafficCalmingAhead ?? this.hasTrafficCalmingAhead,
      trafficCalmingAheadType: trafficCalmingAheadType ?? this.trafficCalmingAheadType,
      hasSpeedCameraAhead: hasSpeedCameraAhead ?? this.hasSpeedCameraAhead,
      speedCameraLimitAhead: speedCameraLimitAhead ?? this.speedCameraLimitAhead,
      lookaheadEvents: lookaheadEvents ?? this.lookaheadEvents,
    );
  }

  @override
  String toString() {
    return 'RoadPoint($streetName, lat: $latitude, lon: $longitude, limit: $maxSpeedLimitKmh km/h, oneWay: $isOneWay, source: $dataSource, cycle: $isCycleway, foot: $isFootway, lookahead: $lookaheadMaxSpeed)';
  }
}
