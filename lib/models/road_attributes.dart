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

  @override
  String toString() {
    return 'RoadAttributes(name: $name, maxspeed: $maxspeed, oneway: $isOneWay, distance: ${distanceMeters?.toStringAsFixed(1)}m, class: $roadClass)';
  }
}
