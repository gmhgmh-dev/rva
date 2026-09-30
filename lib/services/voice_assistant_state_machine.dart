import 'dart:math';
import '../models/lookahead_event.dart';
import '../models/road_point.dart';
import '../models/voice_alert_event.dart';
import 'settings_service.dart';

/// State Machine that tracks:
/// 1. Speed limit state (currentMaxSpeed & isInReducedSpeedZone)
/// 2. Living street state (isInLivingStreetZone, 20 km/h)
/// 3. 30 km/h speed limit zone state (isIn30SpeedZone, 30 km/h)
/// 4. One-way street state (isOneWay)
/// 5. Current street name tracking and dynamic announcements
///
/// Dispatches exact Latvian voice announcement events:
/// - Trigger 1: "Samazināts ātruma ierobežojums: [X] kilometri stundā." (vai dinamiskā frāze)
/// - Trigger 2: "Atruma ierobežojuma zona ir beigusies."
/// - Trigger 3: "Jūs atrodaties uz vienvirziena ielas."
/// - Trigger 4: "Vienvirziena iela ir beigusies."
/// - Trigger 5 (Living zone): "Iebraucāt dzīvojamā zonā. Maksimālais ātrums 20 kilometri stundā."
/// - Trigger 6 (30 zone): "Iebraucāt 30 kilometru stundā ātruma ierobežojuma zonā."
/// - Dynamic street naming: "Atrodaties uz [street_name]. Atļautais ātrums [max_speed] kilometri stundā."
class VoiceAssistantStateMachine {
  int? _currentMaxSpeed;
  bool _isOneWay;
  bool _isInReducedSpeedZone;
  bool _isInLivingStreetZone;
  bool _isIn30SpeedZone;
  bool _isInPedestrianOrBicycleWay;
  bool _isCurrentWayCycleway = false;
  bool _isCurrentWayFootway = false;
  String? _currentStreetName;
  String? _pendingStreetCandidate;
  int _pendingStreetConfirmations = 0;
  double _pendingStreetDistanceMeters = 0.0;
  double? _lastCandidateLat;
  double? _lastCandidateLon;
  int _pendingSpeedRestorationConfirmations = 0;
  int _pendingOneWayExitConfirmations = 0;
  int? _lastLookaheadAlertedLimit;
  DateTime? _lastTrafficCalmingAlertTime;
  DateTime? _lastSpeedCameraAlertTime;
  String? _lastAlertedStreetName;
  
  // Lookahead event tracking to prevent spam
  final Map<LookaheadEventType, DateTime> _lastLookaheadEventTimes = {};
  double? _lastLookaheadEventLat;
  double? _lastLookaheadEventLon;

  bool announceStreetChanges;
  bool useDynamicPhrases;
  VoiceAlertStyle alertStyle;

  VoiceAssistantStateMachine({
    int? initialMaxSpeed = 50,
    bool initialIsOneWay = false,
    String? initialStreetName,
    this.announceStreetChanges = false,
    this.useDynamicPhrases = false,
    this.alertStyle = VoiceAlertStyle.concise,
  })  : _currentMaxSpeed = initialMaxSpeed,
        _isOneWay = initialIsOneWay,
        _currentStreetName = initialStreetName,
        _isInReducedSpeedZone = (initialMaxSpeed != null && initialMaxSpeed < 50),
        _isInLivingStreetZone = (initialMaxSpeed == 20),
        _isIn30SpeedZone = (initialMaxSpeed == 30),
        _isInPedestrianOrBicycleWay = false;

  int? get currentMaxSpeed => _currentMaxSpeed;
  bool get isOneWay => _isOneWay;
  bool get isInReducedSpeedZone => _isInReducedSpeedZone;
  bool get isInLivingStreetZone => _isInLivingStreetZone;
  bool get isIn30SpeedZone => _isIn30SpeedZone;
  bool get isInPedestrianOrBicycleWay => _isInPedestrianOrBicycleWay;
  String? get currentStreetName => _currentStreetName;
  double get pendingStreetDistanceMeters => _pendingStreetDistanceMeters;

  /// Calculates distance in meters between two GPS coordinates using Haversine formula.
  static double calculateDistanceMeters(double lat1, double lon1, double lat2, double lon2) {
    const earthRadius = 6371000.0;
    final dLat = (lat2 - lat1) * (pi / 180.0);
    final dLon = (lon2 - lon1) * (pi / 180.0);
    final lat1Rad = lat1 * (pi / 180.0);
    final lat2Rad = lat2 * (pi / 180.0);

    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1Rad) * cos(lat2Rad) * sin(dLon / 2) * sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  /// Resets state machine to initial values (e.g. at the start of a route)
  void reset({
    int? initialMaxSpeed = 50,
    bool initialIsOneWay = false,
    String? initialStreetName,
  }) {
    _currentMaxSpeed = initialMaxSpeed;
    _isOneWay = initialIsOneWay;
    _currentStreetName = initialStreetName;
    _isInReducedSpeedZone = (initialMaxSpeed != null && initialMaxSpeed < 50);
    _isInLivingStreetZone = (initialMaxSpeed == 20);
    _isIn30SpeedZone = (initialMaxSpeed == 30);
    _isInPedestrianOrBicycleWay = false;
    _pendingStreetCandidate = null;
    _pendingStreetConfirmations = 0;
    _pendingStreetDistanceMeters = 0.0;
    _lastCandidateLat = null;
    _lastCandidateLon = null;
    _pendingSpeedRestorationConfirmations = 0;
    _pendingOneWayExitConfirmations = 0;
    _lastLookaheadAlertedLimit = null;
    _lastTrafficCalmingAlertTime = null;
    _lastSpeedCameraAlertTime = null;
    _lastAlertedStreetName = null;
    _lastLookaheadEventTimes.clear();
    _lastLookaheadEventLat = null;
    _lastLookaheadEventLon = null;
  }

  /// Returns a cleaned street name if valid, or null if unnamed / generic driveway.
  static String? cleanStreetName(String? streetName) {
    if (streetName == null) return null;
    final trimmed = streetName.trim();
    if (trimmed.isEmpty ||
        trimmed == 'Pilsētas ceļš' ||
        trimmed == 'Pagalma brauktuve' ||
        trimmed == 'Dzīvojamā zona' ||
        trimmed == 'Dzīvojamais rajons' ||
        trimmed == 'Iela') {
      return null;
    }
    return trimmed;
  }

