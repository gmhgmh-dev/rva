import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:pmtiles/pmtiles.dart';
import 'package:vector_tile/vector_tile.dart';
import '../models/road_attributes.dart';

/// Local PMTiles service for querying vector map tiles offline.
/// Reads local latvia.pmtiles and extracts road attributes (maxspeed, oneway, name)
/// for given GPS coordinates.
class PMTilesService {
  PmTilesArchive? _archive;
  File? _loadedFile;

  bool get isLoaded => _archive != null;
  File? get loadedFile => _loadedFile;
  int? get minZoom => _archive?.minZoom;
  int? get maxZoom => _archive?.maxZoom;

  /// Opens a local PMTiles archive file.
  Future<void> openArchive(File file) async {
    await close();
    _archive = await PmTilesArchive.fromFile(file);
    _loadedFile = file;
    debugPrint('PMTiles archive loaded: ${file.path} (Zoom: ${_archive?.minZoom}..${_archive?.maxZoom})');
  }

  /// Injects an existing archive (useful for tests or custom loaders).
  void setArchive(PmTilesArchive archive, [File? file]) {
    _archive = archive;
    _loadedFile = file;
  }

  /// Closes the currently opened archive.
  Future<void> close() async {
    try {
      await _archive?.close();
    } catch (_) {}
    _archive = null;
    _loadedFile = null;
  }

