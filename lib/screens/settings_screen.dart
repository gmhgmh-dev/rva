import 'package:flutter/material.dart';
import '../services/driving_assistant_manager.dart';
import '../services/map_downloader_service.dart';

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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
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
          ],
        ),
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
