import 'package:flutter_test/flutter_test.dart';
import 'package:rva/models/road_point.dart';
import 'package:rva/models/voice_alert_event.dart';
import 'package:rva/services/voice_assistant_state_machine.dart';

void main() {
  group('Voice Assistant Dynamic Street Naming and Living Zone (v0.2.0) Tests', () {
    late VoiceAssistantStateMachine stateMachine;

    setUp(() {
      stateMachine = VoiceAssistantStateMachine(
        initialMaxSpeed: 50,
        initialIsOneWay: false,
      );
    });

    test('formatStreetAnnouncement formats correctly with valid street name', () {
      final text = VoiceAssistantStateMachine.formatStreetAnnouncement(
        streetName: 'Brīvības iela',
        maxSpeed: 50,
      );
      expect(text, equals('Atrodaties uz Brīvības iela. Atļautais ātrums 50 kilometri stundā.'));
    });

    test('formatStreetAnnouncement falls back to neutral phrase for unnamed or generic driveways', () {
      final textNull = VoiceAssistantStateMachine.formatStreetAnnouncement(
        streetName: null,
        maxSpeed: 30,
      );
      expect(textNull, equals('Atrodaties uz neidentificēta ceļa. Atļautais ātrums 30 kilometri stundā.'));

      final textYard = VoiceAssistantStateMachine.formatStreetAnnouncement(
        streetName: 'Pagalma brauktuve',
        maxSpeed: 20,
      );
      expect(textYard, equals('Atrodaties uz neidentificēta ceļa. Atļautais ātrums 20 kilometri stundā.'));

      final textIela = VoiceAssistantStateMachine.formatStreetAnnouncement(
        streetName: 'Iela',
        maxSpeed: 50,
      );
      expect(textIela, equals('Atrodaties uz neidentificēta ceļa. Atļautais ātrums 50 kilometri stundā.'));
    });

    test('formatLivingStreetAnnouncement returns exact Latvian phrase', () {
      final text = VoiceAssistantStateMachine.formatLivingStreetAnnouncement();
      expect(text, equals('Iebraucāt dzīvojamā zonā. Maksimālais ātrums 20 kilometri stundā.'));
    });

    test('Living street entry triggers VoiceAlertType.livingStreetEntered with 20 km/h limit', () {
      final events = stateMachine.processRoadPoint(
        RoadPoint(
          latitude: 57.395,
          longitude: 21.565,
          vehicleSpeedKmh: 18,
          maxSpeedLimitKmh: 20,
          isOneWay: false,
          streetName: 'Dzīvojamā zona',
          roadClass: 'living_street',
          timestamp: DateTime.now(),
        ),
      );

      expect(events.length, equals(1));
      final alert = events.first;
      expect(alert.type, equals(VoiceAlertType.livingStreetEntered));
      expect(alert.spokenText, equals('Iebraucāt dzīvojamā zonā. Maksimālais ātrums 20 kilometri stundā.'));
      expect(alert.speedLimitKmh, equals(20));
      expect(stateMachine.isInLivingStreetZone, isTrue);
      expect(stateMachine.currentMaxSpeed, equals(20));
    });

    test('Subsequent points inside living zone DO NOT repeat the voice announcement (debounce/threshold)', () {
      // 1. Entry point
      final firstEvents = stateMachine.processRoadPoint(
        RoadPoint(
          latitude: 57.3951,
          longitude: 21.5651,
          vehicleSpeedKmh: 15,
          maxSpeedLimitKmh: 20,
          isOneWay: false,
          streetName: 'Dzīvojamā zona',
          roadClass: 'living_street',
          timestamp: DateTime.now(),
        ),
      );
      expect(firstEvents.length, equals(1));
      expect(firstEvents.first.type, equals(VoiceAlertType.livingStreetEntered));

      // 2. Next point inside living zone
      final secondEvents = stateMachine.processRoadPoint(
        RoadPoint(
          latitude: 57.3953,
          longitude: 21.5653,
          vehicleSpeedKmh: 16,
          maxSpeedLimitKmh: 20,
          isOneWay: false,
          streetName: 'Dzīvojamā zona',
          roadClass: 'living_street',
          timestamp: DateTime.now(),
        ),
      );
      expect(secondEvents, isEmpty, reason: 'Living zone alert must not repeat while staying in the zone');

      // 3. Third point inside living zone
      final thirdEvents = stateMachine.processRoadPoint(
        RoadPoint(
          latitude: 57.3955,
          longitude: 21.5655,
          vehicleSpeedKmh: 14,
          maxSpeedLimitKmh: 20,
          isOneWay: false,
          streetName: 'Dzīvojamā zona',
          roadClass: 'living_street',
          timestamp: DateTime.now(),
        ),
      );
      expect(thirdEvents, isEmpty);
    });

    test('Exiting living zone back to urban road (50 km/h) triggers speedZoneEnded', () {
      // Enter living zone
      stateMachine.processRoadPoint(
        RoadPoint(
          latitude: 57.3951,
          longitude: 21.5651,
          vehicleSpeedKmh: 15,
          maxSpeedLimitKmh: 20,
          isOneWay: false,
          streetName: 'Dzīvojamā zona',
          roadClass: 'living_street',
          timestamp: DateTime.now(),
        ),
      );
      expect(stateMachine.isInLivingStreetZone, isTrue);

      // Exit living zone onto main street (50 km/h)
      final exitEvents = stateMachine.processRoadPoint(
        RoadPoint(
          latitude: 57.3960,
          longitude: 21.5670,
          vehicleSpeedKmh: 42,
          maxSpeedLimitKmh: 50,
          isOneWay: false,
          streetName: 'Lielais prospekts',
          roadClass: 'primary',
          timestamp: DateTime.now(),
        ),
      );

      expect(exitEvents.length, equals(1));
      expect(exitEvents.first.type, equals(VoiceAlertType.speedZoneEnded));
      expect(exitEvents.first.spokenText, equals('Atruma ierobežojuma zona ir beigusies.'));
      expect(stateMachine.isInLivingStreetZone, isFalse);
      expect(stateMachine.currentMaxSpeed, equals(50));
    });

    test('Dynamic street change triggers streetChanged event when announceStreetChanges is true', () {
      final dynamicStateMachine = VoiceAssistantStateMachine(
        initialMaxSpeed: 50,
        initialIsOneWay: false,
        initialStreetName: 'Kuldīgas iela',
        announceStreetChanges: true,
      );

      final events = dynamicStateMachine.processRoadPoint(
        RoadPoint(
          latitude: 57.3970,
          longitude: 21.5680,
          vehicleSpeedKmh: 48,
          maxSpeedLimitKmh: 50,
          isOneWay: false,
          streetName: 'Lielais prospekts',
          timestamp: DateTime.now(),
        ),
      );

      expect(events.length, equals(1));
      expect(events.first.type, equals(VoiceAlertType.streetChanged));
      expect(
        events.first.spokenText,
        equals('Atrodaties uz Lielais prospekts. Atļautais ātrums 50 kilometri stundā.'),
      );
      expect(dynamicStateMachine.currentStreetName, equals('Lielais prospekts'));
    });
  });
}
