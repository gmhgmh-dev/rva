import 'package:flutter/material.dart';
import '../services/driving_assistant_manager.dart';
import '../services/map_downloader_service.dart';
import '../services/settings_service.dart';

/// Settings screen managing the offline Latvia PMTiles vector map.
class SettingsScreen extends StatefulWidget {
  final DrivingAssistantManager assistantManager;

  const SettingsScreen({
    super.key,
    required this.assistantManager,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _urlController;
  MapFileInfo? _fileInfo;
  bool _showAdvancedUrl = false;

  MapDownloaderService get _downloader => widget.assistantManager.mapDownloaderService;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(text: MapDownloaderService.defaultUrl);
    _downloader.addListener(_onDownloaderChanged);
    _loadFileMetadata();
  }

  @override
  void dispose() {
    _downloader.removeListener(_onDownloaderChanged);
    _urlController.dispose();
    super.dispose();
  }

  void _onDownloaderChanged() {
    if (mounted) {
      setState(() {});
      if (_downloader.progress.isCompleted) {
        _loadFileMetadata();
      }
    }
  }

  Future<void> _loadFileMetadata() async {
    final info = await _downloader.getMapFileInfo();
    if (mounted) {
      setState(() {
        _fileInfo = info;
      });
    }
  }

  Future<void> _startDownload() async {
    final customUrl = _urlController.text.trim();
    try {
      await _downloader.downloadMap(
        url: customUrl.isNotEmpty ? customUrl : null,
      );
      // Automatically load the newly downloaded archive into PMTilesService
      final loaded = await widget.assistantManager.tryLoadOfflineMap();
      await _loadFileMetadata();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              loaded
                  ? 'Latvijas bezsaistes karte veiksmīgi lejupielādēta un aktivizēta!'
                  : 'Karte lejupielādēta, bet neizdevās ielādēt PMTiles arhīvu.',
            ),
            backgroundColor: loaded ? Colors.green.shade800 : Colors.amber.shade900,
          ),
        );
      }
    } catch (e) {
      if (mounted && !_downloader.progress.isCancelled) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lejupielādes kļūda: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _deleteMap() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E222B),
        title: const Text('Dzēst bezsaistes karti?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Vai tiešām vēlaties dzēst failu latvia.pmtiles no ierīces atmiņas?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Atcelt', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Dzēst', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await widget.assistantManager.pmTilesService.close();
      await _downloader.deleteMapFile();
      await _loadFileMetadata();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bezsaistes karte dzēsta.'),
            backgroundColor: Colors.blueGrey,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = _downloader.progress;
    final isDownloading = progress.isDownloading;
    final hasFile = _fileInfo != null;

    return Scaffold(
      backgroundColor: const Color(0xFF121418),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B1E24),
        elevation: 0,
        title: const Text(
          'Iestatījumi • Bezsaistes karte',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 40),
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status & File Info Card
            _buildFileInfoCard(hasFile),

            const SizedBox(height: 16),

            // Download Progress Indicator (visible when downloading or recently failed)
            if (isDownloading || progress.isFailed || progress.isCancelled) ...[
              _buildProgressSection(progress),
              const SizedBox(height: 16),
            ],

            // Main Action Button: Lejupielādēt / Atjaunināt Latvijas bezsaistes karti
            _buildDownloadButton(isDownloading),

            const SizedBox(height: 12),

            // Delete Button if file exists
            if (hasFile && !isDownloading) ...[
              Center(
                child: TextButton.icon(
                  style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                  label: const Text('Dzēst lokālo kartes failu'),
                  onPressed: _deleteMap,
                ),
              ),
              const SizedBox(height: 8),
            ],

            const Divider(color: Color(0xFF2C323F), height: 32),

            // Advanced URL Settings
            _buildAdvancedSettings(isDownloading),

            const Divider(color: Color(0xFF2C323F), height: 32),
            
            // App settings
            _buildAppSettings(),
          ],
        ),
        ),
      ),
    );
  }

  Widget _buildAppSettings() {
    final settings = widget.assistantManager.settingsService;
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Balss asistenta iestatījumi',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildSwitch(
              title: 'Klusuma režīms',
              subtitle: 'Atslēdz visas balss norādes. Darbosies tikai vizuālie brīdinājumi.',
              value: settings.isMuted,
              onChanged: (val) => settings.setIsMuted(val),
            ),
            _buildSwitch(
              title: 'Dinamiskās frāzes',
              subtitle: 'Izrunā pilnus teikumus ar ātruma vienībām, nevis lakoniskus paziņojumus.',
              value: settings.useDynamicPhrases,
              onChanged: (val) => settings.setUseDynamicPhrases(val),
            ),
            _buildSwitch(
              title: 'Paziņot ielu nosaukumus',
              subtitle: 'Nosauc ielas nosaukumu pie katras krustojuma/ielas maiņas.',
              value: settings.announceStreetChanges,
              onChanged: (val) => settings.setAnnounceStreetChanges(val),
            ),
            _buildSwitch(
              title: 'Īss pīkstiens balss vietā',
              subtitle: 'Ātruma pārsniegšanas gadījumā atskaņos tikai īsu brīdinājuma signālu.',
              value: settings.speedingBeepOnly,
              onChanged: (val) => settings.setSpeedingBeepOnly(val),
            ),
            const SizedBox(height: 16),
            const Text(
              'Ātruma brīdinājuma atkārtošanas intervāls',
              style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<int>(
              value: settings.speedWarningInterval,
              dropdownColor: const Color(0xFF1E222B),
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFF1E222B),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
              items: const [
                DropdownMenuItem(value: 5, child: Text('5 sekundes')),
                DropdownMenuItem(value: 10, child: Text('10 sekundes')),
                DropdownMenuItem(value: 15, child: Text('15 sekundes')),
                DropdownMenuItem(value: 30, child: Text('30 sekundes')),
                DropdownMenuItem(value: 9999, child: Text('Brīdināt tikai vienreiz')),
              ],
              onChanged: (val) {
                if (val != null) {
                  settings.setSpeedWarningInterval(val);
                }
              },
            ),
            const SizedBox(height: 16),
            const Text(
              'Ātruma tolerances režīms',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            const Text(
              'Izvēlieties statisku slieksni (+km/h) vai progresīvu procentuālo slieksni (lielākiem ātrumiem lielāka pielaide).',
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1E222B),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF2C323F)),
              ),
              padding: const EdgeInsets.all(4),
              child: Row(
                children: [
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => settings.setSpeedToleranceMode(SpeedToleranceMode.fixed),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        decoration: BoxDecoration(
                          color: settings.speedToleranceMode == SpeedToleranceMode.fixed
                              ? const Color(0xFF2E66FF)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'Statisks (+km/h)',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: settings.speedToleranceMode == SpeedToleranceMode.fixed
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => settings.setSpeedToleranceMode(SpeedToleranceMode.percentage),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        decoration: BoxDecoration(
                          color: settings.speedToleranceMode == SpeedToleranceMode.percentage
                              ? const Color(0xFF2E66FF)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'Progresīvs (%)',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: settings.speedToleranceMode == SpeedToleranceMode.percentage
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            if (settings.speedToleranceMode == SpeedToleranceMode.fixed) ...[
              const Text(
                'Statiska tolerance virs ierobežojuma',
                style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<int>(
                value: settings.speedTolerance,
                dropdownColor: const Color(0xFF1E222B),
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xFF1E222B),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                items: const [
                  DropdownMenuItem(value: 0, child: Text('+0 km/h (Stingrs - brīdināt tūlīt)')),
                  DropdownMenuItem(value: 3, child: Text('+3 km/h')),
                  DropdownMenuItem(value: 5, child: Text('+5 km/h')),
                  DropdownMenuItem(value: 10, child: Text('+10 km/h')),
                ],
                onChanged: (val) {
                  if (val != null) {
                    settings.setSpeedTolerance(val);
                  }
                },
              ),
            ] else ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Progresīvā tolerance:',
                    style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    '${settings.speedTolerancePercentage.toStringAsFixed(1)}%',
                    style: const TextStyle(color: Color(0xFF5E9CFF), fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Slider(
                value: settings.speedTolerancePercentage.clamp(1.0, 15.0),
                min: 1.0,
                max: 15.0,
                divisions: 28,
                label: '${settings.speedTolerancePercentage.toStringAsFixed(1)}%',
                activeColor: const Color(0xFF2E66FF),
                onChanged: (val) => settings.setSpeedTolerancePercentage(val),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [3.0, 5.0, 7.0, 10.0].map((preset) {
                  final isSelected = (settings.speedTolerancePercentage - preset).abs() < 0.1;
                  return ChoiceChip(
                    label: Text('${preset.toInt()}%${preset == 5.0 ? ' (Ieteicams)' : ''}'),
                    selected: isSelected,
                    selectedColor: const Color(0xFF2E66FF),
                    backgroundColor: const Color(0xFF1E222B),
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : Colors.white70,
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    onSelected: (_) => settings.setSpeedTolerancePercentage(preset),
                  );
                }).toList(),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E222B),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF2C323F)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFF5E9CFF)),
                        SizedBox(width: 6),
                        Text(
                          'Piemērs ar pašreizējo procentu:',
                          style: TextStyle(color: Color(0xFF5E9CFF), fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _buildProgressiveExampleRow(20, 'dzīvojamā zona', settings.speedTolerancePercentage),
                    _buildProgressiveExampleRow(30, '30 km/h zona', settings.speedTolerancePercentage),
                    _buildProgressiveExampleRow(50, 'pilsētas iela', settings.speedTolerancePercentage),
                    _buildProgressiveExampleRow(90, 'šoseja', settings.speedTolerancePercentage),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
            const Text(
              'Ceļu un pagalmu piesaistes rādiusi (metri)',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            const Text(
              'Pielāgojiet meklēšanas attālumu ap sevi tuvākajai ielai vai pagalmam. Pieskarieties skaitlim, lai ievadītu precīzu vērtību.',
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
            const SizedBox(height: 12),
            _buildRadiusTile(
              context: context,
              title: 'Ielu meklēšanas rādiuss',
              subtitle: 'Ieteicamais noklusējums: 40 m. Izmanto galveno un nosaukto ielu noteikšanai.',
              value: settings.roadSearchRadiusMeters,
              min: 10,
              max: 150,
              defaultValue: 40.0,
              onChanged: (val) => settings.setRoadSearchRadiusMeters(val),
            ),
            const SizedBox(height: 12),
            _buildRadiusTile(
              context: context,
              title: 'Pagalmu un dzīvojamo zonu rādiuss',
              subtitle: 'Ieteicamais noklusējums: 15 m. Izmanto pagalma brauktuvēm un dzīvojamajām zonām (20 km/h).',
              value: settings.courtyardSearchRadiusMeters,
              min: 5,
              max: 40,
              defaultValue: 15.0,
              onChanged: (val) => settings.setCourtyardSearchRadiusMeters(val),
            ),
            const SizedBox(height: 24),
            const Text(
              'GPS stabilitātes un krustojumu filtri',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            const Text(
              'Pielāgojiet aiztures un histerēzes sliekšņus, lai novērstu viltus paziņojumus un spamu krustojumos vai vāja GPS signāla brīžos.',
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
            const SizedBox(height: 12),
            _buildCountTile(
              context: context,
              title: 'Ielas maiņas apstiprinājumu skaits',
              subtitle: 'Ieteicamais: 4 punkti (~4 sek). Novērš šķērsojamo ielu spamu krustojumos.',
              value: settings.streetChangeConfirmations,
              min: 1,
              max: 10,
              defaultValue: 4,
              unit: 'punkti',
              onChanged: (val) => settings.setStreetChangeConfirmations(val),
            ),
            const SizedBox(height: 12),
            _buildCountTile(
              context: context,
              title: 'Ātruma atcelšanas apstiprinājumi',
              subtitle: 'Ieteicamais: 4 punkti. Novērš 50 km/h mirgošanu uz vienas ielas posmiem.',
              value: settings.speedRestorationConfirmations,
              min: 1,
              max: 10,
              defaultValue: 4,
              unit: 'punkti',
              onChanged: (val) => settings.setSpeedRestorationConfirmations(val),
            ),
            const SizedBox(height: 12),
            _buildCountTile(
              context: context,
              title: 'Vienvirziena ielas beigu apstiprinājumi',
              subtitle: 'Ieteicamais: 3 punkti. Novērš kļūdainus "Vienvirziena iela ir beigusies" krustojumos.',
              value: settings.oneWayExitConfirmations,
              min: 1,
              max: 10,
              defaultValue: 3,
              unit: 'punkti',
              onChanged: (val) => settings.setOneWayExitConfirmations(val),
            ),
            const SizedBox(height: 12),
            _buildSwitch(
              title: 'Prioritizēt velosipēdu ceļus un ietves',
              subtitle: 'Piemērots braukšanai ar velosipēdu vai skrejriteni, lai asistents nepiesietu auto ceļiem.',
              value: settings.prioritizePedestrianAndCycleways,
              onChanged: (val) => settings.setPrioritizePedestrianAndCycleways(val),
            ),
            _buildSwitch(
              title: 'Filtrēt veco GPS kešu starta brīdī',
              subtitle: 'Noraida vēsturiskos GPS datus no ierīces atmiņas, novēršot kļūdainus starta paziņojumus.',
              value: settings.filterStaleGpsFixes,
              onChanged: (val) => settings.setFilterStaleGpsFixes(val),
            ),
            if (settings.filterStaleGpsFixes) ...[
              const SizedBox(height: 8),
              _buildCountTile(
                context: context,
                title: 'Veco GPS punktu noilguma slieksnis',
                subtitle: 'Ieteicamais: 5 sek. Punkti ar lielāku laika nobīdi no pašreizējā brīža tiek noraidīti.',
                value: settings.staleGpsTimeoutSeconds,
                min: 1,
                max: 30,
                defaultValue: 5,
                unit: 'sek',
                onChanged: (val) => settings.setStaleGpsTimeoutSeconds(val),
              ),
            ],
            const SizedBox(height: 24),
            const Text(
              'Sistēmas iestatījumi',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildSwitch(
              title: 'Automātiska GPS palaišana',
              subtitle: 'Sākt GPS izsekošanu uzreiz pēc lietotnes atvēršanas.',
              value: settings.autoStartGps,
              onChanged: (val) => settings.setAutoStartGps(val),
            ),
            _buildSwitch(
              title: 'Neizslēgt ekrānu',
              subtitle: 'Uzturēt telefona ekrānu ieslēgtu, kamēr lietotne ir atvērta (Wakelock).',
              value: settings.keepScreenOn,
              onChanged: (val) => settings.setKeepScreenOn(val),
            ),
            const SizedBox(height: 24),
            const Text(
              'Brauciena datu ierakstīšana',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildSwitch(
              title: 'Ierakstīt GPX maršrutu',
              subtitle: 'Saglabā GPS koordinātas, ātrumu un ielas .gpx failā, ko var atvērt kartēs.',
              value: settings.recordGpx,
              onChanged: (val) => settings.setRecordGpx(val),
            ),
            _buildSwitch(
              title: 'Ierakstīt brīdinājumu žurnālu (.log)',
              subtitle: 'Saglabā visus saņemtos balss paziņojumus un ātruma trauksmes teksta failā.',
              value: settings.recordAlertLogs,
              onChanged: (val) => settings.setRecordAlertLogs(val),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.share_rounded, size: 18),
                    label: const Text('Eksportēt datus'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.cyan.withOpacity(0.2),
                      foregroundColor: Colors.cyanAccent,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () {
                      widget.assistantManager.tripRecorderService.shareRecordedFiles();
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.delete_outline_rounded, size: 18),
                    label: const Text('Dzēst datus'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent.withOpacity(0.1),
                      foregroundColor: Colors.redAccent,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () {
                      widget.assistantManager.tripRecorderService.deleteAllRecordedFiles();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Visi saglabātie braucienu faili ir dzēsti.')),
                      );
                    },
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildSwitch({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      activeColor: Colors.cyanAccent,
      title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 14)),
      subtitle: Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 12)),
      value: value,
      onChanged: onChanged,
    );
  }

  Widget _buildRadiusTile({
    required BuildContext context,
    required String title,
    required String subtitle,
    required double value,
    required double min,
    required double max,
    required double defaultValue,
    required ValueChanged<double> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E222B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2C323F)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
              InkWell(
                onTap: () => _showNumericInputDialog(
                  context: context,
                  title: title,
                  initialValue: value.round(),
                  min: min.toInt(),
                  max: max.toInt(),
                  onSaved: (val) => onChanged(val.toDouble()),
                ),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.cyanAccent.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.cyanAccent.withOpacity(0.5)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${value.round()} m',
                        style: const TextStyle(color: Colors.cyanAccent, fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.edit_outlined, color: Colors.cyanAccent, size: 14),
                    ],
                  ),
                ),
              ),
              if ((value - defaultValue).abs() > 0.5) ...[
                const SizedBox(width: 6),
                IconButton(
                  tooltip: 'Atjaunot ieteikto ($defaultValue m)',
                  icon: const Icon(Icons.restart_alt_rounded, color: Colors.white54, size: 18),
                  onPressed: () => onChanged(defaultValue),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 12)),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 4,
              activeTrackColor: Colors.cyanAccent,
              inactiveTrackColor: const Color(0xFF2C323F),
              thumbColor: Colors.cyanAccent,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
            ),
            child: Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              divisions: (max - min).toInt(),
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCountTile({
    required BuildContext context,
    required String title,
    required String subtitle,
    required int value,
    required int min,
    required int max,
    required int defaultValue,
    required String unit,
    required ValueChanged<int> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E222B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2C323F)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
              InkWell(
                onTap: () => _showNumericInputDialog(
                  context: context,
                  title: title,
                  initialValue: value,
                  min: min,
                  max: max,
                  onSaved: onChanged,
                ),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.cyanAccent.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.cyanAccent.withOpacity(0.5)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$value $unit',
                        style: const TextStyle(color: Colors.cyanAccent, fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.edit_outlined, color: Colors.cyanAccent, size: 14),
                    ],
                  ),
                ),
              ),
              if (value != defaultValue) ...[
                const SizedBox(width: 6),
                IconButton(
                  tooltip: 'Atjaunot ieteikto ($defaultValue $unit)',
                  icon: const Icon(Icons.restart_alt_rounded, color: Colors.white54, size: 18),
                  onPressed: () => onChanged(defaultValue),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 12)),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 4,
              activeTrackColor: Colors.cyanAccent,
              inactiveTrackColor: const Color(0xFF2C323F),
              thumbColor: Colors.cyanAccent,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
            ),
            child: Slider(
              value: value.toDouble().clamp(min.toDouble(), max.toDouble()),
              min: min.toDouble(),
              max: max.toDouble(),
              divisions: max - min,
              onChanged: (val) => onChanged(val.round()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressiveExampleRow(int speedLimit, String contextLabel, double percentage) {
    final tolerance = speedLimit * (percentage / 100.0);
    final warnSpeed = speedLimit + tolerance;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '$speedLimit km/h ($contextLabel)',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          Text(
            'brīdina pie > ${warnSpeed.toStringAsFixed(1)} km/h (+${tolerance.toStringAsFixed(1)})',
            style: const TextStyle(color: Color(0xFF8AB4F8), fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  void _showNumericInputDialog({
    required BuildContext context,
    required String title,
    required int initialValue,
    required int min,
    required int max,
    required ValueChanged<int> onSaved,
  }) {
    final controller = TextEditingController(text: initialValue.toString());
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E222B),
        title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Ievadiet attālumu metros ($min – $max m):', style: const TextStyle(color: Colors.white70, fontSize: 13)),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              autofocus: true,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                suffixText: 'm',
                suffixStyle: const TextStyle(color: Colors.cyanAccent),
                filled: true,
                fillColor: const Color(0xFF14171F),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Atcelt', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.cyanAccent,
              foregroundColor: Colors.black,
            ),
            onPressed: () {
              final parsed = int.tryParse(controller.text.trim());
              if (parsed != null && parsed >= min && parsed <= max) {
                onSaved(parsed);
                Navigator.pop(ctx);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Lūdzu ievadiet skaitli robežās no $min līdz $max')),
                );
              }
            },
            child: const Text('Saglabāt'),
          ),
        ],
      ),
    );
  }

  Widget _buildFileInfoCard(bool hasFile) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E222B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasFile ? Colors.green.shade700 : const Color(0xFF2C323F),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (hasFile ? Colors.greenAccent : Colors.orangeAccent).withAlpha(40),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  hasFile ? Icons.map_rounded : Icons.cloud_off_rounded,
                  color: hasFile ? Colors.greenAccent : Colors.orangeAccent,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Latvijas PMTiles bezsaistes karte',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hasFile ? 'Aktīva & gatava bezsaistei' : 'Karte nav lejupielādēta',
                      style: TextStyle(
                        color: hasFile ? Colors.greenAccent : Colors.orangeAccent,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Text(
            'Nodrošina tūlītējus ātruma ierobežojumu un vienvirziena ielu datus no OpenStreetMap vektorslāņiem (transportation) bez interneta savienojuma.',
            style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.3),
          ),
          const Divider(color: Color(0xFF2C323F), height: 24),
          if (hasFile && _fileInfo != null) ...[
            _buildMetaRow(Icons.insert_drive_file_outlined, 'Faila nosaukums', MapDownloaderService.mapFileName),
            const SizedBox(height: 8),
            _buildMetaRow(Icons.data_usage_rounded, 'Faila izmērs', _fileInfo!.formattedSize),
            const SizedBox(height: 8),
            _buildMetaRow(Icons.schedule_rounded, 'Pēdējoreiz atjaunināts', _fileInfo!.formattedDate),
          ] else ...[
            const Row(
              children: [
                Icon(Icons.info_outline_rounded, color: Colors.white38, size: 16),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Lejupielādējiet karti, lai navigācija darbotos pilnīgi bezsaistē.',
                    style: TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMetaRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.cyanAccent),
        const SizedBox(width: 8),
        Text('$label: ', style: const TextStyle(color: Colors.white60, fontSize: 13)),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildProgressSection(DownloadProgress progress) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E222B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: progress.isFailed ? Colors.redAccent : Colors.cyan.shade700,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                progress.isFailed
                    ? Icons.error_outline_rounded
                    : (progress.isCancelled ? Icons.cancel_outlined : Icons.downloading_rounded),
                color: progress.isFailed
                    ? Colors.redAccent
                    : (progress.isCancelled ? Colors.amberAccent : Colors.cyanAccent),
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  progress.isDownloading
                      ? 'Lejupielādē karti: ${progress.percentage.toStringAsFixed(1)}%'
                      : (progress.isFailed ? 'Lejupielādes kļūda' : 'Lejupielāde atcelta'),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
              if (progress.isDownloading)
                TextButton(
                  onPressed: () => _downloader.cancelDownload(),
                  child: const Text('Atcelt', style: TextStyle(color: Colors.redAccent, fontSize: 12)),
                ),
            ],
          ),
          if (progress.isDownloading) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progress.progress >= 0 ? progress.progress : null,
                minHeight: 8,
                backgroundColor: const Color(0xFF2C323F),
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.cyanAccent),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${progress.formattedReceived} no ${progress.formattedTotal}',
              style: const TextStyle(color: Colors.white54, fontSize: 11, fontFamily: 'monospace'),
            ),
          ],
          if (progress.isFailed && progress.errorMessage != null) ...[
            const SizedBox(height: 6),
            Text(
              progress.errorMessage!,
              style: const TextStyle(color: Colors.redAccent, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDownloadButton(bool isDownloading) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: isDownloading ? const Color(0xFF2A3444) : const Color(0xFF1976D2),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 4,
        ),
        icon: isDownloading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white70),
              )
            : const Icon(Icons.cloud_download_rounded, size: 22),
        label: const Text(
          'Lejupielādēt / Atjaunināt Latvijas bezsaistes karti',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        onPressed: isDownloading ? null : _startDownload,
      ),
    );
  }

  Widget _buildAdvancedSettings(bool isDownloading) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => setState(() => _showAdvancedUrl = !_showAdvancedUrl),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Icon(
                  _showAdvancedUrl ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                  color: Colors.white54,
                  size: 20,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Papildu iestatījumi (PMTiles lejupielādes URL)',
                  style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ),
        if (_showAdvancedUrl) ...[
          const SizedBox(height: 8),
          TextField(
            controller: _urlController,
            enabled: !isDownloading,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: InputDecoration(
              labelText: 'PMTiles avota URL',
              labelStyle: const TextStyle(color: Colors.white54),
              hintText: 'https://...',
              hintStyle: const TextStyle(color: Colors.white24),
              filled: true,
              fillColor: const Color(0xFF1E222B),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Colors.cyanAccent),
              ),
              suffixIcon: IconButton(
                icon: const Icon(Icons.refresh_rounded, size: 18, color: Colors.white54),
                tooltip: 'Atiestatīt uz noklusēto URL',
                onPressed: () => _urlController.text = MapDownloaderService.defaultUrl,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
