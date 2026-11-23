import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/api_config.dart';
import '../constants/app_colors.dart';
import '../../features/home/providers/home_provider.dart';

/// Interactive modal allowing developers and testers to inspect, test,
/// and switch the backend server target at runtime without recompilation.
class ServerSettingsModal extends ConsumerStatefulWidget {
  final VoidCallback? onClose;
  final ValueChanged<String>? onApplied;

  const ServerSettingsModal({
    super.key,
    this.onClose,
    this.onApplied,
  });

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
      subtitle: 'For physical phone or local network (${ApiConfig.currentLanIp}:8000)',
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
      subtitle: 'Loopback alias for Android Studio emulator (10.0.2.2:8000)',
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

    final res = await ApiConfig.checkServerHealthDetails(targetUrl);
    if (!mounted) return;
    setState(() {
      _isTesting = false;
      _healthResult = res;
    });
  }

  void _close() {
    if (widget.onClose != null) {
      widget.onClose!();
    } else if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _applyAndSave() async {
    final finalUrl = _selectedUrl.trim();
    await ApiConfig.setRuntimeBaseUrl(finalUrl);

    // Invalidate home feed and blogs so it immediately fetches from the new server
    ref.invalidate(homeFeedProvider);
    ref.invalidate(blogsProvider);

    if (!mounted) return;
    _close();

    if (widget.onApplied != null) {
      widget.onApplied!(finalUrl);
    }

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
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue.withAlpha(20),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.dns_rounded, color: AppColors.primaryBlue, size: 20),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Server Configuration',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark,
                      ),
                    ),
                    Text(
                      'Choose backend or enter custom IP:Port',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textMedium,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, color: AppColors.textMedium),
                onPressed: _close,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Health Check status banner
          _buildHealthStatusCard(),
          const SizedBox(height: 16),

          // Scrollable Presets
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                ..._presets.map((preset) {
                  final isSelected = _selectedUrl == preset.url;
                  return Card(
                    elevation: 0,
                    margin: const EdgeInsets.only(bottom: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: isSelected ? AppColors.primaryBlue : AppColors.borderLight,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    color: isSelected ? AppColors.primaryBlue.withAlpha(12) : AppColors.surfaceCard,
                    child: ListTile(
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                      leading: Icon(
                        preset.icon,
                        color: isSelected ? AppColors.primaryBlue : AppColors.textMedium,
                        size: 22,
                      ),
                      title: Text(
                        preset.title,
                        style: TextStyle(
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                          fontSize: 14,
                          color: AppColors.textDark,
                        ),
                      ),
                      subtitle: Text(
                        '${preset.subtitle}\n${preset.url}',
                        style: TextStyle(
                          fontSize: 11,
                          color: isSelected ? AppColors.primaryBlue : AppColors.textMedium,
                          height: 1.3,
                        ),
                      ),
                      trailing: Radio<String>(
                        value: preset.url,
                        groupValue: _selectedUrl,
                        activeColor: AppColors.primaryBlue,
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              _selectedUrl = val;
                              _customUrlController.text = val;
                            });
                            _runHealthCheck(val);
                          }
                        },
                      ),
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

                // Custom URL Card
                Card(
                  elevation: 0,
                  margin: const EdgeInsets.only(bottom: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: isCustom ? AppColors.primaryBlue : AppColors.borderLight,
                      width: isCustom ? 2 : 1,
                    ),
                  ),
                  color: isCustom ? AppColors.primaryBlue.withAlpha(12) : AppColors.surfaceCard,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.edit_road_rounded,
                              size: 20,
                              color: isCustom ? AppColors.primaryBlue : AppColors.textMedium,
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Custom Server URL',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textDark,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _customUrlController,
                          style: const TextStyle(fontSize: 13),
                          decoration: InputDecoration(
                            hintText: 'http://192.168.1.11:8000',
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
                      : '${res.message}\nEnsure backend server is running on 0.0.0.0:8000',
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
