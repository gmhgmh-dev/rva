import 'package:flutter/material.dart';
import '../services/settings_service.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  static const String appName = 'Roads Voice Assistant';
  static const String appShortName = 'RVA';
  static const String appVersion = SettingsService.appVersion;
  static const String buildNumber = '3';
  static const String releaseTag = 'v0.2.1-stable';
  static const String repoUrl = 'https://github.com/gmhgmh-dev/rva';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121418),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E222B),
        elevation: 0,
        title: const Text(
          'Par lietotni',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
          // App Logo & Version Header
          Center(
            child: Column(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1976D2), Color(0xFF00B0FF)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blueAccent.withOpacity(0.35),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.record_voice_over_rounded,
                    size: 42,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  appName,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blueAccent.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.blueAccent.withOpacity(0.3)),
                  ),
                  child: const Text(
                    'Versija $appVersion (Būvējums $buildNumber) • $releaseTag',
                    style: TextStyle(
                      color: Color(0xFF8AB4F8),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Bezsaistes balss asistents Latvijas ceļiem',
                  style: TextStyle(color: Colors.white54, fontSize: 13),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Overview Card
          _buildCard(
            title: 'Apraksts un mērķis',
            icon: Icons.info_outline_rounded,
            iconColor: Colors.blueAccent,
            child: const Text(
              'Roads Voice Assistant (RVA) ir specializēts bezsaistes balss asistents autovadītājiem un mikromobilitātes braucējiem Latvijā. '
              'Lietotne darbojas pilnīgi autonomi bez interneta pieslēguma, izmantojot lokālu Latvijas vektorkarti (PMTiles), '
              'un nodrošina savlaicīgus balss paziņojumus par atļauto braukšanas ātrumu, ātruma ierobežojuma un dzīvojamajām zonām, '
              'kā arī apsteidzošus brīdinājumus par fotoradariem un ātrumvaļņiem.',
              style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.45),
            ),
          ),

          const SizedBox(height: 16),

          // Key Capabilities Card
          _buildCard(
            title: 'Galvenās funkcijas',
            icon: Icons.star_outline_rounded,
            iconColor: Colors.amberAccent,
            child: Column(
              children: [
                _buildFeatureItem(Icons.speed_rounded, 'Reāllaika atļautā ātruma un ielu noteikšana', 'Pilnībā bezsaistē no lokālā vektorkartes faila (latvia.pmtiles).'),
                _buildFeatureItem(Icons.location_city_rounded, 'Dzīvojamo (20 km/h) un 30 zonu paziņojumi', 'Automātiska iebraukšanas un izbraukšanas zonu atpazīšana.'),
                _buildFeatureItem(Icons.warning_amber_rounded, 'Ātruma pārsniegšanas trauksmes', 'Fiksēta (+0..+10 km/h) vai procentuāla (3..15%) pielāgojama tolerance.'),
                _buildFeatureItem(Icons.visibility_rounded, 'Apsteidzošā noteikšana (Lookahead)', 'Projekcija 50–100m uz priekšu gaidāmo ātruma zonu savlaicīgai paziņošanai.'),
                _buildFeatureItem(Icons.camera_alt_outlined, 'Fotoradari un ātrumvaļņi', 'Brīdinājumi par stacionārajiem radariem un paaugstinātajām gājēju pārejām.'),
                _buildFeatureItem(Icons.volume_down_rounded, 'Audio ducking (Mūzikas pieklusināšana)', 'Automātiski pieklusina fona mūziku un radio balss paziņojumu laikā.'),
                _buildFeatureItem(Icons.electric_scooter_rounded, 'Mikromobilitātes (skrejriteņa/velo) adaptācija', 'Inteliģenta veloceliņu un ietvju piesaiste pie lēna braukšanas ātruma.'),
                _buildFeatureItem(Icons.analytics_outlined, 'Diagnostika un telemetrija', 'GPX maršrutu un paziņojumu žurnālu (.log) ieraksts un 1-klikšķa eksports.'),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Open Source & Data Attribution Card
          _buildCard(
            title: 'Kartes un atvērtā koda datu avoti',
            icon: Icons.map_outlined,
            iconColor: Colors.greenAccent,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildAttributionRow('OpenStreetMap', 'Kartes dati © OpenStreetMap contributors (ODbL licence). Paldies OSM kopienai par detalizētajiem Latvijas un Ventspils ceļu datiem.'),
                const Divider(color: Color(0xFF2C323F), height: 18),
                _buildAttributionRow('Protomaps & PMTiles', 'Bezsaistes vektorkaršu flīžu formāts un MVT parsētājs (BSD-3-Clause).'),
                const Divider(color: Color(0xFF2C323F), height: 18),
                _buildAttributionRow('Flutter & Dart', 'Google lietotņu izstrādes ietvars (BSD-3-Clause).'),
                const Divider(color: Color(0xFF2C323F), height: 18),
                _buildAttributionRow('Flutter TTS', 'Teksta-runas sintēzes dzinēja integrācija latviešu valodā.'),
                const Divider(color: Color(0xFF2C323F), height: 18),
                _buildAttributionRow('Geolocator & Wakelock', 'Augstas precizitātes GPS un ekrāna vadība.'),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Privacy & Security Card
          _buildCard(
            title: 'Privātums un datu drošība',
            icon: Icons.security_rounded,
            iconColor: Colors.cyanAccent,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  '• 100% lokāla datu apstrāde: visi ģeotelpiskie aprēķini, GPS izsekošana un balss paziņojumi tiek izpildīti tikai jūsu ierīcē.',
                  style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
                ),
                SizedBox(height: 6),
                Text(
                  '• Nekādi telemetrijas dati, GPS koordinātas vai braucienu maršruti netiek automātiski nosūtīti ārējiem serveriem.',
                  style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
                ),
                SizedBox(height: 6),
                Text(
                  '• Diagnostikas pakotnes nosūtīšana notiek tikai un vienīgi pēc jūsu tiešas izvēles (kopīgošanas poga iestatījumos).',
                  style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Developer & License Action Card
          _buildCard(
            title: 'Izstrāde un licences',
            icon: Icons.code_rounded,
            iconColor: const Color(0xFF8AB4F8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Izstrādātājs: GMH Dev\nProjekts: Roads Voice Assistant (RVA)\nRepozitorijs: $repoUrl',
                  style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.5),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.description_outlined, size: 18),
                        label: const Text('Atvērtā koda licences'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF8AB4F8),
                          side: const BorderSide(color: Color(0xFF2C323F)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () {
                          showLicensePage(
                            context: context,
                            applicationName: appName,
                            applicationVersion: 'v$appVersion (Build $buildNumber)',
                            applicationLegalese: '© 2026 GMH Dev. Kartes dati © OpenStreetMap contributors.',
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),
          const Center(
            child: Text(
              '© 2026 GMH Dev. Visas tiesības aizsargātas.',
              style: TextStyle(color: Colors.white38, fontSize: 11),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    ),
  );
}

  Widget _buildCard({
    required String title,
    required IconData icon,
    required Color iconColor,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E222B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF2C323F)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _buildFeatureItem(IconData icon, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.cyanAccent),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttributionRow(String name, String description) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          name,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          description,
          style: const TextStyle(color: Colors.white60, fontSize: 12, height: 1.35),
        ),
      ],
    );
  }
}