  /// Queries the vector road layer at ([lat], [lon]) and returns attributes of the nearest road.
  /// Searches for features in 'transportation' / 'road' / 'roads' layers within [maxRadiusMeters].
  Future<RoadAttributes?> getRoadAttributes(
    double lat,
    double lon, {
    int? targetZoom,
    double? maxRadiusMeters,
    double? courtyardRadiusMeters,
    String? currentRoadName,
    double? vehicleHeading,
    double? vehicleSpeedKmh,
    bool prioritizePedestrianAndCycleways = false,
  }) async {
    final archive = _archive;
    if (archive == null) {
      return null;
    }

    final effectiveMaxRadius = maxRadiusMeters ?? 40.0;
    final effectiveCourtyardRadius = courtyardRadiusMeters ?? 15.0;

    // Default zoom level 14 is the standard resolution for road geometries in vector basemaps
    final defaultZoom = (targetZoom ?? 14);
    final z = defaultZoom.clamp(archive.minZoom, archive.maxZoom);
    final n = 1 << z;

    // Web Mercator projection calculations
    final tileXDouble = (lon + 180.0) / 360.0 * n;
    final tileX = tileXDouble.floor().clamp(0, n - 1);

    final rad = lat * pi / 180.0;
    final sinLat = sin(rad).clamp(-0.9999, 0.9999);
    final tileYDouble = (1.0 - 0.5 * log((1.0 + sinLat) / (1.0 - sinLat)) / pi) / 2.0 * n;
    final tileY = tileYDouble.floor().clamp(0, n - 1);

    final tileId = ZXY(z, tileX, tileY).toTileId();

    try {
      final entry = await archive.lookup(tileId);
      if (entry == null) {
        return null;
      }

      final tile = await archive.tile(tileId);
      final tileBytes = Uint8List.fromList(tile.bytes());
      final vectorTile = VectorTile.fromBytes(bytes: tileBytes);

      // Collect all road-related layers (geometry + names)
      final roadLayers = vectorTile.layers.where((layer) {
        final nameLower = layer.name.toLowerCase();
        return nameLower == 'transportation' ||
            nameLower == 'transportation_name' ||
            nameLower == 'road' ||
            nameLower == 'roads';
      }).toList();

      if (roadLayers.isEmpty) {
        return null;
      }

      double minAnyDistanceSq = double.infinity;
      VectorTileFeature? closestAnyFeature;
      int extentAny = 4096;

      double minNamedDistanceSq = double.infinity;
      VectorTileFeature? closestNamedFeature;
      int extentNamed = 4096;

      double minLivingDistanceSq = double.infinity;
      VectorTileFeature? closestLivingFeature;
      int extentLiving = 4096;

      double minPedCycleDistanceSq = double.infinity;
      VectorTileFeature? closestPedCycleFeature;
      int extentPedCycle = 4096;

      final normalizedCurrentRoad = currentRoadName?.trim().toLowerCase();

      for (final layer in roadLayers) {
        final extent = layer.extent > 0 ? layer.extent : 4096;
        final px = (tileXDouble - tileX) * extent;
        final py = (tileYDouble - tileY) * extent;

        for (final feature in layer.features) {
          if (feature.type != VectorTileGeomType.LINESTRING) continue;

          final lines = feature.decodeLineString();
          double featureMinDistSq = double.infinity;
          double bestSegmentBearing = 0.0;

          for (final line in lines) {
            for (var i = 0; i < line.length - 1; i++) {
              final p1 = line[i];
              final p2 = line[i + 1];

              final distSq = _pointToSegmentDistanceSq(
                px,
                py,
                p1[0].toDouble(),
                p1[1].toDouble(),
                p2[0].toDouble(),
                p2[1].toDouble(),
              );

              if (distSq < featureMinDistSq) {
                featureMinDistSq = distSq;
                final dx = p2[0].toDouble() - p1[0].toDouble();
                final dy = p2[1].toDouble() - p1[1].toDouble();
                bestSegmentBearing = _calculateSegmentBearing(dx, dy);
              }
            }
          }

          if (featureMinDistSq < minAnyDistanceSq) {
            minAnyDistanceSq = featureMinDistSq;
            closestAnyFeature = feature;
            extentAny = extent;
          }

          final props = feature.decodeProperties();

          // Check if this feature is a pedestrian path or cycleway
          final rawClass = (props['class']?.value ?? props['highway']?.value)?.toString().toLowerCase() ?? '';
          final rawSubclass = props['subclass']?.value?.toString().toLowerCase() ?? '';
          final rawHighway = props['highway']?.value?.toString().toLowerCase() ?? '';
          final bicycleTag = props['bicycle']?.value?.toString().toLowerCase() ?? '';
          final footTag = props['foot']?.value?.toString().toLowerCase() ?? '';

          final bool isPedOrCycle = rawClass == 'cycleway' ||
              rawSubclass == 'cycleway' ||
              rawHighway == 'cycleway' ||
              rawClass == 'footway' ||
              rawSubclass == 'footway' ||
              rawHighway == 'footway' ||
              rawClass == 'pedestrian' ||
              rawHighway == 'pedestrian' ||
              rawClass == 'path' ||
              rawSubclass == 'path' ||
              rawHighway == 'path' ||
              bicycleTag == 'designated' ||
              bicycleTag == 'yes' ||
              footTag == 'designated';

          if (isPedOrCycle && featureMinDistSq < minPedCycleDistanceSq) {
            minPedCycleDistanceSq = featureMinDistSq;
            closestPedCycleFeature = feature;
            extentPedCycle = extent;
          }

          // Check if this feature is a living street (20 km/h)
          final isLiving = rawClass == 'living_street';
          if (isLiving && featureMinDistSq < minLivingDistanceSq) {
            minLivingDistanceSq = featureMinDistSq;
            closestLivingFeature = feature;
            extentLiving = extent;
          }

          // Check if this feature has an explicit street name
          final hasName = props.containsKey('name') ||
              props.containsKey('name:latin') ||
              props.containsKey('name:lv') ||
              props.containsKey('name:en') ||
              props.containsKey('ref');

          // Directional angle check: if the vehicle is actively moving (> 5 km/h),
          // compare vehicle heading with this road segment's orientation.
          double headingPenalty = 1.0;
          if (vehicleHeading != null && vehicleSpeedKmh != null && vehicleSpeedKmh > 5.0) {
            final angleDiff = _angleDifference(vehicleHeading, bestSegmentBearing);
            if (angleDiff > 55.0) {
              // Perpendicular cross-street! Penalize heavily unless already on this street
              headingPenalty = 8.0;
            } else if (angleDiff < 30.0) {
              // Vehicle heading closely aligns with this road segment
              headingPenalty = 0.6;
            }
          }

          final fName = (props['name'] ?? props['name:lv'] ?? props['name:latin'])?.value.toString().trim().toLowerCase();
          final isCurrentRoad = normalizedCurrentRoad != null && fName != null && fName == normalizedCurrentRoad;

          // Sticky bias at intersections: if this feature is the current road,
          // give it strong affinity advantage to avoid flickering to perpendicular cross-streets.
          double effectiveDistSq = featureMinDistSq;
          if (isCurrentRoad) {
            effectiveDistSq = featureMinDistSq * 0.20; // Strong current road affinity
          } else {
            effectiveDistSq = featureMinDistSq * headingPenalty;
          }

          if (hasName && effectiveDistSq < minNamedDistanceSq) {
            minNamedDistanceSq = effectiveDistSq;
            closestNamedFeature = feature;
            extentNamed = extent;
          }
        }
      }

      if (closestAnyFeature == null &&
          closestNamedFeature == null &&
          closestLivingFeature == null &&
          closestPedCycleFeature == null) {
        return null;
      }

      // 0. High Priority for Pedestrian / Cycleway when enabled (e.g. e-scooter or bicycle ride):
      if (prioritizePedestrianAndCycleways && closestPedCycleFeature != null && minPedCycleDistanceSq != double.infinity) {
        final metersPerPixelPedCycle = (cos(rad) * 40075016.686) / (n * extentPedCycle);
        final distPedCycleMeters = sqrt(minPedCycleDistanceSq) * metersPerPixelPedCycle;

        if (distPedCycleMeters <= effectiveCourtyardRadius || distPedCycleMeters <= 20.0) {
          final props = closestPedCycleFeature.decodeProperties();
          return _extractRoadAttributes(props, distPedCycleMeters);
        }
      }

      // Calculate distances for named and any features
      double distNamedMeters = double.infinity;
      if (closestNamedFeature != null && minNamedDistanceSq != double.infinity) {
        final metersPerPixelNamed = (cos(rad) * 40075016.686) / (n * extentNamed);
        distNamedMeters = sqrt(minNamedDistanceSq) * metersPerPixelNamed;
      }

      double distAnyMeters = double.infinity;
      if (closestAnyFeature != null && minAnyDistanceSq != double.infinity) {
        final metersPerPixelAny = (cos(rad) * 40075016.686) / (n * extentAny);
        distAnyMeters = sqrt(minAnyDistanceSq) * metersPerPixelAny;
      }

      // If the vehicle is currently on an established named road (primary/secondary/tertiary/residential)
      // and still within reasonable distance (<= 25m), do NOT snap into an adjacent courtyard driveway!
      final bool onEstablishedNamedRoad = normalizedCurrentRoad != null &&
          normalizedCurrentRoad.isNotEmpty &&
          normalizedCurrentRoad != 'dzīvojamā zona' &&
          normalizedCurrentRoad != 'pagalma brauktuve' &&
          normalizedCurrentRoad != 'pilsētas ceļš';

      // 1. High Priority: If within courtyardSearchRadius of a living street (20 km/h), prioritize it!
      // But only if not already driving along an established named road within 20m.
      if (closestLivingFeature != null && minLivingDistanceSq != double.infinity) {
        final metersPerPixelLiving = (cos(rad) * 40075016.686) / (n * extentLiving);
        final distLivingMeters = sqrt(minLivingDistanceSq) * metersPerPixelLiving;

        if (distLivingMeters <= effectiveCourtyardRadius) {
          if (!onEstablishedNamedRoad || distNamedMeters > 20.0) {
            final props = closestLivingFeature.decodeProperties();
            return _extractRoadAttributes(props, distLivingMeters);
          }
        }
      }

      // 2. If the vehicle is within courtyardSearchRadius to a courtyard driveway or residential way,
      // and the closest named road is significantly further away (> 25m), stay on the courtyard/service way.
      if (distAnyMeters <= effectiveCourtyardRadius && distNamedMeters > 25.0 && closestAnyFeature != null) {
        if (!onEstablishedNamedRoad || distNamedMeters > 25.0) {
          final props = closestAnyFeature.decodeProperties();
          return _extractRoadAttributes(props, distAnyMeters);
        }
      }

      // 3. Otherwise, check if closest named feature is within roadSearchRadius
      if (distNamedMeters <= effectiveMaxRadius && closestNamedFeature != null) {
        final props = closestNamedFeature.decodeProperties();
        return _extractRoadAttributes(props, distNamedMeters);
      }

      // 4. Fallback to closest any feature within roadSearchRadius
      if (distAnyMeters <= effectiveMaxRadius && closestAnyFeature != null) {
        final props = closestAnyFeature.decodeProperties();
        return _extractRoadAttributes(props, distAnyMeters);
      }

      return null;
    } catch (e, st) {
      debugPrint('PMTiles lookup error at ($lat, $lon): $e\n$st');
      return null;
    }
  }