  /// Checks if two street names represent the same valid street.
  static bool areSameStreets(String? street1, String? street2) {
    if (street1 == null && street2 == null) return true;
    final s1 = cleanStreetName(street1);
    final s2 = cleanStreetName(street2);
    if (s1 != null && s2 != null) {
      return s1.toLowerCase() == s2.toLowerCase();
    }
    // If one or both are generic / unnamed, compare raw trimmed strings
    return street1?.trim().toLowerCase() == street2?.trim().toLowerCase();
  }

  /// Formats dynamic street and speed limit announcement:
  /// "Atrodaties uz [street_name]. Atļautais ātrums [max_speed] kilometri stundā."
  /// Or "Atrodaties uz neidentificēta ceļa. Atļautais ātrums [max_speed] kilometri stundā."
  static String formatStreetAnnouncement({
    String? streetName,
    required int maxSpeed,
  }) {
    final name = cleanStreetName(streetName);

    if (name != null) {
      return 'Atrodaties uz $name. Atļautais ātrums $maxSpeed kilometri stundā.';
    } else {
      return 'Atrodaties uz neidentificēta ceļa. Atļautais ātrums $maxSpeed kilometri stundā.';
    }
  }

  /// Formats speed reduction announcement.
  /// If on the same street, announces the restriction concisely without repeating the street name:
  /// "Ātruma ierobežojums [maxSpeed] kilometri stundā."
  /// If on a new street, announces the street name and the speed limit:
  /// "Atrodaties uz [streetName]. Atļautais ātrums [maxSpeed] kilometri stundā."
  static String formatSpeedReductionAnnouncement({
    String? streetName,
    required int maxSpeed,
    bool isSameStreet = false,
  }) {
    final validName = cleanStreetName(streetName);
    if (isSameStreet || validName == null) {
      return 'Ātruma ierobežojums $maxSpeed kilometri stundā.';
    } else {
      return 'Atrodaties uz $validName. Atļautais ātrums $maxSpeed kilometri stundā.';
    }
  }

  /// Formats speed restored announcement when returning to standard speed limit (e.g. 50 km/h).
  /// On the same street:
  /// - "Ātruma ierobežojums ir beidzies. [streetName]."
  /// - Or "Ātruma ierobežojums ir beidzies." if unnamed.
  /// On a new street / turn:
  /// - concise: "Ierobežojums beidzies. [streetName]."
  /// - detailed: "Ātruma ierobežojums ir beidzies. Nogriezāties uz [streetName]."
  static String formatSpeedRestoredAnnouncement({
    String? streetName,
    required int maxSpeed,
    bool isSameStreet = true,
    VoiceAlertStyle style = VoiceAlertStyle.concise,
  }) {
    final validName = cleanStreetName(streetName);
    if (isSameStreet || validName == null) {
      if (validName != null) {
        return 'Ātruma ierobežojums ir beidzies. $validName.';
      } else {
        return 'Ātruma ierobežojums ir beidzies.';
      }
    } else {
      if (style == VoiceAlertStyle.concise) {
        return 'Ierobežojums beidzies. $validName.';
      } else {
        return 'Ātruma ierobežojums ir beidzies. Nogriezāties uz $validName.';
      }
    }
  }

  /// Formats speed zone ended announcement (Ceļa zīme 522 "Zonas beigas").
  /// On the same street:
  /// - "Atruma ierobežojuma zona ir beigusies."
  /// On a new street / turn:
  /// - concise: "Atruma ierobežojuma zona ir beigusies. [streetName]."
  /// - detailed: "Atruma ierobežojuma zona ir beigusies. Nogriezāties uz [streetName]."
  static String formatSpeedZoneEndedAnnouncement({
    String? streetName,
    bool isSameStreet = true,
    VoiceAlertStyle style = VoiceAlertStyle.concise,
  }) {
    final validName = cleanStreetName(streetName);
    if (isSameStreet || validName == null) {
      return 'Atruma ierobežojuma zona ir beigusies.';
    } else {
      if (style == VoiceAlertStyle.concise) {
        return 'Atruma ierobežojuma zona ir beigusies. $validName.';
      } else {
        return 'Atruma ierobežojuma zona ir beigusies. Nogriezāties uz $validName.';
      }
    }
  }

  /// Formats one-way entrance announcement for both concise and detailed styles.
  /// On the same street:
  /// - concise: "Vienvirziena posms." (vai "Vienvirziena posms, [maxSpeed] kilometri stundā.")
  /// - detailed: "Sākas vienvirziena posms." (vai "Sākas vienvirziena posms, atļautais ātrums [maxSpeed] kilometri stundā.")
  /// On a new street / turn:
  /// - concise: "[StreetName]. Vienvirziena iela." (vai "[StreetName]. Vienvirziena, [maxSpeed] kilometri stundā.")
  /// - detailed: "Nogriezāties uz [StreetName]. Vienvirziena iela." (vai "Nogriezāties uz [StreetName]. Vienvirziena iela, atļautais ātrums [maxSpeed] kilometri stundā.")
  /// If [speedRestored] is true, prefixes with speed limit end announcement for seamless Smart Fusion.
  static String formatOneWayAnnouncement({
    String? streetName,
    required bool isSameStreet,
    int? maxSpeed,
    bool speedRestored = false,
    VoiceAlertStyle style = VoiceAlertStyle.concise,
  }) {
    final validName = cleanStreetName(streetName);
    final hasReducedSpeed = (maxSpeed != null && maxSpeed < 50);

    String body;
    if (isSameStreet || validName == null) {
      if (style == VoiceAlertStyle.concise) {
        if (hasReducedSpeed) {
          body = 'Vienvirziena posms, $maxSpeed kilometri stundā.';
        } else {
          body = 'Vienvirziena posms.';
        }
      } else {
        if (hasReducedSpeed) {
          body = 'Sākas vienvirziena posms, atļautais ātrums $maxSpeed kilometri stundā.';
        } else {
          body = 'Sākas vienvirziena posms.';
        }
      }
    } else {
      // New street / turn onto one-way street
      if (style == VoiceAlertStyle.concise) {
        if (hasReducedSpeed) {
          body = '$validName. Vienvirziena, $maxSpeed kilometri stundā.';
        } else {
          body = '$validName. Vienvirziena iela.';
        }
      } else {
        if (hasReducedSpeed) {
          body = 'Nogriezāties uz $validName. Vienvirziena iela, atļautais ātrums $maxSpeed kilometri stundā.';
        } else {
          body = 'Nogriezāties uz $validName. Vienvirziena iela.';
        }
      }
    }

    if (speedRestored) {
      final prefix = (style == VoiceAlertStyle.concise)
          ? 'Ierobežojums beidzies. '
          : 'Ātruma ierobežojums ir beidzies. ';
      return '$prefix$body';
    }
    return body;
  }

