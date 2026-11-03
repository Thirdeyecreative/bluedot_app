import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/api_config.dart';
import '../constants/app_colors.dart';
import '../../features/home/providers/home_provider.dart';

/// Interactive modal allowing developers and testers to inspect, test,
/// and switch the backend server target at runtime without recompilation.
class ServerSettingsModal extends ConsumerStatefulWidget {
  const ServerSettingsModal({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const ServerSettingsModal(),
    );
  }

  @override
  ConsumerState<ServerSettingsModal> createState() => _ServerSettingsModalState();
}

class _ServerSettingsModalState extends ConsumerState<ServerSettingsModal> {
  late final TextEditingController _customUrlController;
  late String _selectedUrl;
  bool _isTesting = false;
  ServerHealthResult? _healthResult;

  final List<({String title, String subtitle, String url, IconData icon})> _presets = [
    (
      title: 'Local Wi-Fi PC',
      subtitle: 'For physical phone on Wi-Fi (192.168.1.7:8000)',
      url: 'http://${ApiConfig.currentLanIp}:8000',
      icon: Icons.wifi_rounded,
    ),
    (
      title: 'Localhost',
      subtitle: 'For Web, Windows Desktop, or USB adb reverse',
      url: 'http://127.0.0.1:8000',
      icon: Icons.laptop_windows_rounded,
    ),
    (
      title: 'Android Emulator',
      subtitle: 'Loopback alias for Android Studio emulator',
      url: 'http://10.0.2.2:8000',
      icon: Icons.phone_android_rounded,
    ),
    (
      title: 'Cloud Staging',
      subtitle: 'Cloud Run staging backend',
      url: ApiConfig.stagingUrl,
      icon: Icons.cloud_queue_rounded,
    ),
    (
      title: 'Cloud Production',
      subtitle: 'Live Cloud Run production cluster',
      url: ApiConfig.productionUrl,
      icon: Icons.rocket_launch_rounded,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _selectedUrl = ApiConfig.baseUrl;
    _customUrlController = TextEditingController(text: _selectedUrl);
    _runHealthCheck(_selectedUrl);
  }

  @override
  void dispose() {
    _customUrlController.dispose();
    super.dispose();
  }

  Future<void> _runHealthCheck(String targetUrl) async {
    setState(() {
      _isTesting = true;
      _healthResult = null;
    });

    final res = await ApiConfig.checkServerHealth(targetUrl);
    if (!mounted) return;
    setState(() {
      _isTesting = false;
      _healthResult = res;
    });
  }

  Future<void> _applyAndSave() async {
    final finalUrl = _selectedUrl.trim();
    await ApiConfig.setRuntimeBaseUrl(finalUrl);

    // Invalidate home feed so it immediately fetches from the new server
    ref.invalidate(homeFeedProvider);
    ref.invalidate(blogsProvider);

    if (!mounted) return;
    Navigator.of(context).pop();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text('Active server set to: $finalUrl')),
          ],
        ),
        backgroundColor: AppColors.forestGreen,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final isCustom = !_presets.any((p) => p.url == _selectedUrl);

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 16, 20, 24 + bottomInset),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.borderLight,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue.withAlpha(20),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.dns_rounded, color: AppColors.primaryBlue, size: 22),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Server Connection Settings',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textDark),
                    ),
                    Text(
                      'Select or test the backend API destination',
                      style: TextStyle(fontSize: 12, color: AppColors.textMedium),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded, color: AppColors.textLight),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Health Status Banner
          _buildHealthStatusCard(),
          const SizedBox(height: 16),

          // Presets List
          const Text(
            'SELECT ENVIRONMENT',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textLight, letterSpacing: 1.1),
          ),
          const SizedBox(height: 8),

          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                ..._presets.map((preset) {
                  final isSelected = _selectedUrl == preset.url;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primaryBlue.withAlpha(12) : AppColors.surfaceCard,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSelected ? AppColors.primaryBlue : AppColors.borderLight,
                        width: isSelected ? 1.5 : 1.0,
                      ),
                    ),
                    child: ListTile(
                      dense: true,
                      leading: Icon(preset.icon, color: isSelected ? AppColors.primaryBlue : AppColors.textMedium),
                      title: Text(
                        preset.title,
                        style: TextStyle(
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                          color: isSelected ? AppColors.primaryBlue : AppColors.textDark,
                          fontSize: 14,
                        ),
                      ),
                      subtitle: Text(preset.subtitle, style: const TextStyle(fontSize: 11, color: AppColors.textMedium)),
                      trailing: isSelected
                          ? const Icon(Icons.check_circle_rounded, color: AppColors.primaryBlue, size: 20)
                          : null,
                      onTap: () {
                        setState(() {
                          _selectedUrl = preset.url;
                          _customUrlController.text = preset.url;
                        });
                        _runHealthCheck(preset.url);
                      },
                    ),
                  );
                }),

                // Custom URL Tile
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: isCustom ? AppColors.primaryBlue.withAlpha(12) : AppColors.surfaceCard,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isCustom ? AppColors.primaryBlue : AppColors.borderLight,
                      width: isCustom ? 1.5 : 1.0,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.edit_note_rounded, color: isCustom ? AppColors.primaryBlue : AppColors.textMedium),
                            const SizedBox(width: 12),
                            Text(
                              'Custom URL / IP',
                              style: TextStyle(
                                fontWeight: isCustom ? FontWeight.w700 : FontWeight.w600,
                                color: isCustom ? AppColors.primaryBlue : AppColors.textDark,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _customUrlController,
                          decoration: InputDecoration(
                            hintText: 'http://192.168.1.X:8000',
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.bolt_rounded, color: AppColors.primaryBlue),
                              tooltip: 'Ping Custom URL',
                              onPressed: () {
                                setState(() {
                                  _selectedUrl = _customUrlController.text.trim();
                                });
                                _runHealthCheck(_selectedUrl);
                              },
                            ),
                          ),
                          onChanged: (val) {
                            setState(() {
                              _selectedUrl = val.trim();
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isTesting ? null : () => _runHealthCheck(_selectedUrl),
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Test Ping'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: _applyAndSave,
                  icon: const Icon(Icons.check_rounded, size: 18),
                  label: const Text('Apply & Connect'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryBlue,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHealthStatusCard() {
    if (_isTesting) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.backgroundCream,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderLight),
        ),
        child: const Row(
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Checking server /health endpoint...',
                style: TextStyle(fontSize: 13, color: AppColors.textMedium),
              ),
            ),
          ],
        ),
      );
    }

    final res = _healthResult;
    if (res == null) return const SizedBox.shrink();

    final isOk = res.isHealthy;
    final color = isOk ? AppColors.forestGreen : AppColors.errorRed;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withAlpha(18),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(80)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(isOk ? Icons.check_circle_rounded : Icons.cancel_rounded, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isOk ? 'Server Online (${res.latencyMs} ms)' : 'Connection Failed',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: color),
                ),
                const SizedBox(height: 2),
                Text(
                  isOk
                      ? 'Endpoint /health responded with 200 OK.'
                      : '${res.message}\nEnsure backend server is running with --host 0.0.0.0 --port 8000',
                  style: TextStyle(fontSize: 11, color: color.withAlpha(220), height: 1.3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

