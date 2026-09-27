import '../models/road_point.dart';
import '../models/voice_alert_event.dart';

/// State Machine that tracks:
/// 1. Speed limit state (currentMaxSpeed & isInReducedSpeedZone)
/// 2. Living street state (isInLivingStreetZone, 20 km/h)
/// 3. One-way street state (isOneWay)
/// 4. Current street name tracking and dynamic announcements
///
/// Dispatches exact Latvian voice announcement events:
/// - Trigger 1: "Samazināts ātruma ierobežojums: [X] kilometri stundā." (vai dinamiskā frāze)
/// - Trigger 2: "Atruma ierobežojuma zona ir beigusies."
/// - Trigger 3: "Jūs atrodaties uz vienvirziena ielas."
/// - Trigger 4: "Vienvirziena iela ir beigusies."
/// - Trigger 5 (Living zone): "Iebraucāt dzīvojamā zonā. Maksimālais ātrums 20 kilometri stundā."
/// - Dynamic street naming: "Atrodaties uz [street_name]. Atļautais ātrums [max_speed] kilometri stundā."
class VoiceAssistantStateMachine {
  int? _currentMaxSpeed;
  bool _isOneWay;
  bool _isInReducedSpeedZone;
  bool _isInLivingStreetZone;
  String? _currentStreetName;
  final bool announceStreetChanges;
  final bool useDynamicPhrases;

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
        _isInLivingStreetZone = (initialMaxSpeed == 20);

  int? get currentMaxSpeed => _currentMaxSpeed;
  bool get isOneWay => _isOneWay;
  bool get isInReducedSpeedZone => _isInReducedSpeedZone;
  bool get isInLivingStreetZone => _isInLivingStreetZone;
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

  /// Processes a new [RoadPoint] update and returns a list of triggered voice alert events.
  List<VoiceAlertEvent> processRoadPoint(RoadPoint point) {
    return processUpdate(
      newMaxSpeed: point.maxSpeedLimitKmh,
      newIsOneWay: point.isOneWay,
      streetName: point.streetName,
      roadClass: point.roadClass,
      timestamp: point.timestamp,
    );
  }

  /// Evaluates transitions for speed limit, living zones, and one-way status.
  List<VoiceAlertEvent> processUpdate({
    required int? newMaxSpeed,
    required bool? newIsOneWay,
    String? streetName,
    String? roadClass,
    DateTime? timestamp,
  }) {
    final now = timestamp ?? DateTime.now();
    final events = <VoiceAlertEvent>[];

    // Determine if road is living street (20 km/h)
    final isLiving = (roadClass?.toLowerCase() == 'living_street') ||
        (newMaxSpeed == 20) ||
        (streetName?.toLowerCase() == 'dzīvojamā zona');

    final effectiveSpeed = isLiving ? 20 : newMaxSpeed;

    // 1. DZĪVOJAMĀS ZONAS STĀVOKLIS (20 km/h)
    if (isLiving) {
      if (!_isInLivingStreetZone) {
        _isInLivingStreetZone = true;
        _isInReducedSpeedZone = true;
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
    }

    // 2. ĀTRUMA IEROBEŽOJUMA STĀVOKLIS
    if (effectiveSpeed != null && !isLiving) {
      if (effectiveSpeed < 50) {
        // Pāreja no parastās/lielāka ātruma zonas uz samazinātu ātrumu (< 50 km/h)
        // vai jauna samazinātā ātruma vērtība
        final isSpeedChanged = (_currentMaxSpeed != effectiveSpeed);
        if (!_isInReducedSpeedZone || isSpeedChanged) {
          _isInReducedSpeedZone = true;
          _currentMaxSpeed = effectiveSpeed;
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
      } else {
        // effectiveSpeed >= 50
        // TRIGERIS 2: Ja atļautais ātrums atkal atgriežas uz 50 km/h vai vairāk (izbraucot no zonām)
        if (_isInReducedSpeedZone) {
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
        } else {
          _currentMaxSpeed = effectiveSpeed;
        }
      }
    }

    // 3. VIENVIRZIENA IELAS STĀVOKLIS
    if (newIsOneWay != null) {
      if (!_isOneWay && newIsOneWay) {
        // TRIGERIS 3: Ja auto no divvirzienu ielas iebrauc vienvirziena ielā (oneway == true)
        _isOneWay = true;
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
        _isOneWay = false;
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

    // 4. IELAS MAIŅAS STĀVOKLIS
    if (streetName != null && streetName.trim().isNotEmpty) {
      final normalizedNewStreet = streetName.trim();
      final isChanged = _currentStreetName != null && _currentStreetName != normalizedNewStreet;
      if (isChanged && announceStreetChanges) {
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
      _currentStreetName = normalizedNewStreet;
    }

    return events;
  }
}