  /// Formats one-way exit announcement when a one-way segment ends on the same street.
  /// - concise: "Vienvirziena posms ir beidzies. Divvirzienu satiksme."
  /// - detailed: "Vienvirziena posms ir beidzies. Atjaunota divvirzienu satiksme."
  static String formatOneWayExitedAnnouncement({
    String? streetName,
    required bool isSameStreet,
    VoiceAlertStyle style = VoiceAlertStyle.concise,
  }) {
    if (style == VoiceAlertStyle.concise) {
      return 'Vienvirziena posms ir beidzies. Divvirzienu satiksme.';
    } else {
      return 'Vienvirziena posms ir beidzies. Atjaunota divvirzienu satiksme.';
    }
  }

  /// Formats announcement when confirming a turn onto a new street.
  /// In concise mode:
  /// - "[StreetName]." if standard speed (50 km/h)
  /// - "[StreetName], [maxSpeed] kilometri stundā." if reduced speed
  /// In detailed mode:
  /// - "Nogriezāties uz [StreetName]." if standard speed
  /// - "Nogriezāties uz [StreetName], atļautais ātrums [maxSpeed] kilometri stundā." if reduced speed
  static String formatStreetChangeAnnouncement({
    required String streetName,
    required int maxSpeed,
    required VoiceAlertStyle style,
  }) {
    final validName = cleanStreetName(streetName);
    if (validName != null) {
      if (style == VoiceAlertStyle.concise) {
        if (maxSpeed < 50) {
          return '$validName, $maxSpeed kilometri stundā.';
        }
        return '$validName.';
      } else {
        if (maxSpeed < 50) {
          return 'Nogriezāties uz $validName, atļautais ātrums $maxSpeed kilometri stundā.';
        }
        return 'Nogriezāties uz $validName.';
      }
    } else {
      if (style == VoiceAlertStyle.concise) {
        if (maxSpeed < 50) {
          return 'Ātruma ierobežojums $maxSpeed kilometri stundā.';
        }
        return '';
      } else {
        if (maxSpeed < 50) {
          return 'Atrodaties uz neidentificēta ceļa. Atļautais ātrums $maxSpeed kilometri stundā.';
        }
        return 'Atrodaties uz neidentificēta ceļa.';
      }
    }
  }

  /// Formats living street entry announcement:
  /// "Iebraucāt dzīvojamā zonā. Maksimālais ātrums 20 kilometri stundā."
  static String formatLivingStreetAnnouncement() {
    return 'Iebraucāt dzīvojamā zonā. Maksimālais ātrums 20 kilometri stundā.';
  }

  /// Formats speed limit zone entry announcement:
  /// "Iebraucāt 30 kilometru stundā ātruma ierobežojuma zonā."
  static String formatSpeedZoneAnnouncement(int speedLimit) {
    return 'Iebraucāt $speedLimit kilometru stundā ātruma ierobežojuma zonā.';
  }

  /// Formats lookahead lower speed announcement:
  /// "Pēc [distance] metriem ātruma ierobežojums [maxSpeed] kilometri stundā."
  static String formatLookaheadSpeedAnnouncement(int maxSpeed, int distanceMeters) {
    return 'Pēc $distanceMeters metriem ātruma ierobežojums $maxSpeed kilometri stundā.';
  }

  /// Formats traffic calming announcement:
  /// "Uzmanību, priekšā ātrumvalnis."
  static String formatTrafficCalmingAnnouncement([String? type]) {
    return 'Uzmanību, priekšā ātrumvalnis.';
  }

  /// Formats speed camera announcement:
  /// "Priekšā fotoradars, atļautais ātrums [maxSpeed]." or "Uzmanību, priekšā fotoradars."
  static String formatSpeedCameraAnnouncement([int? maxSpeed]) {
    if (maxSpeed != null && maxSpeed > 0) {
      return 'Priekšā fotoradars, atļautais ātrums $maxSpeed kilometri stundā.';
    }
    return 'Uzmanību, priekšā fotoradars.';
  }

  static String formatTrafficLightAnnouncement() {
    return 'Priekšā luksofors.';
  }

  static String formatGiveWayAnnouncement() {
    return 'Priekšā dodiet ceļu.';
  }

  static String formatStopSignAnnouncement() {
    return 'Priekšā stop zīme.';
  }

  static String formatMainRoadReminderAnnouncement() {
    return 'Krustojums. Jūs esat uz galvenā ceļa.';
  }

  static String formatEqualIntersectionAnnouncement() {
    return 'Vienādas nozīmes krustojums. Labās rokas likums.';
  }

  static String formatMainRoadTurnsAnnouncement(bool isRight) {
    return isRight ? 'Uzmanību, galvenais ceļš nogriežas pa labi.' : 'Uzmanību, galvenais ceļš nogriežas pa kreisi.';
  }

  bool _isSpeeding = false;
  DateTime? _lastSpeedingWarningTime;

  /// Processes a new [RoadPoint] update and returns a list of triggered voice alert events.
  List<VoiceAlertEvent> processRoadPoint(
    RoadPoint point, {
    int speedTolerance = 0,
    SpeedToleranceMode toleranceMode = SpeedToleranceMode.fixed,
    double speedTolerancePercentage = 5.0,
    int speedWarningInterval = 10,
    double streetChangeDistanceMeters = 35.0,
    int streetChangeConfirmations = 2,
    int speedRestorationConfirmations = 1,
    int oneWayExitConfirmations = 1,
    bool lookaheadAlertsEnabled = false,
    bool lookaheadTrafficLights = true,
    bool lookaheadGiveWay = true,
    bool lookaheadIntersections = true,
    bool trafficCalmingAlertsEnabled = false,
    bool speedCameraAlertsEnabled = false,
    bool enableSpeedAdaptiveDistance = false,
  }) {
    return processUpdate(
      newMaxSpeed: point.maxSpeedLimitKmh,
      newIsOneWay: point.isOneWay,
      streetName: point.streetName,
      roadClass: point.roadClass,
      isZone: point.isZone,
      isCycleway: point.isCycleway,
      isFootway: point.isFootway,
      isPath: point.isPath,
      timestamp: point.timestamp,
      vehicleSpeedKmh: point.vehicleSpeedKmh,
      latitude: point.latitude,
      longitude: point.longitude,
      speedTolerance: speedTolerance,
      toleranceMode: toleranceMode,
      speedTolerancePercentage: speedTolerancePercentage,
      speedWarningInterval: speedWarningInterval,
      streetChangeDistanceMeters: streetChangeDistanceMeters,
      streetChangeConfirmations: streetChangeConfirmations,
      speedRestorationConfirmations: speedRestorationConfirmations,
      oneWayExitConfirmations: oneWayExitConfirmations,
      lookaheadMaxSpeed: point.lookaheadMaxSpeed,
      lookaheadDistanceMeters: point.lookaheadDistanceMeters,
      lookaheadAlertsEnabled: lookaheadAlertsEnabled,
      hasTrafficCalmingAhead: point.hasTrafficCalmingAhead,
      trafficCalmingAheadType: point.trafficCalmingAheadType,
      trafficCalmingAlertsEnabled: trafficCalmingAlertsEnabled,
      hasSpeedCameraAhead: point.hasSpeedCameraAhead,
      speedCameraLimitAhead: point.speedCameraLimitAhead,
      speedCameraAlertsEnabled: speedCameraAlertsEnabled,
      lookaheadEvents: point.lookaheadEvents,
      lookaheadTrafficLights: lookaheadTrafficLights,
      lookaheadGiveWay: lookaheadGiveWay,
      lookaheadIntersections: lookaheadIntersections,
      enableSpeedAdaptiveDistance: enableSpeedAdaptiveDistance,
    );
  }

