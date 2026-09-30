import 'dart:math';
import 'package:vector_tile/vector_tile.dart';
import '../models/lookahead_event.dart';

class PathTraversalHelper {
  /// Traverses the current LineString forward based on heading and distance.
  /// Finds points of interest (traffic signals, stop signs) and intersections.
  static List<LookaheadEvent> traverse({
    required VectorTile tile,
    required double startPx,
    required double startPy,
    required double heading,
    required int extent,
    required double metersPerPixel,
    required double maxDistanceMeters,
    required String? currentRoadName,
    required double currentLat,
    required double currentLon,
  }) {
    final events = <LookaheadEvent>[];
    
    // 1. Find the current road feature (LineString)
    VectorTileFeature? currentRoad;
    double minRoadDistSq = double.infinity;
    List<List<int>> bestLine = [];
    int bestSegmentIndex = -1;
    bool traverseForward = true;

    final roadLayers = tile.layers.where((l) {
      final name = l.name.toLowerCase();
      return name == 'transportation' || name == 'road' || name == 'roads';
    });

    for (final layer in roadLayers) {
      for (final feature in layer.features) {
        if (feature.type != VectorTileGeomType.LINESTRING) continue;
        
        final lines = feature.decodeLineString();
        for (final line in lines) {
          for (var i = 0; i < line.length - 1; i++) {
            final p1 = line[i];
            final p2 = line[i + 1];
            
            final distSq = _pointToSegmentDistanceSq(
              startPx, startPy,
              p1[0].toDouble(), p1[1].toDouble(),
              p2[0].toDouble(), p2[1].toDouble()
            );
            
            if (distSq < minRoadDistSq) {
              // Also check heading alignment to ensure we don't snap to a cross street
              final dx = p2[0].toDouble() - p1[0].toDouble();
              final dy = p2[1].toDouble() - p1[1].toDouble();
              final segmentBearing = _calculateSegmentBearing(dx, dy);
              final diffForward = _angleDifference(heading, segmentBearing);
              final diffBackward = _angleDifference(heading, (segmentBearing + 180.0) % 360.0);
              
              if (diffForward < 45.0 || diffBackward < 45.0) {
                minRoadDistSq = distSq;
                currentRoad = feature;
                bestLine = line;
                bestSegmentIndex = i;
                traverseForward = diffForward < 45.0;
              }
            }
          }
        }
      }
    }

    if (currentRoad == null || bestLine.isEmpty) return events;

    // 2. Extract path points to traverse
    List<List<int>> pathPixels = [];
    if (traverseForward) {
      // Add a projected point on the segment as the start
      pathPixels.add([startPx.round(), startPy.round()]);
      for (var i = bestSegmentIndex + 1; i < bestLine.length; i++) {
        pathPixels.add(bestLine[i]);
      }
    } else {
      pathPixels.add([startPx.round(), startPy.round()]);
      for (var i = bestSegmentIndex; i >= 0; i--) {
        pathPixels.add(bestLine[i]);
      }
    }

    // 3. Walk the path, accumulating distance, and checking for POIs/intersections near each segment
    double accumulatedDistanceMeters = 0.0;
    
    // Collect POIs
    final poiFeatures = <VectorTileFeature>[];
    for (final layer in tile.layers) {
      for (final feature in layer.features) {
        if (feature.type == VectorTileGeomType.POINT) {
          poiFeatures.add(feature);
        }
      }
    }

    // Collect all other roads for intersection checks
    final allRoadLines = <Map<String, dynamic>>[];
    for (final layer in roadLayers) {
      for (final feature in layer.features) {
        if (feature.id == currentRoad.id) continue; // Skip ourselves
        if (feature.type != VectorTileGeomType.LINESTRING) continue;
        final props = feature.decodeProperties();
        allRoadLines.add({
          'feature': feature,
          'lines': feature.decodeLineString(),
          'class': (props['class']?.value ?? props['highway']?.value)?.toString().toLowerCase() ?? '',
          'name': (props['name'] ?? props['name:lv'] ?? props['name:latin'])?.value.toString().toLowerCase()
        });
      }
    }

    final currentProps = currentRoad.decodeProperties();
    final currentClass = (currentProps['class']?.value ?? currentProps['highway']?.value)?.toString().toLowerCase() ?? '';

    Set<int> processedPoiIds = {};
    Set<int> processedRoadIds = {};

    for (var i = 0; i < pathPixels.length - 1; i++) {
      final p1 = pathPixels[i];
      final p2 = pathPixels[i + 1];
      
      final dx = p2[0] - p1[0];
      final dy = p2[1] - p1[1];
      final segLengthPixels = sqrt(dx * dx + dy * dy);
      final segLengthMeters = segLengthPixels * metersPerPixel;
      
      if (accumulatedDistanceMeters + segLengthMeters > maxDistanceMeters) {
        // We reached the lookahead limit
        break;
      }

      // Check POIs near this segment
      for (final poi in poiFeatures) {
        if (processedPoiIds.contains(poi.id.toInt())) continue;
        final geom = poi.decodePoint();
        if (geom.isEmpty || geom[0].length < 2) continue;
        final px = geom[0][0].toDouble();
        final py = geom[0][1].toDouble();
        
        final distSq = _pointToSegmentDistanceSq(px, py, p1[0].toDouble(), p1[1].toDouble(), p2[0].toDouble(), p2[1].toDouble());
        final distMeters = sqrt(distSq) * metersPerPixel;
        
        if (distMeters < 15.0) { // Within 15 meters of the path
          final props = poi.decodeProperties();
          final highway = (props['highway'] ?? props['subclass'] ?? props['class'])?.value.toString().toLowerCase();
          
          LookaheadEventType? type;
          if (highway == 'traffic_signals' || highway == 'traffic_light' || props.containsKey('traffic_signals')) {
            type = LookaheadEventType.trafficLight;
          } else if (highway == 'stop' || highway == 'stop_sign') {
            type = LookaheadEventType.stopSign;
          } else if (highway == 'give_way' || highway == 'yield') {
            type = LookaheadEventType.giveWay;
          }
          
          if (type != null) {
            events.add(LookaheadEvent(
              type: type,
              distanceMeters: accumulatedDistanceMeters + (segLengthMeters * 0.5), // Approx distance
              latitude: currentLat, // Ideally we convert px,py to lat,lon, but currentLat works for the alert
              longitude: currentLon,
            ));
            processedPoiIds.add(poi.id.toInt());
          }
        }
      }

      // Check Intersections with other roads
      for (final road in allRoadLines) {
        final feature = road['feature'] as VectorTileFeature;
        if (processedRoadIds.contains(feature.id.toInt())) continue;
        
        final lines = road['lines'] as List<List<List<int>>>;
        bool intersects = false;
        
        for (final line in lines) {
          for (var j = 0; j < line.length - 1; j++) {
            final rp1 = line[j];
            final rp2 = line[j + 1];
            if (_segmentsIntersect(
                p1[0].toDouble(), p1[1].toDouble(), p2[0].toDouble(), p2[1].toDouble(),
                rp1[0].toDouble(), rp1[1].toDouble(), rp2[0].toDouble(), rp2[1].toDouble())) {
              intersects = true;
              break;
            }
          }
          if (intersects) break;
        }

        if (intersects) {
          final interClass = road['class'] as String;
          // Logic for intersection types
          final isCurrentMain = (currentClass == 'primary' || currentClass == 'secondary' || currentClass == 'tertiary');
          final isInterMinor = (interClass == 'residential' || interClass == 'unclassified' || interClass == 'service');
          
          if (isCurrentMain && isInterMinor) {
            events.add(LookaheadEvent(
              type: LookaheadEventType.mainRoadReminder,
              distanceMeters: accumulatedDistanceMeters + (segLengthMeters * 0.5),
              latitude: currentLat,
              longitude: currentLon,
            ));
          } else if (currentClass == interClass && currentClass != 'service') {
             events.add(LookaheadEvent(
              type: LookaheadEventType.equalIntersection,
              distanceMeters: accumulatedDistanceMeters + (segLengthMeters * 0.5),
              latitude: currentLat,
              longitude: currentLon,
            ));
          }
          processedRoadIds.add(feature.id.toInt());
        }
      }

      accumulatedDistanceMeters += segLengthMeters;
    }

    return filterByHierarchy(events);
  }

