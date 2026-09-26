import 'package:flutter_test/flutter_test.dart';
import 'package:rva/models/voice_alert_event.dart';
import 'package:rva/services/voice_assistant_state_machine.dart';

void main() {
  group('VoiceAssistantStateMachine Tests', () {
    late VoiceAssistantStateMachine stateMachine;

    setUp(() {
      // Start in default standard urban state (50 km/h, two-way street)
      stateMachine = VoiceAssistantStateMachine(initialMaxSpeed: 50, initialIsOneWay: false);
    });

    test('Initial state is correctly set', () {
      expect(stateMachine.currentMaxSpeed, equals(50));
      expect(stateMachine.isOneWay, isFalse);
      expect(stateMachine.isInReducedSpeedZone, isFalse);
    });

    test('TRIGERIS 1: Ātruma samazināšanās zem 50 km/h (piem., 30 km/h)', () {
      final events = stateMachine.processUpdate(
        newMaxSpeed: 30,
        newIsOneWay: false,
        streetName: 'Kuldīgas iela',
      );

      expect(events.length, equals(1));
      final alert = events.first;
      expect(alert.type, equals(VoiceAlertType.speedReduced));
      expect(alert.spokenText, equals('Samazināts ātruma ierobežojums: 30 kilometri stundā.'));
      expect(stateMachine.currentMaxSpeed, equals(30));
      expect(stateMachine.isInReducedSpeedZone, isTrue);
    });

    test('TRIGERIS 2: Ātruma atgriešanās uz 50 km/h pēc samazinātas zonas', () {
      // Step 1: Iebraucam 30 km/h zonā
      stateMachine.processUpdate(newMaxSpeed: 30, newIsOneWay: false);
      expect(stateMachine.isInReducedSpeedZone, isTrue);

      // Step 2: Izbraucam no 30 km/h zonas atpakaļ uz 50 km/h
      final events = stateMachine.processUpdate(
        newMaxSpeed: 50,
        newIsOneWay: false,
        streetName: 'Lielais prospekts',
      );

      expect(events.length, equals(1));
      final alert = events.first;
      expect(alert.type, equals(VoiceAlertType.speedZoneEnded));
      expect(alert.spokenText, equals('Atruma ierobežojuma zona ir beigusies.'));
      expect(stateMachine.currentMaxSpeed, equals(50));
      expect(stateMachine.isInReducedSpeedZone, isFalse);
    });

    test('TRIGERIS 3: Auto no divvirzienu ielas iebrauc vienvirziena ielā (oneway == true)', () {
      final events = stateMachine.processUpdate(
        newMaxSpeed: 50,
        newIsOneWay: true,
        streetName: 'Sofijas iela',
      );

      expect(events.length, equals(1));
      final alert = events.first;
      expect(alert.type, equals(VoiceAlertType.oneWayEntered));
      expect(alert.spokenText, equals('Jūs atrodaties uz vienvirziena ielas.'));
      expect(stateMachine.isOneWay, isTrue);
    });

    test('TRIGERIS 4: Auto izbrauc no vienvirziena ielas atpakaļ divvirzienu ielā (oneway == false)', () {
      // Step 1: Iebraucam vienvirziena ielā
      stateMachine.processUpdate(newMaxSpeed: 30, newIsOneWay: true);
      expect(stateMachine.isOneWay, isTrue);

      // Step 2: Izbraucam atpakaļ uz divvirzienu ielu
      final events = stateMachine.processUpdate(
        newMaxSpeed: 30,
        newIsOneWay: false,
        streetName: 'Platā iela',
      );

      expect(events.length, equals(1));
      final alert = events.first;
      expect(alert.type, equals(VoiceAlertType.oneWayExited));
      expect(alert.spokenText, equals('Vienvirziena iela ir beigusies.'));
      expect(stateMachine.isOneWay, isFalse);
    });

    test('Vienādas koordinātas/stāvokļi neatkārto brīdinājumus nepārtraukti', () {
      // Pirmā 30 km/h zona
      final events1 = stateMachine.processUpdate(newMaxSpeed: 30, newIsOneWay: false);
      expect(events1.length, equals(1));

      // Nākamais punkts ar to pašu ātrumu un ielas virzienu
      final events2 = stateMachine.processUpdate(newMaxSpeed: 30, newIsOneWay: false);
      expect(events2.isEmpty, isTrue);

      // Vienvirziena iela
      final events3 = stateMachine.processUpdate(newMaxSpeed: 30, newIsOneWay: true);
      expect(events3.length, equals(1));

      // Nākamais punkts pa to pašu vienvirziena ielu
      final events4 = stateMachine.processUpdate(newMaxSpeed: 30, newIsOneWay: true);
      expect(events4.isEmpty, isTrue);
    });
  });
}
