/// Model representing road attributes retrieved from vector map tiles (PMTiles).
class RoadAttributes {
  final int? maxspeed;
  final bool isOneWay;
  final String? name;
  final double? distanceMeters;
  final String? roadClass;
  final bool isZone;
  final bool isCycleway;
  final bool isFootway;
  final bool isPath;
  final bool hasTrafficCalming;
  final String? trafficCalmingType;
  final bool hasSpeedCamera;
  final int? speedCameraLimit;

  const RoadAttributes({
    this.maxspeed,
    this.isOneWay = false,
    this.name,
    this.distanceMeters,
    this.roadClass,
    this.isZone = false,
    this.isCycleway = false,
    this.isFootway = false,
    this.isPath = false,
    this.hasTrafficCalming = false,
    this.trafficCalmingType,
    this.hasSpeedCamera = false,
    this.speedCameraLimit,
  });

  bool get isPedestrianOrBicycle => isCycleway || isFootway || isPath;

  RoadAttributes copyWith({
    int? maxspeed,
    bool? isOneWay,
    String? name,
    double? distanceMeters,
    String? roadClass,
    bool? isZone,
    bool? isCycleway,
    bool? isFootway,
    bool? isPath,
    bool? hasTrafficCalming,
    String? trafficCalmingType,
    bool? hasSpeedCamera,
    int? speedCameraLimit,
  }) {
    return RoadAttributes(
      maxspeed: maxspeed ?? this.maxspeed,
      isOneWay: isOneWay ?? this.isOneWay,
      name: name ?? this.name,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      roadClass: roadClass ?? this.roadClass,
      isZone: isZone ?? this.isZone,
      isCycleway: isCycleway ?? this.isCycleway,
      isFootway: isFootway ?? this.isFootway,
      isPath: isPath ?? this.isPath,
      hasTrafficCalming: hasTrafficCalming ?? this.hasTrafficCalming,
      trafficCalmingType: trafficCalmingType ?? this.trafficCalmingType,
      hasSpeedCamera: hasSpeedCamera ?? this.hasSpeedCamera,
      speedCameraLimit: speedCameraLimit ?? this.speedCameraLimit,
    );
  }

  @override
  String toString() {
    return 'RoadAttributes(name: $name, maxspeed: $maxspeed, oneway: $isOneWay, distance: ${distanceMeters?.toStringAsFixed(1)}m, class: $roadClass, cycleway: $isCycleway, footway: $isFootway, bump: $hasTrafficCalming, camera: $hasSpeedCamera)';
  }
}