  /// Filters lookahead events by CSN priority hierarchy within spatial clusters (25m threshold).
  ///
  /// CSN Priority Hierarchy:
  /// 1. Traffic Light (`trafficLight`) - suppresses all signs and intersection reminders
  /// 2. Stop Sign (`stopSign`) - suppresses give way and intersection reminders
  /// 3. Give Way (`giveWay`) - suppresses intersection reminders
  /// 4. Main Road turns (`mainRoadTurnsRight`, `mainRoadTurnsLeft`)
  /// 5. Main Road Reminder (`mainRoadReminder`)
  /// 6. Equal Intersection (`equalIntersection`)
  static List<LookaheadEvent> filterByHierarchy(
    List<LookaheadEvent> rawEvents, {
    double clusterThresholdMeters = 25.0,
  }) {
    if (rawEvents.length <= 1) return rawEvents;

    // 1. Sort by distance along the path
    final sorted = List<LookaheadEvent>.from(rawEvents)
      ..sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));

    // 2. Group into spatial clusters within clusterThresholdMeters
    final List<List<LookaheadEvent>> clusters = [];
    List<LookaheadEvent> currentCluster = [];

    for (final event in sorted) {
      if (currentCluster.isEmpty) {
        currentCluster.add(event);
      } else {
        if ((event.distanceMeters - currentCluster.first.distanceMeters).abs() <= clusterThresholdMeters) {
          currentCluster.add(event);
        } else {
          clusters.add(currentCluster);
          currentCluster = [event];
        }
      }
    }
    if (currentCluster.isNotEmpty) {
      clusters.add(currentCluster);
    }

    // 3. For each cluster, pick the single dominant event by CSN priority among intersection controls
    final List<LookaheadEvent> result = [];
    for (final cluster in clusters) {
      final intersectionEvents = cluster.where((e) => _isIntersectionControl(e.type)).toList();
      final nonIntersectionEvents = cluster.where((e) => !_isIntersectionControl(e.type)).toList();

      if (intersectionEvents.isNotEmpty) {
        intersectionEvents.sort((a, b) => _priorityRank(a.type).compareTo(_priorityRank(b.type)));
        result.add(intersectionEvents.first);
      }
      result.addAll(nonIntersectionEvents);
    }

    return result;
  }

  static bool _isIntersectionControl(LookaheadEventType type) {
    switch (type) {
      case LookaheadEventType.trafficLight:
      case LookaheadEventType.stopSign:
      case LookaheadEventType.giveWay:
      case LookaheadEventType.mainRoadTurnsRight:
      case LookaheadEventType.mainRoadTurnsLeft:
      case LookaheadEventType.mainRoadReminder:
      case LookaheadEventType.equalIntersection:
        return true;
      case LookaheadEventType.speedLimitChange:
      case LookaheadEventType.trafficCalming:
      case LookaheadEventType.speedCamera:
        return false;
    }
  }

  static int _priorityRank(LookaheadEventType type) {
    switch (type) {
      case LookaheadEventType.trafficLight:
        return 1;
      case LookaheadEventType.stopSign:
        return 2;
      case LookaheadEventType.giveWay:
        return 3;
      case LookaheadEventType.mainRoadTurnsRight:
      case LookaheadEventType.mainRoadTurnsLeft:
        return 4;
      case LookaheadEventType.mainRoadReminder:
        return 5;
      case LookaheadEventType.equalIntersection:
        return 6;
      case LookaheadEventType.speedCamera:
      case LookaheadEventType.speedLimitChange:
      case LookaheadEventType.trafficCalming:
        return 7;
    }
  }

  // --- Helpers ---
  static double _pointToSegmentDistanceSq(double px, double py, double x1, double y1, double x2, double y2) {
    final dx = x2 - x1;
    final dy = y2 - y1;
    final lenSq = dx * dx + dy * dy;
    if (lenSq < 1e-10) {
      final dpx = px - x1;
      final dpy = py - y1;
      return dpx * dpx + dpy * dpy;
    }
    var t = ((px - x1) * dx + (py - y1) * dy) / lenSq;
    if (t < 0.0) t = 0.0;
    if (t > 1.0) t = 1.0;
    final projX = x1 + t * dx;
    final projY = y1 + t * dy;
    final dpx = px - projX;
    final dpy = py - projY;
    return dpx * dpx + dpy * dpy;
  }

  static double _calculateSegmentBearing(double dx, double dy) {
    final rad = atan2(dx, -dy);
    return (rad * 180.0 / pi + 360.0) % 360.0;
  }

  static double _angleDifference(double heading1, double heading2) {
    double diff = (heading1 - heading2).abs() % 180.0;
    if (diff > 90.0) {
      diff = 180.0 - diff;
    }
    return diff;
  }

  static bool _segmentsIntersect(double p0x, double p0y, double p1x, double p1y, double p2x, double p2y, double p3x, double p3y) {
    final s1x = p1x - p0x; final s1y = p1y - p0y;
    final s2x = p3x - p2x; final s2y = p3y - p2y;
    final s = (-s1y * (p0x - p2x) + s1x * (p0y - p2y)) / (-s2x * s1y + s1x * s2y);
    final t = ( s2x * (p0y - p2y) - s2y * (p0x - p2x)) / (-s2x * s1y + s1x * s2y);
    return (s >= 0 && s <= 1 && t >= 0 && t <= 1);
  }
}