  /// Calculates squared Euclidean distance from point (px, py) to line segment (x1, y1)-(x2, y2).
  static double _pointToSegmentDistanceSq(
    double px,
    double py,
    double x1,
    double y1,
    double x2,
    double y2,
  ) {
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

  /// Extracts maxspeed, oneway, name and roadClass from feature property map.
  RoadAttributes _extractRoadAttributes(
    Map<String, VectorTileValue> props,
    double distanceMeters,
  ) {
    int? maxspeed;
    bool isOneWay = false;
    String? name;
    String? roadClass;

    // 1. Parse maxspeed
    final speedVal = props['maxspeed'] ??
        props['zone:maxspeed'] ??
        props['source:maxspeed'] ??
        props['maxspeed:forward'] ??
        props['maxspeed:backward'];
    if (speedVal != null) {
      maxspeed = _parseIntValue(speedVal.value);
    }

    // 2. Parse oneway
    final onewayVal = props['oneway'];
    if (onewayVal != null) {
      isOneWay = _parseBoolOrOneWay(onewayVal.value);
    }

    // 3. Parse road class & detect pedestrian / cycleway
    final classVal = props['class'] ?? props['highway'];
    if (classVal != null) {
      roadClass = classVal.value.toString();
    }

    final rawClass = roadClass?.toLowerCase() ?? '';
    final rawSubclass = props['subclass']?.value.toString().toLowerCase() ?? '';
    final rawHighway = props['highway']?.value.toString().toLowerCase() ?? '';
    final bicycleTag = props['bicycle']?.value.toString().toLowerCase() ?? '';
    final footTag = props['foot']?.value.toString().toLowerCase() ?? '';

    final bool isCycleway = rawClass == 'cycleway' ||
        rawSubclass == 'cycleway' ||
        rawHighway == 'cycleway' ||
        bicycleTag == 'designated' ||
        bicycleTag == 'yes';

    final bool isFootway = rawClass == 'footway' ||
        rawSubclass == 'footway' ||
        rawHighway == 'footway' ||
        rawClass == 'pedestrian' ||
        rawHighway == 'pedestrian' ||
        footTag == 'designated';

    final bool isPath = rawClass == 'path' || rawSubclass == 'path' || rawHighway == 'path';

    // living_street default speed limit is 20 km/h according to Latvian traffic law
    if (rawClass == 'living_street') {
      maxspeed ??= 20;
    }

    // Default speed limit for pedestrian/bicycle paths
    if (isCycleway || isFootway || isPath) {
      maxspeed ??= 20;
    }

    // 4. Parse road name
    final nameVal = props['name'] ??
        props['name:latin'] ??
        props['name:lv'] ??
        props['name:en'] ??
        props['ref'];
    if (nameVal != null) {
      final str = nameVal.value.toString().trim();
      if (str.isNotEmpty && str.toLowerCase() != 'null') {
        name = str;
      }
    }

    // Meaningful fallback for unnamed ways
    if (name == null || name == 'Iela') {
      if (isCycleway && !isFootway) {
        name = 'Velosipēdu ceļš';
      } else if (isFootway && !isCycleway) {
        name = 'Gājēju ceļš';
      } else if (isPath || (isCycleway && isFootway)) {
        name = 'Gājēju un velosipēdu ceļš';
      } else if (rawClass == 'service' || rawClass == 'parking') {
        name = 'Pagalma brauktuve';
      } else if (rawClass == 'living_street') {
        name = 'Dzīvojamā zona';
      } else if (rawClass == 'residential') {
        name = 'Dzīvojamais rajons';
      } else {
        name = 'Pilsētas ceļš';
      }
    }

    // Detect if road is marked as part of a traffic speed zone
    final isZone = props['zone:maxspeed'] != null ||
        props['zone:traffic'] != null ||
        (props['source:maxspeed']?.value.toString().toLowerCase().contains('zone') ?? false) ||
        (speedVal?.value.toString().toLowerCase().contains('zone') ?? false);

    return RoadAttributes(
      maxspeed: maxspeed,
      isOneWay: isOneWay,
      name: name,
      distanceMeters: distanceMeters,
      roadClass: roadClass,
      isZone: isZone,
      isCycleway: isCycleway,
      isFootway: isFootway,
      isPath: isPath,
    );
  }

  static int? _parseIntValue(Object value) {
    if (value is int) return value;
    final str = value.toString().trim();
    if (str == 'LV:urban' || str == 'urban') return 50;
    if (str == 'LV:rural' || str == 'rural') return 90;
    if (str == 'LV:living_street' || str == 'living_street') return 20;
    if (str == 'LV:zone30' || str == 'zone30') return 30;

    // Sometimes values are formatted as "50", "90 km/h", etc.
    final match = RegExp(r'\d+').firstMatch(str);
    if (match != null) {
      return int.tryParse(match.group(0)!);
    }
    return null;
  }

  static bool _parseBoolOrOneWay(Object value) {
    if (value is bool) return value;
    if (value is int) return value == 1 || value == -1;
    final str = value.toString().trim().toLowerCase();
    return str == 'yes' || str == '1' || str == 'true' || str == '-1';
  }

  @visibleForTesting
  static int? parseIntValue(Object value) => _parseIntValue(value);

  @visibleForTesting
  RoadAttributes extractRoadAttributesForTesting(
    Map<String, VectorTileValue> props,
    double distanceMeters,
  ) =>
      _extractRoadAttributes(props, distanceMeters);

  /// Calculates navigation bearing in degrees [0, 360) for a vector line segment.
  /// In tile coordinates: dx positive East, dy positive South.
  /// Bearing: 0 deg North, 90 deg East, 180 deg South, 270 deg West.
  static double _calculateSegmentBearing(double dx, double dy) {
    final rad = atan2(dx, -dy);
    return (rad * 180.0 / pi + 360.0) % 360.0;
  }

  /// Calculates undirected angle difference in degrees [0, 90] between two bearings.
  static double _angleDifference(double heading1, double heading2) {
    double diff = (heading1 - heading2).abs() % 180.0;
    if (diff > 90.0) {
      diff = 180.0 - diff;
    }
    return diff;
  }

  @visibleForTesting
  static double calculateSegmentBearing(double dx, double dy) => _calculateSegmentBearing(dx, dy);

  @visibleForTesting
  static double angleDifference(double heading1, double heading2) => _angleDifference(heading1, heading2);
}
