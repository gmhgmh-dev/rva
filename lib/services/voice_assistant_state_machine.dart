import '../models/road_point.dart';
import '../models/voice_alert_event.dart';

/// State Machine that tracks:
/// 1. Speed limit state (currentMaxSpeed & isInReducedSpeedZone)
/// 2. One-way street state (isOneWay)
///
/// Dispatches the exact Latvian voice announcement events according to the specification:
/// - Trigger 1: "Samazināts ātruma ierobežojums: [X] kilometri stundā."
/// - Trigger 2: "Atruma ierobežojuma zona ir beigusies."
/// - Trigger 3: "Jūs atrodaties uz vienvirziena ielas."
/// - Trigger 4: "Vienvirziena iela ir beigusies."
class VoiceAssistantStateMachine {
  int? _currentMaxSpeed;
  bool _isOneWay;
  bool _isInReducedSpeedZone;

  VoiceAssistantStateMachine({
    int? initialMaxSpeed = 50,
    bool initialIsOneWay = false,
  })  : _currentMaxSpeed = initialMaxSpeed,
        _isOneWay = initialIsOneWay,
        _isInReducedSpeedZone = (initialMaxSpeed != null && initialMaxSpeed < 50);

  int? get currentMaxSpeed => _currentMaxSpeed;
  bool get isOneWay => _isOneWay;
  bool get isInReducedSpeedZone => _isInReducedSpeedZone;

  /// Resets state machine to initial values (e.g. at the start of a route)
  void reset({int? initialMaxSpeed = 50, bool initialIsOneWay = false}) {
    _currentMaxSpeed = initialMaxSpeed;
    _isOneWay = initialIsOneWay;
    _isInReducedSpeedZone = (initialMaxSpeed != null && initialMaxSpeed < 50);
  }

  /// Processes a new [RoadPoint] update and returns a list of triggered voice alert events.
  List<VoiceAlertEvent> processRoadPoint(RoadPoint point) {
    return processUpdate(
      newMaxSpeed: point.maxSpeedLimitKmh,
      newIsOneWay: point.isOneWay,
      streetName: point.streetName,
      timestamp: point.timestamp,
    );
  }

  /// Evaluates transitions for speed limit and one-way status.
  List<VoiceAlertEvent> processUpdate({
    required int? newMaxSpeed,
    required bool? newIsOneWay,
    String? streetName,
    DateTime? timestamp,
  }) {
    final now = timestamp ?? DateTime.now();
    final events = <VoiceAlertEvent>[];

    // 1. ĀTRUMA IEROBEŽOJUMA STĀVOKLIS
    if (newMaxSpeed != null) {
      if (newMaxSpeed < 50) {
        // Pāreja no parastās/lielāka ātruma zonas uz samazinātu ātrumu (< 50 km/h)
        // vai jauna samazinātā ātruma vērtība
        final isSpeedChanged = (_currentMaxSpeed != newMaxSpeed);
        if (!_isInReducedSpeedZone || isSpeedChanged) {
          _isInReducedSpeedZone = true;
          _currentMaxSpeed = newMaxSpeed;
          events.add(
            VoiceAlertEvent(
              type: VoiceAlertType.speedReduced,
              spokenText: 'Samazināts ātruma ierobežojums: $newMaxSpeed kilometri stundā.',
              timestamp: now,
              speedLimitKmh: newMaxSpeed,
              isOneWay: _isOneWay,
              streetName: streetName,
            ),
          );
        }
      } else {
        // newMaxSpeed >= 50
        // TRIGERIS 2: Ja atļautais ātrums atkal atgriežas uz 50 km/h vai vairāk (izbraucot no zonām)
        if (_isInReducedSpeedZone) {
          _isInReducedSpeedZone = false;
          _currentMaxSpeed = newMaxSpeed;
          events.add(
            VoiceAlertEvent(
              type: VoiceAlertType.speedZoneEnded,
              spokenText: 'Atruma ierobežojuma zona ir beigusies.',
              timestamp: now,
              speedLimitKmh: newMaxSpeed,
              isOneWay: _isOneWay,
              streetName: streetName,
            ),
          );
        } else {
          _currentMaxSpeed = newMaxSpeed;
        }
      }
    }

    // 2. VIENVIRZIENA IELAS STĀVOKLIS
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

    return events;
  }
}
