import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../models/voice_alert_event.dart';
import '../services/driving_assistant_manager.dart';
import '../widgets/one_way_badge_widget.dart';
import '../widgets/speed_sign_widget.dart';
import 'settings_screen.dart';

class DashboardScreen extends StatefulWidget {
  final DrivingAssistantManager assistantManager;

  const DashboardScreen({
    super.key,
    required this.assistantManager,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    widget.assistantManager.addListener(_onStateChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.assistantManager.settingsService.autoStartGps && widget.assistantManager.mode == DriveMode.idle) {
        widget.assistantManager.startRealGps();
      }
    });
  }

  @override
  void dispose() {
    widget.assistantManager.removeListener(_onStateChanged);
    super.dispose();
  }

  void _onStateChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final manager = widget.assistantManager;
    final currentPoint = manager.currentPoint;
    final isDriving = manager.mode != DriveMode.idle;

    return Scaffold(
      backgroundColor: const Color(0xFF121418),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B1E24),
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.blueAccent.withAlpha(50),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.record_voice_over, color: Colors.blueAccent, size: 22),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Roads Voice Assistant',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    'GPS ātruma & vienvirziena brīdinājumi',
                    style: TextStyle(fontSize: 11, color: Colors.white70),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: manager.isMuted ? 'Ieslēgt balsi' : 'Izslēgt balsi',
            icon: Icon(
              manager.isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
              color: manager.isMuted ? Colors.redAccent : Colors.greenAccent,
            ),
            onPressed: () => manager.toggleMute(),
          ),
          IconButton(
            tooltip: 'Bezsaistes kartes iestatījumi',
            icon: const Icon(Icons.settings_rounded, color: Colors.white70),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SettingsScreen(assistantManager: widget.assistantManager),
                ),
              );
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Top Mode & Status Banner
            _buildStatusHeader(manager),

            // Offline PMTiles Map Status Banner
            _buildOfflineMapBanner(manager),

            // Road Dashboard (Speed Limit & One-Way indicators)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E222B),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: manager.isInReducedSpeedZone ? Colors.amber.shade700 : const Color(0xFF2C323F),
                    width: 1.5,
                  ),
                ),
                child: Column(
                  children: [
                    // Data Source Banner (Debug / Status Indicator)
                    _buildDataSourceIndicator(manager),

                    // Street & Coordinates
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.navigation_rounded, color: Colors.cyanAccent, size: 22),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                currentPoint?.streetName ?? 'Nav aktīva maršruta',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                currentPoint != null
                                    ? 'GPS: ${currentPoint.latitude.toStringAsFixed(5)}, ${currentPoint.longitude.toStringAsFixed(5)}'
                                    : 'Gaidīšanas režīms • Ventspils',
                                style: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 12,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (currentPoint != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.cyan.shade900.withAlpha(120),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.cyanAccent, width: 1),
                            ),
                            child: Text(
                              '${currentPoint.vehicleSpeedKmh.toStringAsFixed(0)} km/h',
                              style: const TextStyle(
                                color: Colors.cyanAccent,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const Divider(color: Color(0xFF2C323F), height: 18),

                    // Signs & Indicators Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        SpeedSignWidget(
                          speedLimit: manager.currentMaxSpeed,
                          isReducedZone: manager.isInReducedSpeedZone,
                        ),
                        OneWayBadgeWidget(
                          isOneWay: manager.isOneWay,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Action Buttons Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildActionButtons(manager, isDriving),
            ),

            const SizedBox(height: 6),

            // Live Alert & Trigger Log
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  const Icon(Icons.history_rounded, color: Colors.white70, size: 18),
                  const SizedBox(width: 8),
                  const Text(
                    'BALSS BRĪDINĀJUMU ŽURNĀLS',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${manager.alertHistory.length} paziņojumi',
                    style: const TextStyle(color: Colors.white38, fontSize: 11),
                  ),
                ],
              ),
            ),

            // Alert List View
            Expanded(
              child: _buildAlertHistoryList(manager),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataSourceIndicator(DrivingAssistantManager manager) {
    final currentPoint = manager.currentPoint;
    final mode = manager.mode;

    String label;
    IconData icon;
    Color color;

    if (mode == DriveMode.realGps) {
      final street = (currentPoint != null && currentPoint.streetName.isNotEmpty)
          ? currentPoint.streetName
          : 'Meklē atrašanās vietu...';
      final source = currentPoint?.dataSource ??
          (manager.isOfflineMapLoaded ? 'PMTiles bezsaistes karte' : 'Overpass API tiešsaiste');
      label = 'Datu avots: Reālais GPS [$street] ($source)';
      icon = Icons.satellite_alt_rounded;
      color = Colors.greenAccent;
    } else if (mode == DriveMode.mockSimulation) {
      final street = (currentPoint != null && currentPoint.streetName.isNotEmpty)
          ? currentPoint.streetName
          : 'Lielais prospekts';
      label = 'Datu avots: Demo simulācija [$street]';
      icon = Icons.smart_toy_outlined;
      color = Colors.orangeAccent;
    } else {
      label = 'Datu avots: Gaidīšanas režīms (GPS nav aktīvs)';
      icon = Icons.location_off_outlined;
      color = Colors.white54;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withAlpha(80), width: 1),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusHeader(DrivingAssistantManager manager) {
    Color statusColor;
    String statusTitle;
    IconData statusIcon;

    switch (manager.mode) {
      case DriveMode.mockSimulation:
        statusColor = Colors.orangeAccent;
        statusTitle = 'VENTSPILS TESTA BRAUCIENS AKTĪVS';
        statusIcon = Icons.science_rounded;
        break;
      case DriveMode.realGps:
        statusColor = Colors.greenAccent;
        statusTitle = 'REĀLAIS GPS MARŠRUTS AKTĪVS';
        statusIcon = Icons.gps_fixed_rounded;
        break;
      case DriveMode.idle:
        statusColor = Colors.white54;
        statusTitle = 'GAIDĪŠANAS REŽĪMS';
        statusIcon = Icons.pause_circle_outline_rounded;
        break;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: const Color(0xFF16191F),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(statusIcon, color: statusColor, size: 16),
          const SizedBox(width: 8),
          Text(
            statusTitle,
            style: TextStyle(
              color: statusColor,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOfflineMapBanner(DrivingAssistantManager manager) {
    final isLoaded = manager.isOfflineMapLoaded;
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SettingsScreen(assistantManager: widget.assistantManager),
          ),
        );
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: isLoaded
              ? Colors.teal.shade900.withAlpha(60)
              : Colors.amber.shade900.withAlpha(50),
          border: Border(
            bottom: BorderSide(
              color: isLoaded
                  ? Colors.tealAccent.withAlpha(50)
                  : Colors.amberAccent.withAlpha(50),
              width: 1,
            ),
          ),
        ),
        child: Row(
          children: [
            Icon(
              isLoaded ? Icons.map_rounded : Icons.cloud_download_outlined,
              color: isLoaded ? Colors.tealAccent : Colors.amberAccent,
              size: 14,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                isLoaded
                    ? 'Latvijas PMTiles bezsaistes karte aktīva'
                    : 'Bezsaistes karte nav lejupielādēta • Pieskarieties, lai uzstādītu',
                style: TextStyle(
                  color: isLoaded ? Colors.tealAccent : Colors.amberAccent,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: isLoaded ? Colors.tealAccent : Colors.amberAccent,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(DrivingAssistantManager manager, bool isDriving) {
    return Column(
      children: [
        Row(
          children: [
            // Poga: Sākt reālo GPS
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: manager.mode == DriveMode.realGps ? Colors.green.shade800 : const Color(0xFF233044),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(
                      color: manager.mode == DriveMode.realGps ? Colors.greenAccent : Colors.blue.shade700,
                      width: 1.5,
                    ),
                  ),
                ),
                icon: const Icon(Icons.gps_fixed_rounded, size: 20),
                label: const Text(
                  'Sākt reālo GPS',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                onPressed: () async {
                  final serviceEnabled = await Geolocator.isLocationServiceEnabled();
                  if (!serviceEnabled && mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Ierīcē ir izslēgts GPS atrašanās vietas pakalpojums.'),
                        backgroundColor: Colors.redAccent,
                        action: SnackBarAction(
                          label: 'Ieslēgt GPS',
                          textColor: Colors.white,
                          onPressed: () => Geolocator.openLocationSettings(),
                        ),
                      ),
                    );
                    return;
                  }

                  final permission = await Geolocator.checkPermission();
                  if (permission == LocationPermission.deniedForever && mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('GPS atļaujas ir bloķētas iestatījumos.'),
                        backgroundColor: Colors.redAccent,
                        action: SnackBarAction(
                          label: 'Iestatījumi',
                          textColor: Colors.white,
                          onPressed: () => Geolocator.openAppSettings(),
                        ),
                      ),
                    );
                    return;
                  }

                  final success = await manager.startRealGps();
                  if (!success && mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Neizdevās piekļūt GPS datiem vai atļaujas noraidītas.'),
                        backgroundColor: Colors.redAccent,
                      ),
                    );
                  }
                },
              ),
            ),
            const SizedBox(width: 12),
            // Poga: Palaist Ventspils testa braucienu
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: manager.mode == DriveMode.mockSimulation
                      ? Colors.orange.shade800
                      : const Color(0xFF382F1D),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(
                      color: manager.mode == DriveMode.mockSimulation ? Colors.amberAccent : Colors.orange.shade600,
                      width: 1.5,
                    ),
                  ),
                ),
                icon: const Icon(Icons.play_arrow_rounded, size: 22),
                label: const Text(
                  'Palaist Ventspils testa braucienu',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                onPressed: () {
                  manager.startVentspilsTestRoute(interval: const Duration(seconds: 2));
                },
              ),
            ),
          ],
        ),
        if (isDriving) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                    side: const BorderSide(color: Colors.redAccent, width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.stop_rounded, size: 18),
                  label: const Text('Apturēt braucienu', style: TextStyle(fontWeight: FontWeight.bold)),
                  onPressed: () => manager.stop(),
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.amberAccent,
                  side: const BorderSide(color: Colors.amberAccent, width: 1.5),
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.skip_next_rounded, size: 18),
                label: const Text('Nākamais punkts'),
                onPressed: () => manager.stepNextMockPoint(),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildAlertHistoryList(DrivingAssistantManager manager) {
    if (manager.alertHistory.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.mic_none_rounded, color: Colors.white.withAlpha(40), size: 36),
              const SizedBox(height: 6),
              const Text(
                'Pagaidām nav atskaņots neviens paziņojums.',
                style: TextStyle(color: Colors.white38, fontSize: 13),
              ),
              const SizedBox(height: 2),
              const Text(
                'Palaidiet Ventspils testa braucienu, lai pārbaudītu trigerus.',
                style: TextStyle(color: Colors.white24, fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      itemCount: manager.alertHistory.length,
      itemBuilder: (context, index) {
        final alert = manager.alertHistory[index];
        return _buildAlertCard(alert);
      },
    );
  }

  Widget _buildAlertCard(VoiceAlertEvent alert) {
    Color badgeColor;
    String badgeLabel;
    IconData alertIcon;

    switch (alert.type) {
      case VoiceAlertType.speedReduced:
        badgeColor = Colors.redAccent;
        badgeLabel = 'TRIGERIS 1 • Ātruma samazinājums';
        alertIcon = Icons.speed_rounded;
        break;
      case VoiceAlertType.speedZoneEnded:
        badgeColor = Colors.greenAccent;
        badgeLabel = 'TRIGERIS 2 • Zonas beigas';
        alertIcon = Icons.check_circle_outline_rounded;
        break;
      case VoiceAlertType.oneWayEntered:
        badgeColor = Colors.blueAccent;
        badgeLabel = 'TRIGERIS 3 • Vienvirziena sākums';
        alertIcon = Icons.arrow_upward_rounded;
        break;
      case VoiceAlertType.oneWayExited:
        badgeColor = Colors.cyanAccent;
        badgeLabel = 'TRIGERIS 4 • Vienvirziena beigas';
        alertIcon = Icons.swap_vert_rounded;
        break;
      case VoiceAlertType.livingStreetEntered:
        badgeColor = Colors.deepOrangeAccent;
        badgeLabel = 'DZĪVOJAMĀ ZONA • 20 km/h';
        alertIcon = Icons.home_rounded;
        break;
      case VoiceAlertType.speed30ZoneEntered:
        badgeColor = Colors.orangeAccent;
        badgeLabel = '30 ZONA • 30 km/h';
        alertIcon = Icons.traffic_rounded;
        break;
      case VoiceAlertType.speedRestored:
        badgeColor = Colors.lightGreenAccent;
        badgeLabel = 'ATĻAUTAIS ĀTRUMS • 50 km/h';
        alertIcon = Icons.speed_rounded;
        break;
      case VoiceAlertType.speedingWarning:
        badgeColor = Colors.redAccent;
        badgeLabel = 'ĀTRUMA PĀRSNIEG AANA';
        alertIcon = Icons.warning_rounded;
        break;
      case VoiceAlertType.streetChanged:
        badgeColor = Colors.amberAccent;
        badgeLabel = 'IELAS MAIŅA';
        alertIcon = Icons.alt_route_rounded;
        break;
    }

    final timeStr =
        '${alert.timestamp.hour.toString().padLeft(2, '0')}:${alert.timestamp.minute.toString().padLeft(2, '0')}:${alert.timestamp.second.toString().padLeft(2, '0')}';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: const Color(0xFF1A1D24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: badgeColor.withAlpha(80), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: badgeColor.withAlpha(40),
                shape: BoxShape.circle,
              ),
              child: Icon(alertIcon, color: badgeColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: badgeColor.withAlpha(50),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          badgeLabel,
                          style: TextStyle(
                            color: badgeColor,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        timeStr,
                        style: const TextStyle(color: Colors.white38, fontSize: 11),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '"${alert.spokenText}"',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (alert.streetName != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Iela: ${alert.streetName}',
                      style: const TextStyle(color: Colors.white54, fontSize: 11),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
