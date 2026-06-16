import 'dart:io';
import 'package:flutter/material.dart';
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
      ),
      body: SingleChildScrollView(
        // Bottom padding clears the floating nav bar.
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 130),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Info banner
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.forestGreen.withAlpha(20),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.forestGreen.withAlpha(60)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline_rounded, color: AppColors.forestGreen, size: 20),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Spotted a dry lake, empty plot, or degraded land? Suggest it for a future plantation drive — earn 5 XP now and 20 XP when approved!',
                        style: TextStyle(color: AppColors.forestGreen, fontSize: 13, height: 1.4),
                      ),
                    ),
                  ],
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
                    if (_locationFetched)
                      IconButton(
                        icon: const Icon(Icons.refresh_rounded, color: AppColors.primaryBlue, size: 20),
                        onPressed: _getLocation,
                      ),
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
