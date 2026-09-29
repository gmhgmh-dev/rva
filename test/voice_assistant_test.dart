import 'package:flutter_test/flutter_test.dart';
import 'package:rva/models/road_point.dart';
import 'package:rva/models/voice_alert_event.dart';
import 'package:rva/services/voice_assistant_state_machine.dart';
import 'package:rva/services/settings_service.dart';

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

    test('Single 30 km/h section (isZone == false) on SAME street in dynamic mode announces concise restriction on entry and street on exit', () {
      final dynamicStateMachine = VoiceAssistantStateMachine(
        initialMaxSpeed: 50,
        initialIsOneWay: false,
        initialStreetName: 'Sarkanmuižas dambis',
        announceStreetChanges: true,
        useDynamicPhrases: true,
      );

      // Enter isolated 30 km/h segment on SAME street (ceļa zīme 323, isZone = false)
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
      // Concise Latvian announcement without repeating street name when already on that street
      expect(entryEvents.first.spokenText, equals('Ātruma ierobežojums 30 kilometri stundā.'));
      expect(dynamicStateMachine.isIn30SpeedZone, isFalse);
      expect(dynamicStateMachine.isInReducedSpeedZone, isTrue);

      // Exit isolated 30 km/h segment back to 50 km/h on same street (speedRestored, NOT speedZoneEnded)
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
      // Concise exit announcement stating restriction ended followed by street name
      expect(exitEvents.first.spokenText, equals('Ātruma ierobežojums ir beidzies. Sarkanmuižas dambis.'));
      expect(dynamicStateMachine.isIn30SpeedZone, isFalse);
      expect(dynamicStateMachine.isInReducedSpeedZone, isFalse);
      expect(dynamicStateMachine.currentMaxSpeed, equals(50));
    });

    test('Speed reduction when turning onto a NEW street in dynamic mode announces street and limit', () {
      final dynamicStateMachine = VoiceAssistantStateMachine(
        initialMaxSpeed: 50,
        initialIsOneWay: false,
        initialStreetName: 'Lielais prospekts',
        announceStreetChanges: true,
        useDynamicPhrases: true,
      );

      // Turning onto a new street (Kuldīgas iela) with 30 km/h limit
      final entryEvents = dynamicStateMachine.processRoadPoint(
        RoadPoint(
          latitude: 57.3925,
          longitude: 21.5730,
          vehicleSpeedKmh: 25,
          maxSpeedLimitKmh: 30,
          isOneWay: false,
          isZone: false,
          streetName: 'Kuldīgas iela',
          timestamp: DateTime.now(),
        ),
      );

      expect(entryEvents.length, equals(1));
      expect(entryEvents.first.type, equals(VoiceAlertType.speedReduced));
      // Full announcement because driver entered a new street
      expect(entryEvents.first.spokenText, equals('Atrodaties uz Kuldīgas iela. Atļautais ātrums 30 kilometri stundā.'));
    });

    test('Speed reduction on unnamed driveway or generic road announces restriction without verbose fallback', () {
      final dynamicStateMachine = VoiceAssistantStateMachine(
        initialMaxSpeed: 50,
        initialIsOneWay: false,
        initialStreetName: null,
        announceStreetChanges: true,
        useDynamicPhrases: true,
      );

      // Speed reduction on unnamed road
      final entryEvents = dynamicStateMachine.processRoadPoint(
        RoadPoint(
          latitude: 57.3925,
          longitude: 21.5730,
          vehicleSpeedKmh: 20,
          maxSpeedLimitKmh: 30,
          isOneWay: false,
          isZone: false,
          streetName: 'Pilsētas ceļš',
          timestamp: DateTime.now(),
        ),
      );

      expect(entryEvents.length, equals(1));
      expect(entryEvents.first.type, equals(VoiceAlertType.speedReduced));
      expect(entryEvents.first.spokenText, equals('Ātruma ierobežojums 30 kilometri stundā.'));

      // Speed restored on unnamed road
      final exitEvents = dynamicStateMachine.processRoadPoint(
        RoadPoint(
          latitude: 57.3930,
          longitude: 21.5740,
          vehicleSpeedKmh: 48,
          maxSpeedLimitKmh: 50,
          isOneWay: false,
          isZone: false,
          streetName: 'Pilsētas ceļš',
          timestamp: DateTime.now(),
        ),
      );

      expect(exitEvents.length, equals(1));
      expect(exitEvents.first.type, equals(VoiceAlertType.speedRestored));
      expect(exitEvents.first.spokenText, equals('Ātruma ierobežojums ir beidzies.'));
    });

    test('Progressive percentage speed tolerance warns at +1 km/h for 20 km/h, and +4.5 km/h for 90 km/h', () {
      final tolStateMachine = VoiceAssistantStateMachine(
        initialMaxSpeed: 20,
        initialIsOneWay: false,
        initialStreetName: 'Pagalms',
      );

      // In 20 km/h living street with 5% tolerance: threshold = 20 + (20 * 0.05) = 21.0 km/h
      // Driving 20.9 km/h -> NOT speeding
      var events = tolStateMachine.processRoadPoint(
        RoadPoint(
          latitude: 57.3900,
          longitude: 21.5600,
          vehicleSpeedKmh: 20.9,
          maxSpeedLimitKmh: 20,
          isOneWay: false,
          streetName: 'Pagalms',
          timestamp: DateTime.now(),
        ),
        toleranceMode: SpeedToleranceMode.percentage,
        speedTolerancePercentage: 5.0,
      );
      expect(events.where((e) => e.type == VoiceAlertType.speedingWarning), isEmpty);

      // Driving 21.2 km/h (> 21.0 km/h) -> triggers speeding warning at 1st km over!
      events = tolStateMachine.processRoadPoint(
        RoadPoint(
          latitude: 57.3901,
          longitude: 21.5601,
          vehicleSpeedKmh: 21.2,
          maxSpeedLimitKmh: 20,
          isOneWay: false,
          streetName: 'Pagalms',
          timestamp: DateTime.now(),
        ),
        toleranceMode: SpeedToleranceMode.percentage,
        speedTolerancePercentage: 5.0,
      );
      expect(events.where((e) => e.type == VoiceAlertType.speedingWarning), isNotEmpty);

      // On 90 km/h road with 5% tolerance: threshold = 90 + (90 * 0.05) = 94.5 km/h
      final highwayStateMachine = VoiceAssistantStateMachine(
        initialMaxSpeed: 90,
        initialIsOneWay: false,
        initialStreetName: 'Ventspils šoseja',
      );

      // Driving 94.0 km/h -> NOT speeding (since 94.0 <= 94.5)
      events = highwayStateMachine.processRoadPoint(
        RoadPoint(
          latitude: 57.3900,
          longitude: 21.5600,
          vehicleSpeedKmh: 94.0,
          maxSpeedLimitKmh: 90,
          isOneWay: false,
          streetName: 'Ventspils šoseja',
          timestamp: DateTime.now(),
        ),
        toleranceMode: SpeedToleranceMode.percentage,
        speedTolerancePercentage: 5.0,
      );
      expect(events.where((e) => e.type == VoiceAlertType.speedingWarning), isEmpty);

      // Driving 95.0 km/h (> 94.5 km/h) -> triggers speeding warning
      events = highwayStateMachine.processRoadPoint(
        RoadPoint(
          latitude: 57.3901,
          longitude: 21.5601,
          vehicleSpeedKmh: 95.0,
          maxSpeedLimitKmh: 90,
          isOneWay: false,
          streetName: 'Ventspils šoseja',
          timestamp: DateTime.now(),
        ),
        toleranceMode: SpeedToleranceMode.percentage,
        speedTolerancePercentage: 5.0,
      );
      expect(events.where((e) => e.type == VoiceAlertType.speedingWarning), isNotEmpty);
    });

    test('Static speed tolerance behaves according to fixed km/h offset', () {
      final staticStateMachine = VoiceAssistantStateMachine(
        initialMaxSpeed: 50,
        initialIsOneWay: false,
        initialStreetName: 'Kuldīgas iela',
      );

      // With static tolerance = 5 km/h: threshold = 55.0 km/h
      // Driving 54.5 km/h -> NOT speeding
      var events = staticStateMachine.processRoadPoint(
        RoadPoint(
          latitude: 57.3900,
          longitude: 21.5600,
          vehicleSpeedKmh: 54.5,
          maxSpeedLimitKmh: 50,
          isOneWay: false,
          streetName: 'Kuldīgas iela',
          timestamp: DateTime.now(),
        ),
        toleranceMode: SpeedToleranceMode.fixed,
        speedTolerance: 5,
      );
      expect(events.where((e) => e.type == VoiceAlertType.speedingWarning), isEmpty);

      // Driving 56.0 km/h -> triggers speeding warning
      events = staticStateMachine.processRoadPoint(
        RoadPoint(
          latitude: 57.3901,
          longitude: 21.5601,
          vehicleSpeedKmh: 56.0,
          maxSpeedLimitKmh: 50,
          isOneWay: false,
          streetName: 'Kuldīgas iela',
          timestamp: DateTime.now(),
        ),
        toleranceMode: SpeedToleranceMode.fixed,
        speedTolerance: 5,
      );
      expect(events.where((e) => e.type == VoiceAlertType.speedingWarning), isNotEmpty);
    });

    test('Standstill filter at traffic lights (< 3.5 km/h) prevents street switching and false one-way alerts', () {
      final stateMachine = VoiceAssistantStateMachine(
        initialMaxSpeed: 50,
        initialIsOneWay: false,
        initialStreetName: 'Jūras iela',
        announceStreetChanges: true,
      );

      // Stopped at red light at Kuldīgas iela intersection (speed = 0.5 km/h)
      // GPS drifts and reports Kuldīgas iela with isOneWay = true
      for (var i = 0; i < 5; i++) {
        final events = stateMachine.processRoadPoint(
          RoadPoint(
            latitude: 57.3945,
            longitude: 21.5645,
            vehicleSpeedKmh: 0.5,
            maxSpeedLimitKmh: 50,
            isOneWay: true,
            streetName: 'Kuldīgas iela',
            timestamp: DateTime.now().add(Duration(seconds: i)),
          ),
        );

        // No street changed, no one-way entered because speed < 3.5 km/h
        expect(events, isEmpty, reason: 'Standstill filter must freeze alerts while stopped at traffic light');
        expect(stateMachine.currentStreetName, equals('Jūras iela'));
        expect(stateMachine.isOneWay, isFalse);
      }
    });

    test('Courtyard driveway downgrade is ignored when driving along an established named street', () {
      final stateMachine = VoiceAssistantStateMachine(
        initialMaxSpeed: 50,
        initialIsOneWay: false,
        initialStreetName: 'Jūras iela',
        announceStreetChanges: true,
      );

      // Moving along Jūras iela at 20 km/h, GPS passes adjacent courtyard driveway (Pagalma brauktuve)
      for (var i = 0; i < 3; i++) {
        final events = stateMachine.processRoadPoint(
          RoadPoint(
            latitude: 57.3948,
            longitude: 21.5650,
            vehicleSpeedKmh: 20.0,
            maxSpeedLimitKmh: 50,
            isOneWay: false,
            streetName: 'Pagalma brauktuve',
            timestamp: DateTime.now().add(Duration(seconds: i)),
          ),
        );

        // Downgrade ignored: remains on Jūras iela
        expect(events.where((e) => e.type == VoiceAlertType.streetChanged), isEmpty);
        expect(stateMachine.currentStreetName, equals('Jūras iela'));
      }
    });

    test('Custom streetChangeConfirmations (4 points) prevents intersection cross-street spam', () {
      final stateMachine = VoiceAssistantStateMachine(
        initialMaxSpeed: 50,
        initialIsOneWay: false,
        initialStreetName: 'Kārļa iela',
        announceStreetChanges: true,
      );

      // Points 1, 2, 3 on Ganību iela (traveling 22m, below 35m threshold and below 4 confirmations)
      for (var i = 1; i <= 3; i++) {
        final events = stateMachine.processRoadPoint(
          RoadPoint(
            latitude: 57.3940 + (i - 1) * 0.0001,
            longitude: 21.5640,
            vehicleSpeedKmh: 20.0,
            maxSpeedLimitKmh: 50,
            isOneWay: false,
            streetName: 'Ganību iela',
            timestamp: DateTime.now().add(Duration(seconds: i)),
          ),
          streetChangeConfirmations: 4,
        );

        expect(events.where((e) => e.type == VoiceAlertType.streetChanged), isEmpty,
            reason: 'Points 1..3 must NOT trigger streetChanged when threshold is 4');
        expect(stateMachine.currentStreetName, equals('Kārļa iela'));
      }

      // Point 4: 4th consecutive point reaches 44m (> 35m) and confirms turn into Ganību iela
      final finalEvents = stateMachine.processRoadPoint(
        RoadPoint(
          latitude: 57.3944,
          longitude: 21.5640,
          vehicleSpeedKmh: 20.0,
          maxSpeedLimitKmh: 50,
          isOneWay: false,
          streetName: 'Ganību iela',
          timestamp: DateTime.now().add(const Duration(seconds: 4)),
        ),
        streetChangeConfirmations: 4,
      );

      expect(finalEvents.where((e) => e.type == VoiceAlertType.streetChanged).length, equals(1));
      expect(stateMachine.currentStreetName, equals('Ganību iela'));
    });

    test('Custom speedRestorationConfirmations (4 points) prevents 50 km/h flickering', () {
      final stateMachine = VoiceAssistantStateMachine(
        initialMaxSpeed: 30,
        initialIsOneWay: false,
        initialStreetName: 'Sarkanmuižas dambis',
        useDynamicPhrases: true,
      );

      // Enter 30 zone
      stateMachine.processRoadPoint(
        RoadPoint(
          latitude: 57.3920,
          longitude: 21.5730,
          vehicleSpeedKmh: 25.0,
          maxSpeedLimitKmh: 30,
          isOneWay: false,
          isZone: true,
          streetName: 'Sarkanmuižas dambis',
          timestamp: DateTime.now(),
        ),
      );
      expect(stateMachine.isIn30SpeedZone, isTrue);

      // 3 brief GPS points reporting 50 km/h (e.g. crossing an unmapped node)
      for (var i = 1; i <= 3; i++) {
        final events = stateMachine.processRoadPoint(
          RoadPoint(
            latitude: 57.3925,
            longitude: 21.5735,
            vehicleSpeedKmh: 25.0,
            maxSpeedLimitKmh: 50,
            isOneWay: false,
            isZone: false,
            streetName: 'Sarkanmuižas dambis',
            timestamp: DateTime.now().add(Duration(seconds: i)),
          ),
          speedRestorationConfirmations: 4,
        );

        expect(events.where((e) => e.type == VoiceAlertType.speedZoneEnded || e.type == VoiceAlertType.speedRestored), isEmpty,
            reason: '3 points must not restore speed when threshold is 4');
        expect(stateMachine.isIn30SpeedZone, isTrue);
      }

      // Point 4: 4th point at 50 km/h confirms exit of speed zone
      final finalEvents = stateMachine.processRoadPoint(
        RoadPoint(
          latitude: 57.3930,
          longitude: 21.5740,
          vehicleSpeedKmh: 45.0,
          maxSpeedLimitKmh: 50,
          isOneWay: false,
          isZone: false,
          streetName: 'Sarkanmuižas dambis',
          timestamp: DateTime.now().add(const Duration(seconds: 4)),
        ),
        speedRestorationConfirmations: 4,
      );

      expect(finalEvents.where((e) => e.type == VoiceAlertType.speedZoneEnded).length, equals(1));
      expect(stateMachine.isIn30SpeedZone, isFalse);
    });

    test('Custom oneWayExitConfirmations (3 points) debounces exit from one-way street', () {
      final stateMachine = VoiceAssistantStateMachine(
        initialMaxSpeed: 50,
        initialIsOneWay: true,
        initialStreetName: 'Kārļa iela',
      );

      // Points 1 and 2: momentary isOneWay = false at an intersection
      for (var i = 1; i <= 2; i++) {
        final events = stateMachine.processRoadPoint(
          RoadPoint(
            latitude: 57.3950,
            longitude: 21.5640,
            vehicleSpeedKmh: 20.0,
            maxSpeedLimitKmh: 50,
            isOneWay: false,
            streetName: 'Kārļa iela',
            timestamp: DateTime.now().add(Duration(seconds: i)),
          ),
          oneWayExitConfirmations: 3,
        );

        expect(events.where((e) => e.type == VoiceAlertType.oneWayExited), isEmpty);
        expect(stateMachine.isOneWay, isTrue);
      }

      // Point 3: confirms real exit
      final finalEvents = stateMachine.processRoadPoint(
        RoadPoint(
          latitude: 57.3955,
          longitude: 21.5640,
          vehicleSpeedKmh: 20.0,
          maxSpeedLimitKmh: 50,
          isOneWay: false,
          streetName: 'Kārļa iela',
          timestamp: DateTime.now().add(const Duration(seconds: 3)),
        ),
        oneWayExitConfirmations: 3,
      );

      expect(finalEvents.where((e) => e.type == VoiceAlertType.oneWayExited).length, equals(1));
      expect(stateMachine.isOneWay, isFalse);
    });

    test('E-scooter crossing an intersection (15m along cross-street) does NOT trigger street change', () {
      final stateMachine = VoiceAssistantStateMachine(
        initialMaxSpeed: 50,
        initialIsOneWay: false,
        initialStreetName: 'Jūras iela',
        announceStreetChanges: true,
      );

      // Rider travels across Saules iela intersection for 3 seconds (~15m traveled)
      // Lat moves 0.00014 deg (~15.5 meters)
      final p1 = stateMachine.processRoadPoint(
        RoadPoint(
          latitude: 57.39800,
          longitude: 21.56500,
          vehicleSpeedKmh: 18.0,
          maxSpeedLimitKmh: 50,
          isOneWay: false,
          streetName: 'Saules iela',
          timestamp: DateTime.now(),
        ),
        streetChangeDistanceMeters: 35.0,
      );
      expect(p1.where((e) => e.type == VoiceAlertType.streetChanged), isEmpty);
      expect(stateMachine.currentStreetName, equals('Jūras iela'));

      final p2 = stateMachine.processRoadPoint(
        RoadPoint(
          latitude: 57.39814,
          longitude: 21.56500,
          vehicleSpeedKmh: 18.0,
          maxSpeedLimitKmh: 50,
          isOneWay: false,
          streetName: 'Saules iela',
          timestamp: DateTime.now().add(const Duration(seconds: 3)),
        ),
        streetChangeDistanceMeters: 35.0,
      );
      // Even after 2 points on Saules iela, only 15.5m covered (< 35m) -> NO ALERT!
      expect(p2.where((e) => e.type == VoiceAlertType.streetChanged), isEmpty);
      expect(stateMachine.currentStreetName, equals('Jūras iela'));
      expect(stateMachine.pendingStreetDistanceMeters, closeTo(15.5, 1.0));

      // Next point returns to Jūras iela
      final p3 = stateMachine.processRoadPoint(
        RoadPoint(
          latitude: 57.39830,
          longitude: 21.56500,
          vehicleSpeedKmh: 18.0,
          maxSpeedLimitKmh: 50,
          isOneWay: false,
          streetName: 'Jūras iela',
          timestamp: DateTime.now().add(const Duration(seconds: 5)),
        ),
        streetChangeDistanceMeters: 35.0,
      );
      // Candidate reset to 0m and current street remains Jūras iela
      expect(p3.where((e) => e.type == VoiceAlertType.streetChanged), isEmpty);
      expect(stateMachine.currentStreetName, equals('Jūras iela'));
      expect(stateMachine.pendingStreetDistanceMeters, equals(0.0));
    });

    test('E-scooter turning into new street and traveling > 35m confirms street change', () {
      final stateMachine = VoiceAssistantStateMachine(
        initialMaxSpeed: 50,
        initialIsOneWay: false,
        initialStreetName: 'Jūras iela',
        announceStreetChanges: true,
      );

      // Point 1: Enters Saules iela
      final p1 = stateMachine.processRoadPoint(
        RoadPoint(
          latitude: 57.39800,
          longitude: 21.56500,
          vehicleSpeedKmh: 18.0,
          maxSpeedLimitKmh: 50,
          isOneWay: false,
          streetName: 'Saules iela',
          timestamp: DateTime.now(),
        ),
        streetChangeDistanceMeters: 35.0,
      );
      expect(p1.where((e) => e.type == VoiceAlertType.streetChanged), isEmpty);

      // Point 2: Rides 40m down Saules iela (0.00036 deg lat = 40.0m)
      final p2 = stateMachine.processRoadPoint(
        RoadPoint(
          latitude: 57.39836,
          longitude: 21.56500,
          vehicleSpeedKmh: 18.0,
          maxSpeedLimitKmh: 50,
          isOneWay: false,
          streetName: 'Saules iela',
          timestamp: DateTime.now().add(const Duration(seconds: 8)),
        ),
        streetChangeDistanceMeters: 35.0,
      );
      // Confirmed! Traveled 40m >= 35m threshold
      final changeEvents = p2.where((e) => e.type == VoiceAlertType.streetChanged).toList();
      expect(changeEvents.length, equals(1));
      expect(changeEvents.first.spokenText, contains('Saules iela'));
      expect(stateMachine.currentStreetName, equals('Saules iela'));
      expect(stateMachine.pendingStreetDistanceMeters, equals(0.0));
    });

    test('Stopped at red light (speed < 3.5 km/h) resets candidate distance', () {
      final stateMachine = VoiceAssistantStateMachine(
        initialMaxSpeed: 50,
        initialIsOneWay: false,
        initialStreetName: 'Jūras iela',
        announceStreetChanges: true,
      );

      // Rider stops at red light (speed = 1.0 km/h) and GPS wobbles to Saules iela
      final p1 = stateMachine.processRoadPoint(
        RoadPoint(
          latitude: 57.39800,
          longitude: 21.56500,
          vehicleSpeedKmh: 1.0,
          maxSpeedLimitKmh: 50,
          isOneWay: false,
          streetName: 'Saules iela',
          timestamp: DateTime.now(),
        ),
        streetChangeDistanceMeters: 35.0,
      );
      expect(p1.where((e) => e.type == VoiceAlertType.streetChanged), isEmpty);
      expect(stateMachine.currentStreetName, equals('Jūras iela'));
      expect(stateMachine.pendingStreetDistanceMeters, equals(0.0));
    });
  });
}
