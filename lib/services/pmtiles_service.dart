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
    double maxRadiusMeters = 150.0,
  }) async {
    final archive = _archive;
    if (archive == null) {
      return null;
    }

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

      for (final layer in roadLayers) {
        final extent = layer.extent > 0 ? layer.extent : 4096;
        final px = (tileXDouble - tileX) * extent;
        final py = (tileYDouble - tileY) * extent;

        for (final feature in layer.features) {
          if (feature.type != VectorTileGeomType.LINESTRING) continue;

          final lines = feature.decodeLineString();
          double featureMinDistSq = double.infinity;

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
              }
            }
          }

          if (featureMinDistSq < minAnyDistanceSq) {
            minAnyDistanceSq = featureMinDistSq;
            closestAnyFeature = feature;
            extentAny = extent;
          }

          // Check if this feature has an explicit street name
          final props = feature.decodeProperties();
          final hasName = props.containsKey('name') ||
              props.containsKey('name:latin') ||
              props.containsKey('name:lv') ||
              props.containsKey('name:en') ||
              props.containsKey('ref');

          if (hasName && featureMinDistSq < minNamedDistanceSq) {
            minNamedDistanceSq = featureMinDistSq;
            closestNamedFeature = feature;
            extentNamed = extent;
          }
        }
      }

      if (closestAnyFeature == null && closestNamedFeature == null) {
        return null;
      }

      // Check if closest named feature is within maxRadiusMeters
      if (closestNamedFeature != null && minNamedDistanceSq != double.infinity) {
        final metersPerPixelNamed = (cos(rad) * 40075016.686) / (n * extentNamed);
        final distNamedMeters = sqrt(minNamedDistanceSq) * metersPerPixelNamed;

        if (distNamedMeters <= maxRadiusMeters) {
          final props = closestNamedFeature.decodeProperties();
          return _extractRoadAttributes(props, distNamedMeters);
        }
      }

      // Fallback to closest any feature
      if (closestAnyFeature != null && minAnyDistanceSq != double.infinity) {
        final metersPerPixelAny = (cos(rad) * 40075016.686) / (n * extentAny);
        final distAnyMeters = sqrt(minAnyDistanceSq) * metersPerPixelAny;

        if (distAnyMeters <= maxRadiusMeters) {
          final props = closestAnyFeature.decodeProperties();
          return _extractRoadAttributes(props, distAnyMeters);
        }
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

    if (lenSq == 0.0) {
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

    // 3. Parse road class
    final classVal = props['class'] ?? props['highway'];
    if (classVal != null) {
      roadClass = classVal.value.toString();
    }

    // living_street default speed limit is 20 km/h according to Latvian traffic law
    if (roadClass?.toLowerCase() == 'living_street') {
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

    // Meaningful fallback for unnamed residential / yard ways
    if (name == null || name == 'Iela') {
      final cls = roadClass?.toLowerCase();
      if (cls == 'service' || cls == 'parking') {
        name = 'Pagalma brauktuve';
      } else if (cls == 'living_street') {
        name = 'Dzīvojamā zona';
      } else if (cls == 'residential') {
        name = 'Dzīvojamais rajons';
      } else {
        name = 'Pilsētas ceļš';
      }
    }

    return RoadAttributes(
      maxspeed: maxspeed,
      isOneWay: isOneWay,
      name: name,
      distanceMeters: distanceMeters,
      roadClass: roadClass,
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
}
