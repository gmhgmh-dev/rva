import 'package:flutter_test/flutter_test.dart';
import 'package:rva/models/voice_alert_event.dart';
import 'package:rva/services/mock_location_service.dart';
import 'package:rva/services/voice_assistant_state_machine.dart';

void main() {
  group('Ventspils Mock Route & 4-Trigger Sequence Tests', () {
    late MockLocationService mockService;
    late VoiceAssistantStateMachine stateMachine;

    setUp(() {
      mockService = MockLocationService();
      stateMachine = VoiceAssistantStateMachine(initialMaxSpeed: 50, initialIsOneWay: false);
    });

    test('GPX XML string parses correctly into RoadPoints', () {
      const sampleGpx = '''<?xml version="1.0" encoding="UTF-8"?>
<gpx version="1.1" creator="Test">
  <trk>
    <trkseg>
      <trkpt lat="57.3915" lon="21.5648">
        <extensions>
          <street_name>Lielais prospekts</street_name>
          <speed_limit>50</speed_limit>
          <oneway>0</oneway>
          <vehicle_speed>45.0</vehicle_speed>
        </extensions>
      </trkpt>
      <trkpt lat="57.3956" lon="21.5579">
        <extensions>
          <street_name>Sofijas iela</street_name>
          <speed_limit>30</speed_limit>
          <oneway>1</oneway>
          <vehicle_speed>25.0</vehicle_speed>
        </extensions>
      </trkpt>
    </trkseg>
  </trk>
</gpx>''';

      final points = mockService.parseGpxString(sampleGpx);
      expect(points.length, equals(2));

      expect(points[0].streetName, equals('Lielais prospekts'));
      expect(points[0].maxSpeedLimitKmh, equals(50));
      expect(points[0].isOneWay, isFalse);

      expect(points[1].streetName, equals('Sofijas iela'));
      expect(points[1].maxSpeedLimitKmh, equals(30));
      expect(points[1].isOneWay, isTrue);
    });

    test('Ventspils testa maršruts secīgi izpilda visus 4 trigerus', () {
      final route = MockLocationService.defaultVentspilsRoute;
      final generatedAlerts = <VoiceAlertEvent>[];

      for (final point in route) {
        final alerts = stateMachine.processRoadPoint(point);
        generatedAlerts.addAll(alerts);
      }

      // Pārbaudām, ka maršrutā visi 4 trigeri ir izsaukti
      expect(generatedAlerts.length, equals(4), reason: 'Jābūt tieši 4 trigeru notikumiem');

      // 1. TRIGERIS: Samazināts ātruma ierobežojums: 30 kilometri stundā. (Kuldīgas iela)
      expect(generatedAlerts[0].type, equals(VoiceAlertType.speedReduced));
      expect(generatedAlerts[0].spokenText, equals('Samazināts ātruma ierobežojums: 30 kilometri stundā.'));
      expect(generatedAlerts[0].streetName, equals('Kuldīgas iela'));

      // 2. TRIGERIS (Trigeris 3 specifikācijā): Iebraukšana vienvirziena ielā (Sofijas iela)
      expect(generatedAlerts[1].type, equals(VoiceAlertType.oneWayEntered));
      expect(generatedAlerts[1].spokenText, equals('Jūs atrodaties uz vienvirziena ielas.'));
      expect(generatedAlerts[1].streetName, equals('Sofijas iela'));

      // 3. TRIGERIS (Trigeris 4 specifikācijā): Izbraukšana no vienvirziena ielas (Platā iela)
      expect(generatedAlerts[2].type, equals(VoiceAlertType.oneWayExited));
      expect(generatedAlerts[2].spokenText, equals('Vienvirziena iela ir beigusies.'));
      expect(generatedAlerts[2].streetName, equals('Platā iela'));

      // 4. TRIGERIS (Trigeris 2 specifikācijā): Ātruma ierobežojuma zonas beigas (Lielais prospekts, 50 km/h)
      expect(generatedAlerts[3].type, equals(VoiceAlertType.speedZoneEnded));
      expect(generatedAlerts[3].spokenText, equals('Atruma ierobežojuma zona ir beigusies.'));
      expect(generatedAlerts[3].streetName, equals('Lielais prospekts'));
    });
  });
}