  /// Evaluates transitions for speed limit, living zones, one-way status, pedestrian/cycleway, and street changes.
  List<VoiceAlertEvent> processUpdate({
    required int? newMaxSpeed,
    required bool? newIsOneWay,
    String? streetName,
    String? roadClass,
    bool isZone = false,
    bool isCycleway = false,
    bool isFootway = false,
    bool isPath = false,
    DateTime? timestamp,
    double? vehicleSpeedKmh,
    double? latitude,
    double? longitude,
    int speedTolerance = 0,
    SpeedToleranceMode toleranceMode = SpeedToleranceMode.fixed,
    double speedTolerancePercentage = 5.0,
    int speedWarningInterval = 10,
    double streetChangeDistanceMeters = 35.0,
    int streetChangeConfirmations = 2,
    int speedRestorationConfirmations = 1,
    int oneWayExitConfirmations = 1,
    int? lookaheadMaxSpeed,
    double? lookaheadDistanceMeters,
    bool lookaheadAlertsEnabled = false,
    bool lookaheadTrafficLights = true,
    bool lookaheadGiveWay = true,
    bool lookaheadIntersections = true,
    bool hasTrafficCalmingAhead = false,
    String? trafficCalmingAheadType,
    bool trafficCalmingAlertsEnabled = false,
    bool hasSpeedCameraAhead = false,
    int? speedCameraLimitAhead,
    bool speedCameraAlertsEnabled = false,
    List<LookaheadEvent> lookaheadEvents = const [],
    bool enableSpeedAdaptiveDistance = false,
  }) {
    final now = timestamp ?? DateTime.now();
    final events = <VoiceAlertEvent>[];
    final String? normalizedNewStreet = streetName?.trim();
    final String? previousStreetName = _currentStreetName;

    // Determine if road is living street (20 km/h)
    final isLiving = (roadClass?.toLowerCase() == 'living_street') ||
        (newMaxSpeed == 20 && !isCycleway && !isFootway && !isPath) ||
        (streetName?.toLowerCase() == 'dzīvojamā zona');

    final effectiveSpeed = isLiving ? 20 : newMaxSpeed;

    // 0. GĀJĒJU UN VELOSIPĒDU CEĻŠ
    final isPedOrBike = isCycleway ||
        isFootway ||
        isPath ||
        (roadClass?.toLowerCase() == 'cycleway') ||
        (roadClass?.toLowerCase() == 'footway') ||
        (roadClass?.toLowerCase() == 'pedestrian') ||
        (roadClass?.toLowerCase() == 'path') ||
        (streetName?.toLowerCase().contains('velosipēd') ?? false) ||
        (streetName?.toLowerCase().contains('gājēj') ?? false);

    final bool currentIsCycle = isCycleway || (roadClass?.toLowerCase() == 'cycleway') || (streetName?.toLowerCase().contains('velosipēd') ?? false);
    final bool currentIsFoot = isFootway || (roadClass?.toLowerCase() == 'footway') || (streetName?.toLowerCase().contains('gājēj') ?? false);

    if (isPedOrBike) {
      final changedPathType = (currentIsCycle && !_isCurrentWayCycleway) || (currentIsFoot && !_isCurrentWayFootway);
      if (!_isInPedestrianOrBicycleWay || changedPathType) {
        _isInPedestrianOrBicycleWay = true;
        _isCurrentWayCycleway = currentIsCycle;
        _isCurrentWayFootway = currentIsFoot;
        if (normalizedNewStreet != null && normalizedNewStreet.isNotEmpty) {
          _lastAlertedStreetName = cleanStreetName(normalizedNewStreet);
        }
        String text;
        if (currentIsCycle && !currentIsFoot) {
          text = 'Atrodaties uz velosipēdu ceļa.';
        } else if (currentIsFoot && !currentIsCycle) {
          text = 'Atrodaties uz gājēju ceļa.';
        } else {
          text = 'Atrodaties uz gājēju un velosipēdu ceļa.';
        }
        events.add(
          VoiceAlertEvent(
            type: VoiceAlertType.pedestrianOrBicycleWayEntered,
            spokenText: text,
            timestamp: now,
            speedLimitKmh: effectiveSpeed ?? 20,
            isOneWay: false,
            streetName: streetName ?? _currentStreetName,
          ),
        );
      }
    } else if (_isInPedestrianOrBicycleWay) {
      // Izbrauca no gājēju / velo ceļa atpakaļ uz auto brauktuvi
      _isInPedestrianOrBicycleWay = false;
      _isCurrentWayCycleway = false;
      _isCurrentWayFootway = false;
    }

    // 1. DZĪVOJAMĀS ZONAS STĀVOKLIS (20 km/h)
    if (isLiving) {
      if (!_isInLivingStreetZone) {
        _isInLivingStreetZone = true;
        _isInReducedSpeedZone = true;
        _isIn30SpeedZone = false;
        _currentMaxSpeed = 20;
        if (normalizedNewStreet != null && normalizedNewStreet.isNotEmpty) {
          _lastAlertedStreetName = cleanStreetName(normalizedNewStreet);
        }
        events.add(
          VoiceAlertEvent(
            type: VoiceAlertType.livingStreetEntered,
            spokenText: formatLivingStreetAnnouncement(),
            timestamp: now,
            speedLimitKmh: 20,
            isOneWay: newIsOneWay ?? _isOneWay,
            streetName: streetName ?? _currentStreetName,
          ),
        );
      }
    } else if (_isInLivingStreetZone) {
      // Exited living street zone
      _isInLivingStreetZone = false;
      if (effectiveSpeed != null && effectiveSpeed >= 50) {
        _isInReducedSpeedZone = false;
        _currentMaxSpeed = effectiveSpeed;
        events.add(
          VoiceAlertEvent(
            type: VoiceAlertType.speedZoneEnded,
            spokenText: 'Atruma ierobežojuma zona ir beigusies.',
            timestamp: now,
            speedLimitKmh: effectiveSpeed,
            isOneWay: _isOneWay,
            streetName: streetName,
          ),
        );
      }
    }

    // 2. ĀTRUMA IEROBEŽOJUMA STĀVOKLIS
    if (isPedOrBike) {
      _currentMaxSpeed = effectiveSpeed;
      _pendingSpeedRestorationConfirmations = 0;
    } else if (effectiveSpeed != null && !isLiving) {
      if (effectiveSpeed < 50) {
        // Pāreja no parastās/lielāka ātruma zonas uz samazinātu ātrumu (< 50 km/h)
        // vai jauna samazinātā ātruma vērtība
        _pendingSpeedRestorationConfirmations = 0;
        final isSpeedChanged = (_currentMaxSpeed != effectiveSpeed);
        if (!_isInReducedSpeedZone || isSpeedChanged) {
          _isInReducedSpeedZone = true;
          _currentMaxSpeed = effectiveSpeed;

          // Check if entering 30 km/h speed zone (Ceļa zīme 521 "30 ZONA")
          if (isZone && effectiveSpeed == 30) {
            _isIn30SpeedZone = true;
            if (normalizedNewStreet != null && normalizedNewStreet.isNotEmpty) {
              _lastAlertedStreetName = cleanStreetName(normalizedNewStreet);
            }
            events.add(
              VoiceAlertEvent(
                type: VoiceAlertType.speed30ZoneEntered,
                spokenText: formatSpeedZoneAnnouncement(30),
                timestamp: now,
                speedLimitKmh: 30,
                isOneWay: _isOneWay,
                streetName: streetName,
              ),
            );
          } else {
            _isIn30SpeedZone = false;
            final isSame = (previousStreetName == null) || (streetName == null) || areSameStreets(previousStreetName, streetName);
            final spoken = useDynamicPhrases
                ? formatSpeedReductionAnnouncement(
                    streetName: streetName,
                    maxSpeed: effectiveSpeed,
                    isSameStreet: isSame,
                  )
                : 'Samazināts ātruma ierobežojums: $effectiveSpeed kilometri stundā.';
            if (!isSame && normalizedNewStreet != null && normalizedNewStreet.isNotEmpty) {
              _lastAlertedStreetName = cleanStreetName(normalizedNewStreet);
            }
            events.add(
              VoiceAlertEvent(
                type: VoiceAlertType.speedReduced,
                spokenText: spoken,
                timestamp: now,
                speedLimitKmh: effectiveSpeed,
                isOneWay: _isOneWay,
                streetName: streetName,
              ),
            );
          }
        }
      } else {
        // effectiveSpeed >= 50
        // TRIGERIS 2: Ja atļautais ātrums atkal atgriežas uz 50 km/h vai vairāk
        if (_isInReducedSpeedZone || _isIn30SpeedZone) {
          final isSame = (previousStreetName == null) || (streetName == null) || areSameStreets(previousStreetName, streetName);
          if (isSame || !useDynamicPhrases || !announceStreetChanges) {
            _pendingSpeedRestorationConfirmations++;
            if (_pendingSpeedRestorationConfirmations >= speedRestorationConfirmations) {
              final wasInActualZone = _isIn30SpeedZone;
              _isInReducedSpeedZone = false;
              _isIn30SpeedZone = false;
              _pendingSpeedRestorationConfirmations = 0;
              _currentMaxSpeed = effectiveSpeed;

              if (wasInActualZone || !useDynamicPhrases) {
                // Zonas beigas (Ceļa zīme 522 "Zonas beigas") vai klasiskais Trigeris 2
                events.add(
                  VoiceAlertEvent(
                    type: VoiceAlertType.speedZoneEnded,
                    spokenText: 'Atruma ierobežojuma zona ir beigusies.',
                    timestamp: now,
                    speedLimitKmh: effectiveSpeed,
                    isOneWay: _isOneWay,
                    streetName: streetName,
                  ),
                );
              } else {
                // Parasta ielas posma beigas dinamiskajā režīmā (atgriežas 50 km/h uz ielas, nevis zonas beigas)
                final spoken = formatSpeedRestoredAnnouncement(
                  streetName: streetName,
                  maxSpeed: effectiveSpeed,
                  isSameStreet: isSame,
                  style: alertStyle,
                );
                if (streetName != null) {
                  _lastAlertedStreetName = cleanStreetName(streetName);
                }
                events.add(
                  VoiceAlertEvent(
                    type: VoiceAlertType.speedRestored,
                    spokenText: spoken,
                    timestamp: now,
                    speedLimitKmh: effectiveSpeed,
                    isOneWay: _isOneWay,
                    streetName: streetName,
                  ),
                );
              }
            }
          } else {
            // !isSame && useDynamicPhrases && announceStreetChanges:
            // Turning onto a new street.
            // Do NOT emit premature speedRestored alert here before the turn is confirmed by distance!
            // When Section 4 (or Section 3 if one-way) confirms the turn via isDistanceMet,
            // it will perform Smart Fusion:
            // e.g. "Ātruma ierobežojums ir beidzies. Nogriezāties uz [NewStreet]."
          }
        } else {
          _pendingSpeedRestorationConfirmations = 0;
          _currentMaxSpeed = effectiveSpeed;
        }
      }
    }

    final bool isMoving = (vehicleSpeedKmh == null || vehicleSpeedKmh >= 3.5);

    // 3. VIENVIRZIENA IELAS STĀVOKLIS
    // Standstill protection: do not toggle one-way state when stopped at a red light or intersection (< 3.5 km/h)
    if (newIsOneWay != null && (isMoving || _currentStreetName == null)) {
      if (!_isOneWay && newIsOneWay) {
        // TRIGERIS 3: Ja auto no divvirzienu ielas iebrauc vienvirziena ielā (oneway == true)
        _isOneWay = true;
        _pendingOneWayExitConfirmations = 0;

        final isSame = (previousStreetName == null) || (streetName == null) || areSameStreets(previousStreetName, streetName);
        if (useDynamicPhrases) {
          // Smart Fusion: Check if speedReduced was just emitted in Section 2 for this point
          final speedReducedIdx = events.indexWhere((e) => e.type == VoiceAlertType.speedReduced);
          int? fusedSpeed;
          if (speedReducedIdx != -1) {
            fusedSpeed = events[speedReducedIdx].speedLimitKmh;
            events.removeAt(speedReducedIdx); // Fused into one-way announcement!
          } else if (effectiveSpeed != null && effectiveSpeed < 50) {
            fusedSpeed = effectiveSpeed;
          }

          // Check if speed restriction ended upon turning into this one-way street
          final wasInSpeedRestricted = (_isInReducedSpeedZone || _isIn30SpeedZone);
          final bool speedEndedOnTurn = !isSame && wasInSpeedRestricted && (effectiveSpeed ?? 50) >= 50;
          if (speedEndedOnTurn) {
            _isInReducedSpeedZone = false;
            _isIn30SpeedZone = false;
            _pendingSpeedRestorationConfirmations = 0;
            _currentMaxSpeed = effectiveSpeed ?? 50;
          }

          final spoken = formatOneWayAnnouncement(
            streetName: streetName,
            isSameStreet: isSame,
            maxSpeed: fusedSpeed,
            speedRestored: speedEndedOnTurn,
            style: alertStyle,
          );

          if (!isSame && normalizedNewStreet != null && normalizedNewStreet.isNotEmpty) {
            _lastAlertedStreetName = cleanStreetName(normalizedNewStreet);
            _currentStreetName = normalizedNewStreet;
          }

          events.add(
            VoiceAlertEvent(
              type: VoiceAlertType.oneWayEntered,
              spokenText: spoken,
              timestamp: now,
              speedLimitKmh: fusedSpeed ?? _currentMaxSpeed,
              isOneWay: true,
              streetName: streetName,
            ),
          );
        } else {
          events.add(
            VoiceAlertEvent(
              type: VoiceAlertType.oneWayEntered,
              spokenText: 'Jūs atrodaties uz vienvirziena ielas.',
              timestamp: now,
              speedLimitKmh: _currentMaxSpeed,
              isOneWay: true,
              streetName: streetName,
            ),
          );
        }
      } else if (_isOneWay && !newIsOneWay) {
        // TRIGERIS 4: Ja auto izbrauc no vienvirziena ielas atpakaļ divvirzienu ielā (oneway == false)
        _pendingOneWayExitConfirmations++;
        if (_pendingOneWayExitConfirmations >= oneWayExitConfirmations) {
          _isOneWay = false;
          _pendingOneWayExitConfirmations = 0;

          final isSame = areSameStreets(_currentStreetName, streetName);
          if (useDynamicPhrases) {
            if (isSame) {
              final spoken = formatOneWayExitedAnnouncement(
                streetName: streetName,
                isSameStreet: true,
                style: alertStyle,
              );
              events.add(
                VoiceAlertEvent(
                  type: VoiceAlertType.oneWayExited,
                  spokenText: spoken,
                  timestamp: now,
                  speedLimitKmh: _currentMaxSpeed,
                  isOneWay: false,
                  streetName: streetName,
                ),
              );
            }
            // If !isSame, driver turned onto a new two-way street; suppress exit alert
            // as Section 4 will naturally announce the new street!
          } else {
            events.add(
              VoiceAlertEvent(
                type: VoiceAlertType.oneWayExited,
                spokenText: 'Vienvirziena iela ir beigusies.',
                timestamp: now,
                speedLimitKmh: _currentMaxSpeed,
                isOneWay: false,
                streetName: streetName,
              ),
            );
          }
        }
      } else if (_isOneWay && newIsOneWay) {
        _pendingOneWayExitConfirmations = 0;
      }
    }

    // 4. IELAS MAIŅAS STĀVOKLIS (Distance-based metros ar krustojumu pret-spama un stāvēšanas filtru)
    if (normalizedNewStreet != null && normalizedNewStreet.isNotEmpty) {
      if (_currentStreetName == null) {
        // Sākotnējais ielas stāvoklis (bez maiņas paziņojuma)
        _currentStreetName = normalizedNewStreet;
        _pendingStreetCandidate = null;
        _pendingStreetConfirmations = 0;
        _pendingStreetDistanceMeters = 0.0;
        _lastCandidateLat = null;
        _lastCandidateLon = null;
      } else if (!isMoving) {
        // Stāvēšanas filtrs: automašīna/skrejritenis stāv pie luksofora vai krustojumā (< 3.5 km/h).
        // Neļaujam GPS svārstībām nomainīt ielu vai uzkrāt distanci metros.
        _pendingStreetCandidate = null;
        _pendingStreetConfirmations = 0;
        _pendingStreetDistanceMeters = 0.0;
        _lastCandidateLat = null;
        _lastCandidateLon = null;
      } else if (_currentStreetName != normalizedNewStreet) {
        // Pārbaudām, vai nav īslaicīgs kritums uz pagalma brauktuvi, kamēr auto brauc pa galveno ielu
        final bool isDowngradeToDriveway = (normalizedNewStreet == 'Pagalma brauktuve' ||
                normalizedNewStreet == 'Pilsētas ceļš') &&
            (_currentStreetName != 'Pagalma brauktuve' &&
                _currentStreetName != 'Pilsētas ceļš' &&
                _currentStreetName != 'Dzīvojamā zona');

        if (isDowngradeToDriveway && !isLiving) {
          // Ignorējam nejaušu pagalma pievilkšanos, braucot pa reālu ielu
          _pendingStreetCandidate = null;
          _pendingStreetConfirmations = 0;
          _pendingStreetDistanceMeters = 0.0;
          _lastCandidateLat = null;
          _lastCandidateLon = null;
        } else {
          // Ziņotā iela atšķiras no pašreizējās ielas.
          // Lai novērstu šķērsojamo ielu spamu krustojumos:
          // Uzkrājam faktiski nobraukto distanci metros pa jauno ielu.
          if (_pendingStreetCandidate == normalizedNewStreet) {
            _pendingStreetConfirmations++;
            if (latitude != null && longitude != null && _lastCandidateLat != null && _lastCandidateLon != null) {
              final stepDist = calculateDistanceMeters(_lastCandidateLat!, _lastCandidateLon!, latitude, longitude);
              // Aizsargājamies pret teleportācijas kļūdām (> 150m vienā solī)
              if (stepDist > 0 && stepDist < 150.0) {
                _pendingStreetDistanceMeters += stepDist;
              }
            }
          } else {
            _pendingStreetCandidate = normalizedNewStreet;
            _pendingStreetConfirmations = 1;
            _pendingStreetDistanceMeters = 0.0;
          }
          _lastCandidateLat = latitude;
          _lastCandidateLon = longitude;

          // Speed-adaptive confirmation distance:
          // For micromobility / scooters / bicycles / slow maneuvers (<= 25 km/h),
          // when enableSpeedAdaptiveDistance is true, required distance is scaled
          // down to 10..15m and confirmations down to 1..2 points,
          // giving immediate, crisp voice feedback right as the turn is completed.
          final double effectiveMinDistance;
          final int effectiveMinConfirmations;
          if (enableSpeedAdaptiveDistance && vehicleSpeedKmh != null && vehicleSpeedKmh <= 25.0) {
            effectiveMinDistance = (streetChangeDistanceMeters * 0.5).clamp(10.0, 15.0);
            effectiveMinConfirmations = streetChangeConfirmations.clamp(1, 2);
          } else {
            effectiveMinDistance = streetChangeDistanceMeters;
            effectiveMinConfirmations = streetChangeConfirmations;
          }

          // Jaunā iela tiek apstiprināta tikai tad, ja:
          // 1) Ar GPS koordinātām un ieslēgtu distanci: nobraukta distance >= effectiveMinDistance
          //    UN saņemti vismaz effectiveMinConfirmations atsevišķi punkti.
          // 2) Bez koordinātām vai ar distanci <= 0: effectiveMinConfirmations.
          final bool hasCoordsAndDistance = (latitude != null && longitude != null && effectiveMinDistance > 0);
          final bool isDistanceMet = hasCoordsAndDistance
              ? (_pendingStreetDistanceMeters >= effectiveMinDistance && _pendingStreetConfirmations >= effectiveMinConfirmations)
              : (_pendingStreetConfirmations >= effectiveMinConfirmations);

          if (isDistanceMet) {
            // Apstiprināts, ka lietotājs tiešām ir nogriezies uz jauno ielu un nobraucis nepieciešamo distanci!
            _currentStreetName = normalizedNewStreet;
            _pendingStreetCandidate = null;
            _pendingStreetConfirmations = 0;
            _pendingStreetDistanceMeters = 0.0;
            _lastCandidateLat = null;
            _lastCandidateLon = null;

            final bool wasInSpeedRestricted = (_isInReducedSpeedZone || _isIn30SpeedZone);
            final bool wasActualZone = _isIn30SpeedZone;
            final int newLimit = effectiveSpeed ?? _currentMaxSpeed ?? 50;
            final bool isSpeedRestoredByTurn = wasInSpeedRestricted && newLimit >= 50;

            if (isSpeedRestoredByTurn) {
              _isInReducedSpeedZone = false;
              _isIn30SpeedZone = false;
              _pendingSpeedRestorationConfirmations = 0;
              _currentMaxSpeed = newLimit;
            }

            if (announceStreetChanges) {
              final alreadyHasAlert = events.any((e) =>
                  e.type == VoiceAlertType.speed30ZoneEntered ||
                  e.type == VoiceAlertType.livingStreetEntered ||
                  e.type == VoiceAlertType.speedReduced ||
                  e.type == VoiceAlertType.speedRestored ||
                  e.type == VoiceAlertType.speedZoneEnded ||
                  e.type == VoiceAlertType.pedestrianOrBicycleWayEntered ||
                  e.type == VoiceAlertType.oneWayEntered);

              final alreadyAnnouncedThisStreet = (_lastAlertedStreetName != null &&
                  cleanStreetName(_lastAlertedStreetName) == cleanStreetName(normalizedNewStreet));

              if (!alreadyHasAlert && !alreadyAnnouncedThisStreet) {
                _lastAlertedStreetName = cleanStreetName(normalizedNewStreet);
                final String spoken;

                if (isSpeedRestoredByTurn && useDynamicPhrases) {
                  // Smart Fusion: End of speed restriction combined with turn announcement!
                  if (wasActualZone) {
                    spoken = formatSpeedZoneEndedAnnouncement(
                      streetName: normalizedNewStreet,
                      isSameStreet: false,
                      style: alertStyle,
                    );
                  } else {
                    spoken = formatSpeedRestoredAnnouncement(
                      streetName: normalizedNewStreet,
                      maxSpeed: newLimit,
                      isSameStreet: false,
                      style: alertStyle,
                    );
                  }
                } else {
                  spoken = useDynamicPhrases
                      ? formatStreetChangeAnnouncement(
                          streetName: normalizedNewStreet,
                          maxSpeed: newLimit,
                          style: alertStyle,
                        )
                      : formatStreetAnnouncement(
                          streetName: normalizedNewStreet,
                          maxSpeed: newLimit,
                        );
                }

                if (spoken.isNotEmpty) {
                  events.add(
                    VoiceAlertEvent(
                      type: isSpeedRestoredByTurn
                          ? (wasActualZone ? VoiceAlertType.speedZoneEnded : VoiceAlertType.speedRestored)
                          : VoiceAlertType.streetChanged,
                      spokenText: spoken,
                      timestamp: now,
                      speedLimitKmh: newLimit,
                      isOneWay: _isOneWay,
                      streetName: normalizedNewStreet,
                    ),
                  );
                }
              } else {
                _lastAlertedStreetName = cleanStreetName(normalizedNewStreet);
              }
            }
          }
        }
      } else {
        // Lietotājs ir uz tās pašas ielas vai atgriezās atpakaļ pēc krustojuma šķērsošanas
        _pendingStreetCandidate = null;
        _pendingStreetConfirmations = 0;
        _pendingStreetDistanceMeters = 0.0;
        _lastCandidateLat = null;
        _lastCandidateLon = null;
      }
    }

    // 5. ĀTRUMA PĀRSNIEGŠANAS BRĪDINĀJUMS
    if (effectiveSpeed != null && vehicleSpeedKmh != null) {
      final double calculatedTolerance = (toleranceMode == SpeedToleranceMode.percentage)
          ? (effectiveSpeed * (speedTolerancePercentage / 100.0))
          : speedTolerance.toDouble();
      final speedLimitWithTolerance = effectiveSpeed + calculatedTolerance;
      final isCurrentlySpeeding = vehicleSpeedKmh > speedLimitWithTolerance;

      if (isCurrentlySpeeding) {
        final canWarnAgain = _lastSpeedingWarningTime == null ||
            now.difference(_lastSpeedingWarningTime!).inSeconds >= speedWarningInterval;

        if (!_isSpeeding || canWarnAgain) {
          _isSpeeding = true;
          _lastSpeedingWarningTime = now;
          events.add(
            VoiceAlertEvent(
              type: VoiceAlertType.speedingWarning,
              spokenText: 'Jūs pārsniedzat atļauto ātrumu.',
              timestamp: now,
              speedLimitKmh: effectiveSpeed,
              isOneWay: _isOneWay,
              streetName: streetName,
            ),
          );
        }
      } else {
        _isSpeeding = false;
      }
    }

    // 6. APSTEIDZOŠIE BRĪDINĀJUMI (Lookahead)
    if (lookaheadAlertsEnabled && lookaheadMaxSpeed != null && effectiveSpeed != null) {
      // Only alert if upcoming speed limit is LOWER than our current speed limit (e.g. 50 -> 30 or 50 -> 20)
      if (lookaheadMaxSpeed < effectiveSpeed && _lastLookaheadAlertedLimit != lookaheadMaxSpeed) {
        final dist = ((lookaheadDistanceMeters ?? 70.0) / 10.0).round() * 10;
        _lastLookaheadAlertedLimit = lookaheadMaxSpeed;
        events.add(
          VoiceAlertEvent(
            type: VoiceAlertType.lookaheadSpeedReduced,
            spokenText: formatLookaheadSpeedAnnouncement(lookaheadMaxSpeed, dist.clamp(30, 150)),
            timestamp: now,
            speedLimitKmh: lookaheadMaxSpeed,
            isOneWay: newIsOneWay ?? _isOneWay,
            streetName: streetName ?? _currentStreetName,
          ),
        );
      }
    }

    // Reset lookahead alert tracking when vehicle has transitioned to that speed
    if (_lastLookaheadAlertedLimit != null && effectiveSpeed == _lastLookaheadAlertedLimit) {
      _lastLookaheadAlertedLimit = null;
    }

    // 7. ĀTRUMVAĻŅI (Traffic Calming)
    if (trafficCalmingAlertsEnabled && hasTrafficCalmingAhead) {
      final shouldAlert = _lastTrafficCalmingAlertTime == null ||
          now.difference(_lastTrafficCalmingAlertTime!).inSeconds >= 45;
      if (shouldAlert) {
        _lastTrafficCalmingAlertTime = now;
        events.add(
          VoiceAlertEvent(
            type: VoiceAlertType.trafficCalmingAhead,
            spokenText: formatTrafficCalmingAnnouncement(trafficCalmingAheadType),
            timestamp: now,
            speedLimitKmh: effectiveSpeed,
            isOneWay: newIsOneWay ?? _isOneWay,
            streetName: streetName ?? _currentStreetName,
          ),
        );
      }
    }

    // 8. FOTORADARI (Speed Enforcement Camera)
    if (speedCameraAlertsEnabled && hasSpeedCameraAhead) {
      final shouldAlert = _lastSpeedCameraAlertTime == null ||
          now.difference(_lastSpeedCameraAlertTime!).inSeconds >= 60;
      if (shouldAlert) {
        _lastSpeedCameraAlertTime = now;
        events.add(
          VoiceAlertEvent(
            type: VoiceAlertType.speedCameraAhead,
            spokenText: formatSpeedCameraAnnouncement(speedCameraLimitAhead ?? effectiveSpeed),
            timestamp: now,
            speedLimitKmh: speedCameraLimitAhead ?? effectiveSpeed,
            isOneWay: newIsOneWay ?? _isOneWay,
            streetName: streetName ?? _currentStreetName,
          ),
        );
      }
    }

    // 9. JAUNIE LOOKAHEAD EVENTI (Traffic Lights, Give Way, Intersections)
    for (final lookaheadEvent in lookaheadEvents) {
      bool canAnnounce = true;
      if (_lastLookaheadEventTimes.containsKey(lookaheadEvent.type)) {
         final timeSinceLast = now.difference(_lastLookaheadEventTimes[lookaheadEvent.type]!).inSeconds;
         if (timeSinceLast < 45) { // 45 seconds cooldown for same type
             if (_lastLookaheadEventLat != null && _lastLookaheadEventLon != null && latitude != null && longitude != null) {
                 final dist = calculateDistanceMeters(_lastLookaheadEventLat!, _lastLookaheadEventLon!, latitude, longitude);
                 if (dist < 50) { // Same physical intersection basically
                     canAnnounce = false;
                 }
             } else {
                 canAnnounce = false;
             }
         }
      }

      if (canAnnounce) {
          String spoken = '';
          VoiceAlertType vType = VoiceAlertType.trafficLightAhead;
          
          switch (lookaheadEvent.type) {
              case LookaheadEventType.trafficLight:
                  if (!lookaheadTrafficLights) continue;
                  spoken = formatTrafficLightAnnouncement();
                  vType = VoiceAlertType.trafficLightAhead;
                  break;
              case LookaheadEventType.giveWay:
                  if (!lookaheadGiveWay) continue;
                  spoken = formatGiveWayAnnouncement();
                  vType = VoiceAlertType.giveWayAhead;
                  break;
              case LookaheadEventType.stopSign:
                  if (!lookaheadGiveWay) continue;
                  spoken = formatStopSignAnnouncement();
                  vType = VoiceAlertType.giveWayAhead;
                  break;
              case LookaheadEventType.mainRoadReminder:
                  if (!lookaheadIntersections) continue;
                  spoken = formatMainRoadReminderAnnouncement();
                  vType = VoiceAlertType.mainRoadReminder;
                  break;
              case LookaheadEventType.equalIntersection:
                  if (!lookaheadIntersections) continue;
                  spoken = formatEqualIntersectionAnnouncement();
                  vType = VoiceAlertType.equalIntersectionAhead;
                  break;
              case LookaheadEventType.mainRoadTurnsRight:
                  if (!lookaheadIntersections) continue;
                  spoken = formatMainRoadTurnsAnnouncement(true);
                  vType = VoiceAlertType.mainRoadTurns;
                  break;
              case LookaheadEventType.mainRoadTurnsLeft:
                  if (!lookaheadIntersections) continue;
                  spoken = formatMainRoadTurnsAnnouncement(false);
                  vType = VoiceAlertType.mainRoadTurns;
                  break;
              default:
                  continue; 
          }
          
          _lastLookaheadEventTimes[lookaheadEvent.type] = now;
          if (latitude != null) _lastLookaheadEventLat = latitude;
          if (longitude != null) _lastLookaheadEventLon = longitude;

          events.add(VoiceAlertEvent(
             type: vType,
             spokenText: spoken,
             timestamp: now,
             speedLimitKmh: effectiveSpeed,
             isOneWay: _isOneWay,
             streetName: streetName ?? _currentStreetName,
          ));
      }
    }

    return events;
  }
}
