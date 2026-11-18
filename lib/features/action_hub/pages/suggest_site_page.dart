import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/api_client.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../../core/widgets/in_app_camera_page.dart';
import '../data/action_repository.dart';

class SuggestSitePage extends ConsumerStatefulWidget {
  const SuggestSitePage({super.key});

  @override
  ConsumerState<SuggestSitePage> createState() => _SuggestSitePageState();
}

class _SuggestSitePageState extends ConsumerState<SuggestSitePage> {
  final _formKey = GlobalKey<FormState>();
  final _descController = TextEditingController();
  final List<File> _photos = [];
  Position? _position;
  bool _isSubmitting = false;
  bool _locationFetched = false;

  static const int _maxPhotos = 5;

  @override
  void initState() {
    super.initState();
    _getLocation();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showHowItWorksSheet();
    });
  }

  void _showHowItWorksSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _SiteSuggestionGuideSheet(),
    );
  }

  @override
  void dispose() {
    _descController.dispose();
    super.dispose();
  }

  Future<void> _getLocation() async {
    await Permission.locationWhenInUse.request();
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 8)),
      );
      setState(() {
        _position = pos;
        _locationFetched = true;
      });
    } catch (_) {
      setState(() => _locationFetched = true);
    }
  }

  Future<void> _searchLocation() async {
    final result = await showDialog<Position>(
      context: context,
      builder: (_) => const _LocationSearchDialog(),
    );
    if (result != null) {
      setState(() {
        _position = result;
        _locationFetched = true;
      });
    }
  }

  Future<void> _capturePhotos() async {
    final remaining = _maxPhotos - _photos.length;
    if (remaining <= 0) return;
    final shots = await openInAppCamera(
      context,
      maxImages: remaining,
      title: 'Photograph the Site',
    );
    if (shots.isNotEmpty) {
      setState(() => _photos.addAll(shots.take(remaining)));
    }
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_position == null) {
      AppFeedback.showError(
        context,
        'We couldn\'t get your location. Tap the refresh icon to try again.',
      );
      return;
    }
    setState(() => _isSubmitting = true);
    try {
      final result = await ref.read(actionRepositoryProvider).suggestSite(
            description: _descController.text.trim(),
            lat: _position!.latitude,
            lng: _position!.longitude,
            images: _photos,
          );
      if (!mounted) return;

      final message = result['message'] as String? ??
          'Our team will review your suggestion. You\'ll earn more XP when it\'s approved!';
      final awarded = result['points_awarded'];

      // Thank the contributor before returning to the Action Hub.
      await AppFeedback.showThankYou(
        context,
        title: 'Thank You! 🌱',
        message: message,
        xpLabel: (awarded is num && awarded > 0) ? '+$awarded XP earned' : null,
      );
      if (mounted) context.pop();
    } catch (e) {
      if (!mounted) return;
      // A 409 means this spot is already a suggestion/site — not a user error.
      // Reassure them it's being looked at rather than showing a red error.
      if (e is ApiException && e.statusCode == 409) {
        await AppFeedback.showThankYou(
          context,
          title: 'Already on Our Radar 🌍',
          message: 'Thanks for spotting this! This location is already under '
              'consideration — our team is reviewing it for proper use.',
        );
        if (mounted) context.pop();
      } else {
        AppFeedback.showError(context, e);
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Suggest a Restoration Site'),
        leading: const BackButton(),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline_rounded),
            tooltip: 'How it works',
            onPressed: _showHowItWorksSheet,
          ),
        ],
      ),
      body: SingleChildScrollView(
        // Bottom padding clears the floating nav bar.
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 130),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Info banner (tappable to view detailed guide)
              GestureDetector(
                onTap: _showHowItWorksSheet,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.forestGreen.withAlpha(20),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.forestGreen.withAlpha(60)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline_rounded, color: AppColors.forestGreen, size: 20),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Spotted a dry lake, empty plot, or degraded land? Suggest it for a future plantation drive — earn 5 XP now and 20 XP when approved!',
                          style: TextStyle(color: AppColors.forestGreen, fontSize: 13, height: 1.4),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(Icons.chevron_right_rounded, color: AppColors.forestGreen.withAlpha(150), size: 20),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Photo capture (in-app camera, up to _maxPhotos)
              Row(
                children: [
                  Text('Photos', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(width: 6),
                  Text('(${_photos.length}/$_maxPhotos)', style: const TextStyle(color: AppColors.textLight, fontSize: 13)),
                ],
              ),
              const SizedBox(height: 8),
              if (_photos.isEmpty)
                GestureDetector(
                  onTap: _capturePhotos,
                  child: Container(
                    height: 160,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceCard,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.borderLight, width: 1.5),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_a_photo_rounded, size: 40, color: AppColors.slateBlue.withAlpha(150)),
                        const SizedBox(height: 8),
                        const Text('Tap to take photos', style: TextStyle(color: AppColors.textMedium)),
                      ],
                    ),
                  ),
                )
              else
                SizedBox(
                  height: 110,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _photos.length + (_photos.length < _maxPhotos ? 1 : 0),
                    separatorBuilder: (_, _) => const SizedBox(width: 10),
                    itemBuilder: (_, i) {
                      // Trailing "add more" tile
                      if (i == _photos.length) {
                        return GestureDetector(
                          onTap: _capturePhotos,
                          child: Container(
                            width: 110,
                            height: 110,
                            decoration: BoxDecoration(
                              color: AppColors.surfaceCard,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppColors.borderLight, width: 1.5),
                            ),
                            child: const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_a_photo_rounded, color: AppColors.slateBlue),
                                SizedBox(height: 6),
                                Text('Add', style: TextStyle(color: AppColors.textMedium, fontSize: 12)),
                              ],
                            ),
                          ),
                        );
                      }
                      return Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: Image.file(_photos[i], width: 110, height: 110, fit: BoxFit.cover),
                          ),
                          Positioned(
                            top: 2,
                            right: 2,
                            child: GestureDetector(
                              onTap: () => setState(() => _photos.removeAt(i)),
                              child: Container(
                                decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                                padding: const EdgeInsets.all(3),
                                child: const Icon(Icons.close_rounded, color: Colors.white, size: 16),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              const SizedBox(height: 20),

              // GPS location
              Text('GPS Location', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.surfaceCard,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.borderLight),
                ),
                child: Row(
                  children: [
                    Icon(
                      _locationFetched ? ((_position != null) ? Icons.location_on_rounded : Icons.location_off_rounded) : Icons.my_location_rounded,
                      color: _position != null ? AppColors.forestGreen : AppColors.textLight,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _position != null
                            ? '${_position!.latitude.toStringAsFixed(5)}, ${_position!.longitude.toStringAsFixed(5)}'
                            : _locationFetched
                                ? 'Could not get location'
                                : 'Fetching location...',
                        style: TextStyle(color: _position != null ? AppColors.textDark : AppColors.textLight, fontSize: 13),
                      ),
                    ),
                    if (!_locationFetched) const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                    if (_locationFetched) ...[
                      IconButton(
                        icon: const Icon(Icons.search_rounded, color: AppColors.primaryBlue, size: 20),
                        tooltip: 'Search for a location manually',
                        onPressed: _searchLocation,
                      ),
                      IconButton(
                        icon: const Icon(Icons.my_location_rounded, color: AppColors.primaryBlue, size: 20),
                        tooltip: 'Use current GPS location',
                        onPressed: _getLocation,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Description
              Text('Description', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _descController,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: 'Describe the site — why is it suitable for restoration? What type of land is it?',
                ),
                validator: (v) => (v == null || v.trim().length < 20) ? 'Please provide at least 20 characters' : null,
              ),
              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _isSubmitting ? null : _submit,
                  icon: _isSubmitting
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.send_rounded),
                  label: const Text('Submit Site Suggestion'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LocationSearchDialog extends StatefulWidget {
  const _LocationSearchDialog();
  @override
  State<_LocationSearchDialog> createState() => _LocationSearchDialogState();
}

class _LocationSearchDialogState extends State<_LocationSearchDialog> {
  final _controller = TextEditingController();
  List<dynamic> _results = [];
  bool _searching = false;
  String? _error;

  Future<void> _search() async {
    final query = _controller.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _searching = true;
      _error = null;
    });

    try {
      final res = await http.get(Uri.parse(
          'https://nominatim.openstreetmap.org/search?format=json&q=${Uri.encodeComponent(query)}&limit=5'));
      
      if (res.statusCode == 200) {
        if (mounted) setState(() => _results = json.decode(res.body));
      } else {
        if (mounted) setState(() => _error = 'Failed to load results.');
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Network error. Please try again.');
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Search Location', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _search(),
              decoration: InputDecoration(
                hintText: 'Enter city or landmark...',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search_rounded),
                  onPressed: _search,
                ),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),
            if (_searching)
              const CircularProgressIndicator()
            else if (_error != null)
              Text(_error!, style: const TextStyle(color: Colors.red))
            else if (_results.isEmpty)
              const Text('No results', style: TextStyle(color: Colors.grey))
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 250),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _results.length,
                  separatorBuilder: (_, __) => const Divider(),
                  itemBuilder: (_, i) {
                    final item = _results[i];
                    return ListTile(
                      title: Text(item['display_name'] ?? 'Unknown', maxLines: 2, overflow: TextOverflow.ellipsis),
                      onTap: () {
                        final lat = double.tryParse(item['lat'].toString());
                        final lon = double.tryParse(item['lon'].toString());
                        if (lat != null && lon != null) {
                          // Return a dummy Position object with the selected lat/lon
                          Navigator.of(context).pop(Position(
                            latitude: lat,
                            longitude: lon,
                            timestamp: DateTime.now(),
                            accuracy: 0,
                            altitude: 0,
                            heading: 0,
                            speed: 0,
                            speedAccuracy: 0,
                            altitudeAccuracy: 0,
                            headingAccuracy: 0,
                          ));
                        }
                      },
                    );
                  },
                ),
              ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HOW IT WORKS & PURPOSE BOTTOM SHEET
// ─────────────────────────────────────────────────────────────────────────────

class _SiteSuggestionGuideSheet extends StatelessWidget {
  const _SiteSuggestionGuideSheet();

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(
        24,
        12,
        24,
        MediaQuery.of(context).padding.bottom + 20,
      ),
      child: SingleChildScrollView(
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
                  color: AppColors.borderMedium,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),

            // Header with icon badge
            Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAF3EB),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.add_location_alt_rounded,
                    color: Color(0xFF386641),
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Suggest a Restoration Site',
                        style: TextStyle(
                          fontSize: 18.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textDark,
                          letterSpacing: -0.3,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'How community land spotting works',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: AppColors.textMedium,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Purpose / What this page does
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF7FAF7),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.borderLight),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Icon(
                    Icons.eco_rounded,
                    color: Color(0xFF386641),
                    size: 20,
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Spotted an empty plot, dry lake bed, or degraded barren land? '
                      'By submitting its location and photos, you flag it for BlueDot arborists to evaluate, verify feasibility, and organize community tree plantation drives!',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textDark,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            const Text(
              'How It Works (4 Simple Steps)',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 14),

            // Step 1
            _buildStepItem(
              icon: Icons.camera_alt_rounded,
              iconColor: AppColors.primaryBlue,
              iconBg: const Color(0xFFEEF1FD),
              stepNumber: '1',
              title: 'Take 1 to 5 Ground Photos',
              description: 'Capture soil condition, open space, and surroundings to help us assess viability.',
            ),
            const SizedBox(height: 14),

            // Step 2
            _buildStepItem(
              icon: Icons.my_location_rounded,
              iconColor: const Color(0xFFD4931A),
              iconBg: const Color(0xFFFEF4E2),
              stepNumber: '2',
              title: 'Verify GPS Coordinates',
              description: 'We auto-pin your spot, or you can search and refine the exact location on the map.',
            ),
            const SizedBox(height: 14),

            // Step 3
            _buildStepItem(
              icon: Icons.edit_note_rounded,
              iconColor: const Color(0xFFC76D4D),
              iconBg: const Color(0xFFFDF0EC),
              stepNumber: '3',
              title: 'Describe Land & Water Access',
              description: 'Mention nearby water sources, fencing, public access, or soil conditions.',
            ),
            const SizedBox(height: 14),

            // Step 4
            _buildStepItem(
              icon: Icons.volunteer_activism_rounded,
              iconColor: const Color(0xFF386641),
              iconBg: const Color(0xFFEAF3EB),
              stepNumber: '4',
              title: 'Verification & Plantation Drive',
              description: 'Our forestry team validates the site. Approved sites host community plantation drives where you earn XP!',
            ),
            const SizedBox(height: 18),

            // XP Bonus Card
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.ecoIndexBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.ecoIndexBorder),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.stars_rounded,
                    color: Color(0xFFC2851B),
                    size: 22,
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Earn +5 XP immediately upon submission, and +20 XP when your site is approved!',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF634D21),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Action Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryBlue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Got It, Let\'s Suggest a Site',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _buildStepItem({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String stepNumber,
    required String title,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: iconBg,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Icon(icon, color: iconColor, size: 19),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textMedium,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

