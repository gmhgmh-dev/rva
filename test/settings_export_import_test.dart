import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rva/services/settings_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('SettingsService Export & Import Tests', () {
    test('exports default settings correctly', () async {
      final settings = SettingsService();
      await settings.loadSettings();

      final map = settings.exportSettings();
      expect(map['road_search_radius_meters'], 40.0);
      expect(map['courtyard_search_radius_meters'], 15.0);
      expect(map['audio_ducking'], true);
      expect(map['lookahead_alerts'], true);
      expect(map['lookahead_distance_meters'], 70.0);
      expect(map['app_version'], '0.2.0');

      final jsonStr = settings.exportJsonString();
      expect(jsonStr.contains('"road_search_radius_meters": 40.0'), true);
      expect(jsonStr.contains('"audio_ducking": true'), true);
    });

    test('imports modified settings and persists them', () async {
      final settings = SettingsService();
      await settings.loadSettings();

      final customJson = '''
      {
        "road_search_radius_meters": 55.0,
        "courtyard_search_radius_meters": 20.0,
        "street_change_confirmations": 6,
        "prioritize_pedestrian_cycleways": true,
        "audio_ducking": false,
        "lookahead_distance_meters": 85.0
      }
      ''';

      final success = await settings.importJsonString(customJson);
      expect(success, true);
      expect(settings.roadSearchRadiusMeters, 55.0);
      expect(settings.courtyardSearchRadiusMeters, 20.0);
      expect(settings.streetChangeConfirmations, 6);
      expect(settings.prioritizePedestrianAndCycleways, true);
      expect(settings.audioDucking, false);
      expect(settings.lookaheadDistanceMeters, 85.0);

      // Verify that reloading from SharedPreferences retains imported values
      final freshSettings = SettingsService();
      await freshSettings.loadSettings();
      expect(freshSettings.roadSearchRadiusMeters, 55.0);
      expect(freshSettings.courtyardSearchRadiusMeters, 20.0);
      expect(freshSettings.streetChangeConfirmations, 6);
      expect(freshSettings.prioritizePedestrianAndCycleways, true);
      expect(freshSettings.audioDucking, false);
      expect(freshSettings.lookaheadDistanceMeters, 85.0);
    });

    test('handles invalid JSON gracefully', () async {
      final settings = SettingsService();
      await settings.loadSettings();

      final invalidJson = 'Not a valid JSON string {[';
      final success = await settings.importJsonString(invalidJson);
      expect(success, false);
    });
  });
}
