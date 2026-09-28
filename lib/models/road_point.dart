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
    );
  }

  @override
  String toString() {
    return 'RoadPoint($streetName, lat: $latitude, lon: $longitude, limit: $maxSpeedLimitKmh km/h, oneWay: $isOneWay, source: $dataSource, cycle: $isCycleway, foot: $isFootway)';
  }
}
