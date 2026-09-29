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
  int _pendingSpeedRestorationConfirmations = 0;
  int _pendingOneWayExitConfirmations = 0;
  int? _lastLookaheadAlertedLimit;
  DateTime? _lastTrafficCalmingAlertTime;
  DateTime? _lastSpeedCameraAlertTime;
  bool announceStreetChanges;
  bool useDynamicPhrases;

  VoiceAssistantStateMachine({
    int? initialMaxSpeed = 50,
    bool initialIsOneWay = false,
    String? initialStreetName,
    this.announceStreetChanges = false,
    this.useDynamicPhrases = false,
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
    _pendingSpeedRestorationConfirmations = 0;
    _pendingOneWayExitConfirmations = 0;
    _lastLookaheadAlertedLimit = null;
    _lastTrafficCalmingAlertTime = null;
    _lastSpeedCameraAlertTime = null;
  }

  /// Formats dynamic street and speed limit announcement:
  /// "Atrodaties uz [street_name]. Atļautais ātrums [max_speed] kilometri stundā."
  /// Or "Atrodaties uz neidentificēta ceļa. Atļautais ātrums [max_speed] kilometri stundā."
  static String formatStreetAnnouncement({
    String? streetName,
    required int maxSpeed,
  }) {
    final name = (streetName != null &&
            streetName.trim().isNotEmpty &&
            streetName.trim() != 'Pilsētas ceļš' &&
            streetName.trim() != 'Pagalma brauktuve' &&
            streetName.trim() != 'Dzīvojamā zona' &&
            streetName.trim() != 'Dzīvojamais rajons' &&
            streetName.trim() != 'Iela')
        ? streetName.trim()
        : null;

    if (name != null) {
      return 'Atrodaties uz $name. Atļautais ātrums $maxSpeed kilometri stundā.';
    } else {
      return 'Atrodaties uz neidentificēta ceļa. Atļautais ātrums $maxSpeed kilometri stundā.';
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

  bool _isSpeeding = false;
  DateTime? _lastSpeedingWarningTime;

  /// Processes a new [RoadPoint] update and returns a list of triggered voice alert events.
  List<VoiceAlertEvent> processRoadPoint(
    RoadPoint point, {
    int speedTolerance = 0,
    SpeedToleranceMode toleranceMode = SpeedToleranceMode.fixed,
    double speedTolerancePercentage = 5.0,
    int speedWarningInterval = 10,
    int streetChangeConfirmations = 2,
    int speedRestorationConfirmations = 1,
    int oneWayExitConfirmations = 1,
    bool lookaheadAlertsEnabled = false,
    bool trafficCalmingAlertsEnabled = false,
    bool speedCameraAlertsEnabled = false,
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
      speedTolerance: speedTolerance,
      toleranceMode: toleranceMode,
      speedTolerancePercentage: speedTolerancePercentage,
      speedWarningInterval: speedWarningInterval,
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
    int speedTolerance = 0,
    SpeedToleranceMode toleranceMode = SpeedToleranceMode.fixed,
    double speedTolerancePercentage = 5.0,
    int speedWarningInterval = 10,
    int streetChangeConfirmations = 2,
    int speedRestorationConfirmations = 1,
    int oneWayExitConfirmations = 1,
    int? lookaheadMaxSpeed,
    double? lookaheadDistanceMeters,
    bool lookaheadAlertsEnabled = false,
    bool hasTrafficCalmingAhead = false,
    String? trafficCalmingAheadType,
    bool trafficCalmingAlertsEnabled = false,
    bool hasSpeedCameraAhead = false,
    int? speedCameraLimitAhead,
    bool speedCameraAlertsEnabled = false,
  }) {
    final now = timestamp ?? DateTime.now();
    final events = <VoiceAlertEvent>[];

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
            final spoken = useDynamicPhrases
                ? formatStreetAnnouncement(streetName: streetName, maxSpeed: effectiveSpeed)
                : 'Samazināts ātruma ierobežojums: $effectiveSpeed kilometri stundā.';
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
              final spoken = formatStreetAnnouncement(streetName: streetName, maxSpeed: effectiveSpeed);
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
          _pendingSpeedRestorationConfirmations = 0;
          _currentMaxSpeed = effectiveSpeed;
        }
      }
    }

    final bool isMoving = (vehicleSpeedKmh == null || vehicleSpeedKmh >= 3.5);
    final String? normalizedNewStreet = streetName?.trim();

    // 3. VIENVIRZIENA IELAS STĀVOKLIS
    // Standstill protection: do not toggle one-way state when stopped at a red light or intersection (< 3.5 km/h)
    if (newIsOneWay != null && (isMoving || _currentStreetName == null)) {
      if (!_isOneWay && newIsOneWay) {
        // TRIGERIS 3: Ja auto no divvirzienu ielas iebrauc vienvirziena ielā (oneway == true)
        _isOneWay = true;
        _pendingOneWayExitConfirmations = 0;
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
      } else if (_isOneWay && !newIsOneWay) {
        // TRIGERIS 4: Ja auto izbrauc no vienvirziena ielas atpakaļ divvirzienu ielā (oneway == false)
        _pendingOneWayExitConfirmations++;
        if (_pendingOneWayExitConfirmations >= oneWayExitConfirmations) {
          _isOneWay = false;
          _pendingOneWayExitConfirmations = 0;
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
      } else if (_isOneWay && newIsOneWay) {
        _pendingOneWayExitConfirmations = 0;
      }
    }

    // 4. IELAS MAIŅAS STĀVOKLIS (ar krustojumu pret-spama un stāvēšanas filtru)
    if (normalizedNewStreet != null && normalizedNewStreet.isNotEmpty) {
      if (_currentStreetName == null) {
        // Sākotnējais ielas stāvoklis (bez maiņas paziņojuma)
        _currentStreetName = normalizedNewStreet;
        _pendingStreetCandidate = null;
        _pendingStreetConfirmations = 0;
      } else if (!isMoving) {
        // Stāvēšanas filtrs: automašīna stāv pie luksofora vai krustojumā (< 3.5 km/h).
        // Neļaujam GPS svārstībām nomainīt ielu vai uzkrāt kandidātu apstiprinājumus.
        _pendingStreetCandidate = null;
        _pendingStreetConfirmations = 0;
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
        } else {
          // Ziņotā iela atšķiras no pašreizējās ielas.
          // Lai novērstu šķērsojamo ielu spamu krustojumos, kur GPS uz 1 sekundi pieskaras šķērsielai:
          // Jaunā iela tiek apstiprināta tikai tad, ja tā novērota vismaz streetChangeConfirmations secīgus atjauninājumus.
          if (_pendingStreetCandidate == normalizedNewStreet) {
            _pendingStreetConfirmations++;
          } else {
            _pendingStreetCandidate = normalizedNewStreet;
            _pendingStreetConfirmations = 1;
          }

          if (_pendingStreetConfirmations >= streetChangeConfirmations) {
            // Apstiprināts, ka lietotājs tiešām ir nogriezies uz jauno ielu!
            _currentStreetName = normalizedNewStreet;
            _pendingStreetCandidate = null;
            _pendingStreetConfirmations = 0;

            if (announceStreetChanges) {
              final alreadyHasAlert = events.any((e) =>
                  e.type == VoiceAlertType.speed30ZoneEntered ||
                  e.type == VoiceAlertType.livingStreetEntered ||
                  e.type == VoiceAlertType.speedReduced ||
                  e.type == VoiceAlertType.speedRestored ||
                  e.type == VoiceAlertType.pedestrianOrBicycleWayEntered);

              if (!alreadyHasAlert) {
                events.add(
                  VoiceAlertEvent(
                    type: VoiceAlertType.streetChanged,
                    spokenText: formatStreetAnnouncement(
                      streetName: normalizedNewStreet,
                      maxSpeed: effectiveSpeed ?? _currentMaxSpeed ?? 50,
                    ),
                    timestamp: now,
                    speedLimitKmh: effectiveSpeed ?? _currentMaxSpeed ?? 50,
                    isOneWay: _isOneWay,
                    streetName: normalizedNewStreet,
                  ),
                );
              }
            }
          }
        }
      } else {
        // Lietotājs ir uz tās pašas ielas vai atgriezās atpakaļ pēc krustojuma šķērsošanas
        _pendingStreetCandidate = null;
        _pendingStreetConfirmations = 0;
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

    return events;
  }
}
