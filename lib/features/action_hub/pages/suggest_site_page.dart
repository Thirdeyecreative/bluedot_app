import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/constants/app_colors.dart';
import '../data/action_repository.dart';

class SuggestSitePage extends ConsumerStatefulWidget {
  const SuggestSitePage({super.key});

  @override
  ConsumerState<SuggestSitePage> createState() => _SuggestSitePageState();
}

class _SuggestSitePageState extends ConsumerState<SuggestSitePage> {
  final _formKey = GlobalKey<FormState>();
  final _descController = TextEditingController();
  File? _photo;
  Position? _position;
  bool _isSubmitting = false;
  bool _locationFetched = false;

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

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final xFile = await picker.pickImage(source: ImageSource.camera, imageQuality: 80);
    if (xFile != null) setState(() => _photo = File(xFile.path));
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_position == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Location not available. Please try again.')));
      return;
    }
    setState(() => _isSubmitting = true);
    try {
      final result = await ref.read(actionRepositoryProvider).suggestSite(
            description: _descController.text.trim(),
            lat: _position!.latitude,
            lng: _position!.longitude,
            image: _photo,
          );
      if (mounted) {
        final message = result['message'] as String? ??
            'Site suggested! Our team will review it — you earn 20 XP when it is approved.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: AppColors.forestGreen),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppColors.errorRed));
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

              // Photo capture
              Text('Photo', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _pickPhoto,
                child: Container(
                  height: 180,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceCard,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.borderLight, width: 1.5),
                  ),
                  child: _photo != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(13),
                          child: Image.file(_photo!, fit: BoxFit.cover),
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.camera_alt_rounded, size: 40, color: AppColors.slateBlue.withAlpha(150)),
                            const SizedBox(height: 8),
                            const Text('Tap to take a photo', style: TextStyle(color: AppColors.textMedium)),
                          ],
                        ),
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
