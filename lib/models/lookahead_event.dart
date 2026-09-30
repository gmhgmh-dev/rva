enum LookaheadEventType {
  trafficLight,
  giveWay,
  stopSign,
  mainRoadReminder,
  equalIntersection,
  mainRoadTurnsRight,
  mainRoadTurnsLeft,
  speedLimitChange,
  trafficCalming,
  speedCamera,
}

class LookaheadEvent {
  final LookaheadEventType type;
  final double distanceMeters;
  final double latitude;
  final double longitude;
  final int? speedLimit;

  const LookaheadEvent({
    required this.type,
    required this.distanceMeters,
    required this.latitude,
    required this.longitude,
    this.speedLimit,
  });

  @override
  String toString() {
    return 'LookaheadEvent(type: $type, dist: ${distanceMeters.toStringAsFixed(1)}m)';
  }
}
