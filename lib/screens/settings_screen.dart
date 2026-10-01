import 'package:flutter/material.dart';
import '../services/driving_assistant_manager.dart';
import '../services/map_downloader_service.dart';
import '../services/settings_service.dart';
import '../services/tts_service.dart';
import 'about_screen.dart';

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
  List<String> _availableEngines = [];
  List<Map<String, String>> _availableVoices = [];
  bool _isLoadingTtsEngines = false;
  bool _isTestingVoice = false;

  MapDownloaderService get _downloader => widget.assistantManager.mapDownloaderService;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(text: MapDownloaderService.defaultUrl);
    _downloader.addListener(_onDownloaderChanged);
    _loadFileMetadata();
    _loadTtsEnginesAndVoices();
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

  Future<void> _loadTtsEnginesAndVoices() async {
    setState(() => _isLoadingTtsEngines = true);
    try {
      final tts = widget.assistantManager.ttsService;
      final engines = await tts.getAvailableEngines();
      final voices = await tts.getLatvianVoices();
      if (mounted) {
        setState(() {
          _availableEngines = engines;
          _availableVoices = voices;
          _isLoadingTtsEngines = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading TTS engines/voices in UI: $e');
      if (mounted) {
        setState(() => _isLoadingTtsEngines = false);
      }
    }
  }

  Future<void> _onEngineChanged(String? newEngine, SettingsService settings) async {
    await settings.setTtsEngine(newEngine);
    await settings.setTtsVoice(name: null, locale: null);
    await widget.assistantManager.ttsService.applySettings(
      engine: newEngine,
      voiceName: null,
      voiceLocale: null,
    );
    final voices = await widget.assistantManager.ttsService.getLatvianVoices();
    if (mounted) {
      setState(() {
        _availableVoices = voices;
      });
    }
  }

  Future<void> _testVoice() async {
    setState(() => _isTestingVoice = true);
    try {
      await widget.assistantManager.ttsService.testVoice();
    } finally {
      if (mounted) {
        setState(() => _isTestingVoice = false);
      }
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
              title: 'Audio fokuss un mūzikas pieklusināšana (Ducking)',
              subtitle: 'Paziņojumu laikā automātiski pieklusina Spotify / radio un citus fona audio avotus.',
              value: settings.audioDucking,
              onChanged: (val) => settings.setAudioDucking(val),
            ),
            _buildSwitch(
              title: 'Dinamiskās frāzes',
              subtitle: 'Izrunā teikumus atbilstoši ceļa situācijai un izvēlētajam stilam.',
              value: settings.useDynamicPhrases,
              onChanged: (val) => settings.setUseDynamicPhrases(val),
            ),
            if (settings.useDynamicPhrases) ...[
              const SizedBox(height: 12),
              const Text(
                'Balss paziņojumu stils',
                style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<VoiceAlertStyle>(
                value: settings.voiceAlertStyle,
                dropdownColor: const Color(0xFF1E222B),
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xFF1E222B),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                items: const [
                  DropdownMenuItem(
                    value: VoiceAlertStyle.concise,
                    child: Text('Lakoniskais ("Kuldīgas iela. Vienvirziena iela.")'),
                  ),
                  DropdownMenuItem(
                    value: VoiceAlertStyle.detailed,
                    child: Text('Paplašinātais ("Nogriezāties uz Kuldīgas iela...")'),
                  ),
                ],
                onChanged: (val) {
                  if (val != null) {
                    settings.setVoiceAlertStyle(val);
                  }
                },
              ),
              const SizedBox(height: 8),
            ],
            _buildSwitch(
              title: 'Paziņot ielu nosaukumus',
              subtitle: 'Nosauc ielas nosaukumu pie katras krustojuma/ielas maiņas.',
              value: settings.announceStreetChanges,
              onChanged: (val) => settings.setAnnounceStreetChanges(val),
            ),
            const SizedBox(height: 12),
            _buildTtsSettingsCard(settings),
            const SizedBox(height: 12),
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
            _buildRadiusTile(
              context: context,
              title: 'Jaunas ielas apstiprināšanas distance (metros)',
              subtitle: 'Ieteicamais: 20 m. Lai asistents paziņotu jaunu ielu, pa to reāli jānobrauc vismaz šis attālums. Pie maza ātruma (skrejriteņi, velosipēdi) asistents automātiski adaptē distanci zibenīgai reakcijai.',
              value: settings.streetChangeDistanceMeters,
              min: 10,
              max: 80,
              defaultValue: 20.0,
              onChanged: (val) => settings.setStreetChangeDistanceMeters(val),
            ),
            const SizedBox(height: 12),
            _buildCountTile(
              context: context,
              title: 'Ielas maiņas apstiprinājumu skaits',
              subtitle: 'Ieteicamais: 3 punkti (~3 sek). Cik atsevišķiem GPS punktiem jāapstiprina jaunā iela.',
              value: settings.streetChangeConfirmations,
              min: 1,
              max: 10,
              defaultValue: 3,
              unit: 'punkti',
              onChanged: (val) => settings.setStreetChangeConfirmations(val),
            ),
            const SizedBox(height: 12),
            _buildSwitch(
              title: 'Adaptīva distance mazam ātrumam (skrejriteņi / velo)',
              subtitle: 'Automātiski samazina nepieciešamo distanci (15 m) un apstiprinājumu skaitu (2 punkti) pie ātruma līdz 25 km/h, lai pagrieziens tiktu paziņots uzreiz pēc manevra veikšanas.',
              value: settings.enableSpeedAdaptiveDistance,
              onChanged: (val) => settings.setEnableSpeedAdaptiveDistance(val),
            ),
            const SizedBox(height: 12),
            _buildCountTile(
              context: context,
              title: 'Ātruma atcelšanas apstiprinājumi',
              subtitle: 'Ieteicamais: 1 punkts (zibenīga atcelšana pēc CSN). Novērš aizturi pēc krustojumiem.',
              value: settings.speedRestorationConfirmations,
              min: 1,
              max: 10,
              defaultValue: 1,
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
            const SizedBox(height: 24),
            const Text(
              'Apsteidzošie brīdinājumi un bīstamības (Lookahead)',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildSwitch(
              title: 'Apsteidzošā ātruma zonu noteikšana (Lookahead)',
              subtitle: 'Savlaicīgi paziņo par gaidāmo zemāka ātruma zonu (30 vai 20 km/h) 50–100m pirms iebraukšanas tajā.',
              value: settings.lookaheadAlerts,
              onChanged: (val) => settings.setLookaheadAlerts(val),
            ),
            if (settings.lookaheadAlerts) ...[
              const SizedBox(height: 8),
              _buildRadiusTile(
                context: context,
                title: 'Apsteidzošā skenēšanas bāzes distance',
                subtitle: 'Ieteicamais: 70 m. Distance uz priekšu braukšanas trajektorijā (ātrumā dinamiskā no 35 līdz 120m).',
                value: settings.lookaheadDistanceMeters,
                min: 30,
                max: 150,
                defaultValue: 70,
                onChanged: (val) => settings.setLookaheadDistanceMeters(val),
              ),
            ],
            _buildSwitch(
              title: 'Luksoforu brīdinājumi',
              subtitle: 'Savlaicīgi paziņo par tuvošanos luksoforam.',
              value: settings.lookaheadTrafficLights,
              onChanged: (val) => settings.setLookaheadTrafficLights(val),
            ),
            _buildSwitch(
              title: '"Dodiet ceļu" / STOP zīmes',
              subtitle: 'Paziņo par tuvošanos "Dodiet ceļu" vai STOP zīmēm pirms krustojumiem.',
              value: settings.lookaheadGiveWay,
              onChanged: (val) => settings.setLookaheadGiveWay(val),
            ),
            _buildSwitch(
              title: 'Krustojumu brīdinājumi',
              subtitle: 'Atgādina par galveno ceļu, tās virziena maiņu vai vienādas nozīmes krustojumiem.',
              value: settings.lookaheadIntersections,
              onChanged: (val) => settings.setLookaheadIntersections(val),
            ),
            _buildSwitch(
              title: 'Ātrumvaļņu brīdinājumi',
              subtitle: 'Savlaicīgi paziņo par tuvošanos ātrumvaļņiem vai paaugstinātām pārejām.',
              value: settings.trafficCalmingAlerts,
              onChanged: (val) => settings.setTrafficCalmingAlerts(val),
            ),
            _buildSwitch(
              title: 'Gājēju pārejas taisnos posmos',
              subtitle: 'Savlaicīgs brīdinājums par gājēju pārejām ārpus krustojumiem.',
              value: settings.lookaheadPedestrianCrossings,
              onChanged: (val) => settings.setLookaheadPedestrianCrossings(val),
            ),
            _buildSwitch(
              title: 'Fotoradaru brīdinājumi',
              subtitle: 'Paziņo par stacionārajiem ātruma kontroles radariem un to atļauto ātrumu.',
              value: settings.speedCameraAlerts,
              onChanged: (val) => settings.setSpeedCameraAlerts(val),
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
            if (settings.recordAlertLogs) ...[
              Padding(
                padding: const EdgeInsets.only(left: 16.0),
                child: _buildSwitch(
                  title: 'Ierakstīt žurnālu arī testa braucieniem (GPX)',
                  subtitle: 'Automātiski izveido .log failu, atskaņojot virtuālos GPX failus vai iebūvēto testa maršrutu.',
                  value: settings.recordVirtualAlertLogs,
                  onChanged: (val) => settings.setRecordVirtualAlertLogs(val),
                ),
              ),
            ],
            const SizedBox(height: 16),
            // Big Diagnostic Bundle Button
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0D47A1), Color(0xFF00838F)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.cyanAccent.withOpacity(0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ElevatedButton.icon(
                icon: const Icon(Icons.send_rounded, size: 22, color: Colors.white),
                label: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Nosūtīt pēdējo braucienu un iestatījumus analīzei',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Apvieno pēdējo GPX, brīdinājumu .log un iestatījumus .json vienā pakotnē',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                ),
                onPressed: () async {
                  try {
                    await widget.assistantManager.tripRecorderService.exportDiagnosticBundle(settings);
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Kļūda sagatavojot pakotni: $e')),
                      );
                    }
                  }
                },
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Iestatījumu konfigurācijas pārvaldība (JSON)',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            const Text(
              'Eksportējiet savus pielāgotos iestatījumus drošībai vai importējiet gatavu konfigurāciju.',
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.file_upload_outlined, size: 18),
                    label: const Text('Eksportēt .json'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.cyan.withOpacity(0.18),
                      foregroundColor: Colors.cyanAccent,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () async {
                      try {
                        await widget.assistantManager.tripRecorderService.exportSettingsFile(settings);
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Neizdevās eksportēt iestatījumus: $e')),
                          );
                        }
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.file_download_outlined, size: 18),
                    label: const Text('Importēt .json'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo.withOpacity(0.25),
                      foregroundColor: const Color(0xFF8AB4F8),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () => _showImportSettingsDialog(context, settings),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Text(
              'Braucienu vēstures faili',
              style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.share_rounded, size: 18),
                    label: const Text('Visi ieraksti'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white70,
                      side: const BorderSide(color: Color(0xFF2C323F)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () {
                      widget.assistantManager.tripRecorderService.shareRecordedFiles();
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.delete_outline_rounded, size: 18),
                    label: const Text('Dzēst visus'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                      side: BorderSide(color: Colors.redAccent.withOpacity(0.4)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          backgroundColor: const Color(0xFF1E222B),
                          title: const Text('Dzēst visus braucienu failus?', style: TextStyle(color: Colors.white)),
                          content: const Text(
                            'Visi lokāli saglabātie .gpx un .log faili tiks neatgriezeniski dzēsti.',
                            style: TextStyle(color: Colors.white70),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('Atcelt', style: TextStyle(color: Colors.white54)),
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('Dzēst'),
                            ),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        await widget.assistantManager.tripRecorderService.deleteAllRecordedFiles();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Visi saglabātie braucienu faili ir dzēsti.')),
                          );
                        }
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Divider(color: Color(0xFF2C323F)),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blueAccent.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.info_outline_rounded, color: Color(0xFF8AB4F8), size: 22),
              ),
              title: const Text('Par lietotni (About)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              subtitle: const Text('Versija ${SettingsService.appVersion} • Funkcijas, atvērtā koda licences un privātums', style: TextStyle(color: Colors.white54, fontSize: 12)),
              trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.white38),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AboutScreen()),
                );
              },
            ),
            const SizedBox(height: 16),
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
          if (value < 15.0) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: Colors.amberAccent, size: 14),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'Šaurs rādiuss (<15 m) var izraisīt ceļa pazaudēšanu manevrējot vai braucot ar skrejriteni.',
                    style: TextStyle(color: Colors.amberAccent.shade100, fontSize: 11),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _showImportSettingsDialog(BuildContext context, SettingsService settings) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E222B),
        title: const Text('Importēt iestatījumus', style: TextStyle(color: Colors.white, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Ielīmējiet iestatījumu JSON tekstu zemāk:',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLines: 8,
              style: const TextStyle(color: Colors.white, fontSize: 12, fontFamily: 'monospace'),
              decoration: InputDecoration(
                hintText: '{\n  "road_search_radius_meters": 40.0,\n  ...\n}',
                hintStyle: const TextStyle(color: Colors.white24, fontSize: 12),
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
              backgroundColor: const Color(0xFF2E66FF),
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              final text = controller.text.trim();
              if (text.isEmpty) return;
              final success = await settings.importJsonString(text);
              if (ctx.mounted) {
                Navigator.pop(ctx);
              }
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      success
                          ? 'Iestatījumi veiksmīgi importēti un piemēroti!'
                          : 'Kļūda importējot iestatījumus: nederīgs JSON formāts.',
                    ),
                    backgroundColor: success ? Colors.green.shade800 : Colors.redAccent,
                  ),
                );
              }
            },
            child: const Text('Importēt un piemērot'),
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

  Widget _buildTtsSettingsCard(SettingsService settings) {
    final engineItems = <String?>[null];
    for (final e in _availableEngines) {
      if (!engineItems.contains(e)) engineItems.add(e);
    }
    if (settings.ttsEngine != null && !engineItems.contains(settings.ttsEngine)) {
      engineItems.add(settings.ttsEngine);
    }

    final voiceItems = <String?>[null];
    for (final v in _availableVoices) {
      final name = v['name'];
      if (name != null && name.isNotEmpty && !voiceItems.contains(name)) {
        voiceItems.add(name);
      }
    }
    if (settings.ttsVoiceName != null && !voiceItems.contains(settings.ttsVoiceName)) {
      voiceItems.add(settings.ttsVoiceName);
    }

    return Container(
      padding: const EdgeInsets.all(14),
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
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF2E66FF).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.record_voice_over_rounded, color: Color(0xFF5B8DEF), size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Runas sintēze un balss (TTS)',
                      style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Dzinējs, balss, ātrums un tonis',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: _isLoadingTtsEngines
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF5B8DEF)),
                      )
                    : const Icon(Icons.refresh_rounded, color: Colors.white70, size: 20),
                tooltip: 'Pārlādēt dzinējus un balsis',
                onPressed: _isLoadingTtsEngines ? null : _loadTtsEnginesAndVoices,
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Text(
            'TTS Runas dzinējs',
            style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          DropdownButtonFormField<String?>(
            key: ValueKey('engine_${settings.ttsEngine}'),
            initialValue: settings.ttsEngine,
            dropdownColor: const Color(0xFF1B1E24),
            style: const TextStyle(color: Colors.white, fontSize: 13),
            isExpanded: true,
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0xFF14171C),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
            items: engineItems.map((engine) {
              return DropdownMenuItem<String?>(
                value: engine,
                child: Text(
                  engine == null ? 'Sistēmas noklusētais dzinējs' : TtsService.formatEngineName(engine),
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }).toList(),
            onChanged: (newEngine) => _onEngineChanged(newEngine, settings),
          ),
          const SizedBox(height: 14),
          const Text(
            'Latviešu valodas balss',
            style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          if (_availableVoices.isNotEmpty) ...[
            DropdownButtonFormField<String?>(
              key: ValueKey('voice_${settings.ttsVoiceName}'),
              initialValue: settings.ttsVoiceName,
              dropdownColor: const Color(0xFF1B1E24),
              style: const TextStyle(color: Colors.white, fontSize: 13),
              isExpanded: true,
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFF14171C),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
              items: voiceItems.map((voiceName) {
                if (voiceName == null) {
                  return const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('Dzinēja noklusētā balss', overflow: TextOverflow.ellipsis),
                  );
                }
                final matched = _availableVoices.firstWhere(
                  (v) => v['name'] == voiceName,
                  orElse: () => {'name': voiceName, 'locale': 'lv-LV'},
                );
                final locale = matched['locale'] ?? '';
                return DropdownMenuItem<String?>(
                  value: voiceName,
                  child: Text(
                    locale.isNotEmpty ? '$voiceName ($locale)' : voiceName,
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
              onChanged: (voiceName) {
                final matched = _availableVoices.firstWhere(
                  (v) => v['name'] == voiceName,
                  orElse: () => {},
                );
                settings.setTtsVoice(
                  name: voiceName,
                  locale: matched['locale'] ?? 'lv-LV',
                );
                widget.assistantManager.ttsService.applySettings(
                  voiceName: voiceName,
                  voiceLocale: matched['locale'] ?? 'lv-LV',
                );
              },
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF14171C),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF2C323F)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline_rounded, color: Colors.amber, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Šim dzinējam nav atsevišķu LV balsu saraksta. Tiks izmantota sistēmas noklusētā latviešu runa.',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Runas ātrums',
                style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
              ),
              Text(
                '${settings.ttsSpeechRate.toStringAsFixed(2)}x',
                style: const TextStyle(color: Color(0xFF5B8DEF), fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: const Color(0xFF2E66FF),
              inactiveTrackColor: const Color(0xFF2C323F),
              thumbColor: const Color(0xFF5B8DEF),
              overlayColor: const Color(0xFF2E66FF).withValues(alpha: 0.2),
            ),
            child: Slider(
              value: settings.ttsSpeechRate.clamp(0.2, 1.2),
              min: 0.2,
              max: 1.2,
              divisions: 20,
              onChanged: (val) {
                settings.setTtsSpeechRate(val);
                widget.assistantManager.ttsService.applySettings(speechRate: val);
              },
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Balss tonis (Pitch)',
                style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
              ),
              Text(
                '${settings.ttsPitch.toStringAsFixed(2)}x',
                style: const TextStyle(color: Color(0xFF5B8DEF), fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: const Color(0xFF2E66FF),
              inactiveTrackColor: const Color(0xFF2C323F),
              thumbColor: const Color(0xFF5B8DEF),
              overlayColor: const Color(0xFF2E66FF).withValues(alpha: 0.2),
            ),
            child: Slider(
              value: settings.ttsPitch.clamp(0.5, 1.5),
              min: 0.5,
              max: 1.5,
              divisions: 20,
              onChanged: (val) {
                settings.setTtsPitch(val);
                widget.assistantManager.ttsService.applySettings(pitch: val);
              },
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E66FF),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: _isTestingVoice
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.volume_up_rounded, size: 20),
              label: Text(_isTestingVoice ? 'Atskaņo...' : 'Pārbaudīt balsi'),
              onPressed: _isTestingVoice ? null : _testVoice,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF131720),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF283449)),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.lightbulb_outline_rounded, color: Color(0xFF64B5F6), size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Padoms: Visdabiskākajai latviešu valodas izrunai ieteicams Google Play instalēt lietotni "Tildes Balss". Pēc instalēšanas nospiediet pārlādēšanas ikonu un atlasiet Tildi.',
                    style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.35),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
