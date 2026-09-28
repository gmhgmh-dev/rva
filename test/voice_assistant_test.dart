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

    test('Dynamic street change triggers streetChanged event after 2 confirmations (anti-spam filter)', () {
      final dynamicStateMachine = VoiceAssistantStateMachine(
        initialMaxSpeed: 50,
        initialIsOneWay: false,
        initialStreetName: 'Kuldīgas iela',
        announceStreetChanges: true,
      );

      // Point 1 on Lielais prospekts - candidate registered, anti-spam prevents premature trigger
      final firstPointEvents = dynamicStateMachine.processRoadPoint(
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
      expect(firstPointEvents, isEmpty, reason: 'First point is filtered as potential intersection cross-street');

      // Point 2 on Lielais prospekts - confirmed turn onto new street
      final events = dynamicStateMachine.processRoadPoint(
        RoadPoint(
          latitude: 57.3975,
          longitude: 21.5685,
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

    test('Intersection cross-street spike is filtered out without spamming', () {
      final dynamicStateMachine = VoiceAssistantStateMachine(
        initialMaxSpeed: 50,
        initialIsOneWay: false,
        initialStreetName: 'Kuldīgas iela',
        announceStreetChanges: true,
      );

      // Single cross-street glitch at an intersection (e.g. Ganību iela)
      final crossStreetEvents = dynamicStateMachine.processRoadPoint(
        RoadPoint(
          latitude: 57.3940,
          longitude: 21.5610,
          vehicleSpeedKmh: 45,
          maxSpeedLimitKmh: 50,
          isOneWay: false,
          streetName: 'Ganību iela',
          timestamp: DateTime.now(),
        ),
      );
      expect(crossStreetEvents, isEmpty, reason: 'Single cross-street spike must not spam voice alerts');

      // Continuing on Kuldīgas iela
      final continueEvents = dynamicStateMachine.processRoadPoint(
        RoadPoint(
          latitude: 57.3945,
          longitude: 21.5600,
          vehicleSpeedKmh: 45,
          maxSpeedLimitKmh: 50,
          isOneWay: false,
          streetName: 'Kuldīgas iela',
          timestamp: DateTime.now(),
        ),
      );
      expect(continueEvents, isEmpty);
      expect(dynamicStateMachine.currentStreetName, equals('Kuldīgas iela'));
    });

    test('Bicycle and pedestrian path entry triggers voice announcement and tracks state', () {
      final cycleStateMachine = VoiceAssistantStateMachine(
        initialMaxSpeed: 50,
        initialIsOneWay: false,
        initialStreetName: 'Lielais prospekts',
      );

      // Enter bicycle path
      final bikeEvents = cycleStateMachine.processRoadPoint(
        RoadPoint(
          latitude: 57.3930,
          longitude: 21.5630,
          vehicleSpeedKmh: 18,
          maxSpeedLimitKmh: 20,
          isOneWay: false,
          isCycleway: true,
          streetName: 'Lielais prospekts veloceliņš',
          timestamp: DateTime.now(),
        ),
      );

      expect(bikeEvents.length, equals(1));
      expect(bikeEvents.first.type, equals(VoiceAlertType.pedestrianOrBicycleWayEntered));
      expect(bikeEvents.first.spokenText, equals('Atrodaties uz velosipēdu ceļa.'));
      expect(cycleStateMachine.isInPedestrianOrBicycleWay, isTrue);

      // Subsequent point on bike path does not repeat voice
      final bikeEvents2 = cycleStateMachine.processRoadPoint(
        RoadPoint(
          latitude: 57.3935,
          longitude: 21.5625,
          vehicleSpeedKmh: 19,
          maxSpeedLimitKmh: 20,
          isOneWay: false,
          isCycleway: true,
          streetName: 'Lielais prospekts veloceliņš',
          timestamp: DateTime.now(),
        ),
      );
      expect(bikeEvents2, isEmpty);

      // Enter footway
      final footEvents = cycleStateMachine.processRoadPoint(
        RoadPoint(
          latitude: 57.3940,
          longitude: 21.5620,
          vehicleSpeedKmh: 5,
          maxSpeedLimitKmh: 20,
          isOneWay: false,
          isFootway: true,
          streetName: 'Gājēju celiņš',
          timestamp: DateTime.now(),
        ),
      );
      expect(footEvents.length, equals(1));
      expect(footEvents.first.type, equals(VoiceAlertType.pedestrianOrBicycleWayEntered));
      expect(footEvents.first.spokenText, equals('Atrodaties uz gājēju ceļa.'));
    });

    test('formatSpeedZoneAnnouncement returns exact Latvian phrase for 30 km/h zone', () {
      final text = VoiceAssistantStateMachine.formatSpeedZoneAnnouncement(30);
      expect(text, equals('Iebraucāt 30 kilometru stundā ātruma ierobežojuma zonā.'));
    });

    test('Entering 30 km/h speed zone triggers VoiceAlertType.speed30ZoneEntered', () {
      final events = stateMachine.processRoadPoint(
        RoadPoint(
          latitude: 57.395,
          longitude: 21.565,
          vehicleSpeedKmh: 28,
          maxSpeedLimitKmh: 30,
          isOneWay: false,
          isZone: true,
          streetName: 'Katoļu iela',
          timestamp: DateTime.now(),
        ),
      );

      expect(events.length, equals(1));
      final alert = events.first;
      expect(alert.type, equals(VoiceAlertType.speed30ZoneEntered));
      expect(alert.spokenText, equals('Iebraucāt 30 kilometru stundā ātruma ierobežojuma zonā.'));
      expect(alert.speedLimitKmh, equals(30));
      expect(stateMachine.isIn30SpeedZone, isTrue);
      expect(stateMachine.isInReducedSpeedZone, isTrue);
      expect(stateMachine.currentMaxSpeed, equals(30));
    });

    test('Subsequent points inside 30 km/h zone DO NOT repeat the voice alert (debounce/threshold)', () {
      // 1. First point entering 30 km/h zone
      final firstEvents = stateMachine.processRoadPoint(
        RoadPoint(
          latitude: 57.3951,
          longitude: 21.5651,
          vehicleSpeedKmh: 26,
          maxSpeedLimitKmh: 30,
          isOneWay: false,
          isZone: true,
          streetName: 'Katoļu iela',
          timestamp: DateTime.now(),
        ),
      );
      expect(firstEvents.length, equals(1));
      expect(firstEvents.first.type, equals(VoiceAlertType.speed30ZoneEntered));

      // 2. Second point inside 30 km/h zone
      final secondEvents = stateMachine.processRoadPoint(
        RoadPoint(
          latitude: 57.3953,
          longitude: 21.5653,
          vehicleSpeedKmh: 27,
          maxSpeedLimitKmh: 30,
          isOneWay: false,
          isZone: true,
          streetName: 'Katoļu iela',
          timestamp: DateTime.now(),
        ),
      );
      expect(secondEvents, isEmpty, reason: '30 zone alert must not repeat while remaining in the zone');

      // 3. Third point turning into another street inside the same 30 zone
      final thirdEvents = stateMachine.processRoadPoint(
        RoadPoint(
          latitude: 57.3956,
          longitude: 21.5656,
          vehicleSpeedKmh: 25,
          maxSpeedLimitKmh: 30,
          isOneWay: false,
          isZone: true,
          streetName: 'Rīgas iela',
          timestamp: DateTime.now(),
        ),
      );
      expect(thirdEvents, isEmpty, reason: 'Continuing in 30 zone must stay silent without re-alerting');
    });

    test('Exiting 30 km/h zone back to urban road (50 km/h) triggers speedZoneEnded', () {
      // Enter 30 zone
      stateMachine.processRoadPoint(
        RoadPoint(
          latitude: 57.3951,
          longitude: 21.5651,
          vehicleSpeedKmh: 25,
          maxSpeedLimitKmh: 30,
          isOneWay: false,
          isZone: true,
          streetName: 'Katoļu iela',
          timestamp: DateTime.now(),
        ),
      );
      expect(stateMachine.isIn30SpeedZone, isTrue);

      // Exit 30 zone
      final exitEvents = stateMachine.processRoadPoint(
        RoadPoint(
          latitude: 57.3970,
          longitude: 21.5680,
          vehicleSpeedKmh: 45,
          maxSpeedLimitKmh: 50,
          isOneWay: false,
          isZone: false,
          streetName: 'Lielais prospekts',
          timestamp: DateTime.now(),
        ),
      );

      expect(exitEvents.length, equals(1));
      expect(exitEvents.first.type, equals(VoiceAlertType.speedZoneEnded));
      expect(exitEvents.first.spokenText, equals('Atruma ierobežojuma zona ir beigusies.'));
      expect(stateMachine.isIn30SpeedZone, isFalse);
      expect(stateMachine.currentMaxSpeed, equals(50));
    });

    test('Single 30 km/h section (isZone == false) in dynamic mode announces street & limit on entry and speedRestored on exit', () {
      final dynamicStateMachine = VoiceAssistantStateMachine(
        initialMaxSpeed: 50,
        initialIsOneWay: false,
        initialStreetName: 'Sarkanmuižas dambis',
        announceStreetChanges: true,
        useDynamicPhrases: true,
      );

      // Enter isolated 30 km/h segment (ceļa zīme 323, isZone = false)
      final entryEvents = dynamicStateMachine.processRoadPoint(
        RoadPoint(
          latitude: 57.3925,
          longitude: 21.5730,
          vehicleSpeedKmh: 28,
          maxSpeedLimitKmh: 30,
          isOneWay: false,
          isZone: false,
          streetName: 'Sarkanmuižas dambis',
          timestamp: DateTime.now(),
        ),
      );

      expect(entryEvents.length, equals(1));
      expect(entryEvents.first.type, equals(VoiceAlertType.speedReduced));
      expect(entryEvents.first.spokenText, equals('Atrodaties uz Sarkanmuižas dambis. Atļautais ātrums 30 kilometri stundā.'));
      expect(dynamicStateMachine.isIn30SpeedZone, isFalse);
      expect(dynamicStateMachine.isInReducedSpeedZone, isTrue);

      // Exit isolated 30 km/h segment back to 50 km/h (speedRestored, NOT speedZoneEnded)
      final exitEvents = dynamicStateMachine.processRoadPoint(
        RoadPoint(
          latitude: 57.3936,
          longitude: 21.5695,
          vehicleSpeedKmh: 45,
          maxSpeedLimitKmh: 50,
          isOneWay: false,
          isZone: false,
          streetName: 'Sarkanmuižas dambis',
          timestamp: DateTime.now(),
        ),
      );

      expect(exitEvents.length, equals(1));
      expect(exitEvents.first.type, equals(VoiceAlertType.speedRestored));
      expect(exitEvents.first.spokenText, equals('Atrodaties uz Sarkanmuižas dambis. Atļautais ātrums 50 kilometri stundā.'));
      expect(dynamicStateMachine.isIn30SpeedZone, isFalse);
      expect(dynamicStateMachine.isInReducedSpeedZone, isFalse);
      expect(dynamicStateMachine.currentMaxSpeed, equals(50));
    });
  });
}
