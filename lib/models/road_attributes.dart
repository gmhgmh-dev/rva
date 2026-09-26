/// Model representing road attributes retrieved from vector map tiles (PMTiles).
class RoadAttributes {
  final int? maxspeed;
  final bool isOneWay;
  final String? name;
  final double? distanceMeters;
  final String? roadClass;

  const RoadAttributes({
    this.maxspeed,
    this.isOneWay = false,
    this.name,
    this.distanceMeters,
    this.roadClass,
  });

  RoadAttributes copyWith({
    int? maxspeed,
    bool? isOneWay,
    String? name,
    double? distanceMeters,
    String? roadClass,
  }) {
    return RoadAttributes(
      maxspeed: maxspeed ?? this.maxspeed,
      isOneWay: isOneWay ?? this.isOneWay,
      name: name ?? this.name,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      roadClass: roadClass ?? this.roadClass,
    );
  }

  @override
  String toString() {
    return 'RoadAttributes(name: $name, maxspeed: $maxspeed, oneway: $isOneWay, distance: ${distanceMeters?.toStringAsFixed(1)}m, class: $roadClass)';
  }
}
