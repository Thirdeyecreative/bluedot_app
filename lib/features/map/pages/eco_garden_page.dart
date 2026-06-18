import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/constants/app_colors.dart';
import '../../scanner/models/scan_result_model.dart';
import '../../scanner/providers/scanner_provider.dart';
import '../../scanner/widgets/scan_history_detail_sheet.dart';

class EcoGardenPage extends ConsumerStatefulWidget {
  const EcoGardenPage({super.key});

  @override
  ConsumerState<EcoGardenPage> createState() => _EcoGardenPageState();
}

class _EcoGardenPageState extends ConsumerState<EcoGardenPage> {
  final MapController _mapController = MapController();
  int? _selectedMarkerIndex;
  bool _showTrees = true;
  LatLng? _myLocation;
  bool _locationResolved = false;

  static const _bangaloreCenter = LatLng(bangaloreCenterLat, bangaloreCenterLng);

  @override
  void initState() {
    super.initState();
    _loadMyLocation();
  }

  // Resolved once (success or failure) before the map is first built, so its
  // initialCenter can correctly default to the user's location when allowed,
  // falling back to Bangalore otherwise -- the map can't be recentered after
  // construction without a visible jump.
  Future<void> _loadMyLocation() async {
    try {
      final permission = await Permission.locationWhenInUse.request();
      if (!permission.isGranted) return;
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 5)),
      );
      if (mounted) setState(() => _myLocation = LatLng(position.latitude, position.longitude));
    } catch (_) {
      // Location unavailable -- map just won't show the "you are here" pin.
    } finally {
      if (mounted) setState(() => _locationResolved = true);
    }
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  void _zoomBy(double delta) {
    final camera = _mapController.camera;
    final nextZoom = (camera.zoom + delta).clamp(4.0, 20.0);
    _mapController.move(camera.center, nextZoom);
  }

  void _showTreeDetail(ScanHistoryItem item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ScanHistoryDetailSheet(item: item),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_locationResolved) {
      return const Scaffold(
        backgroundColor: AppColors.backgroundCream,
        body: Center(child: CircularProgressIndicator(color: AppColors.primaryBlue)),
      );
    }

    final mapTrees = ref.watch(mapTreesProvider);
    final trees = mapTrees.maybeWhen(
      data: (list) => list,
      orElse: () => const <ScanHistoryItem>[],
    );

    return Scaffold(
      body: Stack(
        children: [
          // ── Full-screen map ───────────────────────────────────────────
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _myLocation ?? _bangaloreCenter,
              initialZoom: 11.5,
              minZoom: 4,
              maxZoom: 20,
              onTap: (_, _) => setState(() => _selectedMarkerIndex = null),
            ),
            children: [
              // CartoDB Positron — clean, minimal tile style
              TileLayer(
                urlTemplate: 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
                subdomains: const ['a', 'b', 'c', 'd'],
                userAgentPackageName: 'com.bluedot.app',
                retinaMode: RetinaMode.isHighDensity(context),
              ),

              // Tagged tree markers (blue pins) -- real tagged trees in and
              // around Bangalore, fetched from the backend.
              if (_showTrees)
                MarkerLayer(
                  markers: trees.asMap().entries.map((entry) {
                    final i = entry.key;
                    final tree = entry.value;
                    final isSelected = _selectedMarkerIndex == i;
                    return Marker(
                      point: LatLng(tree.lat!, tree.lng!),
                      width: 36,
                      height: 44,
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedMarkerIndex = i),
                        child: Column(
                          children: [
                            AnimatedContainer(
                              duration: 200.ms,
                              width: isSelected ? 36 : 28,
                              height: isSelected ? 36 : 28,
                              decoration: BoxDecoration(
                                color: AppColors.primaryBlue,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primaryBlue.withAlpha(100),
                                    blurRadius: isSelected ? 12 : 6,
                                  ),
                                ],
                              ),
                              child: const Center(
                                child: Icon(Icons.eco_rounded, color: Colors.white, size: 16),
                              ),
                            ),
                            Container(
                              width: 2,
                              height: 8,
                              color: AppColors.primaryBlue,
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),

              // "You are here" -- the user's current location, in blue.
              if (_myLocation != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _myLocation!,
                      width: 26,
                      height: 26,
                      child: IgnorePointer(
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.primaryBlue.withAlpha(60),
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Container(
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                              color: AppColors.primaryBlue,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),

          // ── Top bar ───────────────────────────────────────────────────
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  _MapButton(
                    icon: Icons.arrow_back_rounded,
                    onTap: () => context.pop(),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(50),
                        boxShadow: [BoxShadow(color: Colors.black.withAlpha(20), blurRadius: 8)],
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.park_rounded, color: AppColors.forestGreen, size: 18),
                          SizedBox(width: 8),
                          Text('My Eco Garden', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.textDark)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Layer toggles ─────────────────────────────────────────────
          Positioned(
            top: 80,
            right: 16,
            child: SafeArea(
              child: Column(
                children: [
                  _LayerToggle(
                    icon: Icons.eco_rounded,
                    label: 'Tagged Trees',
                    active: _showTrees,
                    color: AppColors.primaryBlue,
                    onTap: () => setState(() => _showTrees = !_showTrees),
                  ),
                  const SizedBox(height: 8),
                  _MapButton(
                    icon: Icons.my_location_rounded,
                    onTap: () => _mapController.move(_myLocation ?? _bangaloreCenter, 13),
                  ),
                  const SizedBox(height: 8),
                  _MapButton(
                    icon: Icons.add_rounded,
                    onTap: () => _zoomBy(1),
                  ),
                  const SizedBox(height: 8),
                  _MapButton(
                    icon: Icons.remove_rounded,
                    onTap: () => _zoomBy(-1),
                  ),
                ],
              ),
            ),
          ),

          // ── Bottom stats bar ──────────────────────────────────────────
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _StatsBar(treeCount: trees.length),
          ),

          // ── Tree info card ────────────────────────────────────────────
          if (_selectedMarkerIndex != null && _selectedMarkerIndex! < trees.length)
            Positioned(
              left: 16,
              right: 16,
              bottom: 150,
              child: _TreeInfoCard(
                item: trees[_selectedMarkerIndex!],
                onClose: () => setState(() => _selectedMarkerIndex = null),
                onTap: () => _showTreeDetail(trees[_selectedMarkerIndex!]),
              ).animate().fadeIn(duration: 200.ms).slideY(begin: 0.2, end: 0),
            ),
        ],
      ),
    );
  }
}

// ── Supporting widgets ────────────────────────────────────────────────────────

class _MapButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _MapButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: Colors.black.withAlpha(20), blurRadius: 8)],
          ),
          child: Icon(icon, color: AppColors.textDark, size: 20),
        ),
      );
}

class _LayerToggle extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final Color color;
  final VoidCallback onTap;
  const _LayerToggle({required this.icon, required this.label, required this.active, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: active ? color : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: active ? color : AppColors.borderLight),
            boxShadow: [BoxShadow(color: Colors.black.withAlpha(15), blurRadius: 6)],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: active ? Colors.white : AppColors.textMedium, size: 14),
              const SizedBox(width: 5),
              Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: active ? Colors.white : AppColors.textMedium)),
            ],
          ),
        ),
      );
}

class _StatsBar extends StatelessWidget {
  final int treeCount;
  const _StatsBar({required this.treeCount});

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withAlpha(20), blurRadius: 16, offset: const Offset(0, -4))],
        ),
        child: Row(
          children: [
            Expanded(
              child: Center(
                child: _StatItem(icon: Icons.eco_rounded, value: '$treeCount', label: 'Tagged Trees', color: AppColors.primaryBlue),
              ),
            ),
            Container(width: 1, height: 36, color: AppColors.borderLight),
            // TODO: wire to the user's own tagged-tree count once that flow
            // exists (the map currently only fetches community trees, not
            // per-user ones) -- placeholder at 0 until then.
            const Expanded(
              child: Center(
                child: _StatItem(icon: Icons.park_rounded, value: '0', label: 'Your Trees', color: AppColors.primaryYellow),
              ),
            ),
          ],
        ),
      );
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;
  const _StatItem({required this.icon, required this.value, required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontWeight: FontWeight.w700, color: color, fontSize: 15)),
          Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textMedium)),
        ],
      );
}

class _TreeInfoCard extends StatelessWidget {
  final ScanHistoryItem item;
  final VoidCallback onClose;
  final VoidCallback onTap;
  const _TreeInfoCard({required this.item, required this.onClose, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final name = item.species?.localName.isNotEmpty == true
        ? item.species!.localName
        : item.species?.scientificName ??
            item.plantnetData?.commonName ??
            item.plantnetData?.scientificName ??
            'Unidentified plant';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(25), blurRadius: 16)],
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: onTap,
              behavior: HitTestBehavior.opaque,
              child: Row(
                children: [
                  if (item.imageUrl != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.network(
                        item.imageUrl!,
                        width: 52,
                        height: 52,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => _treeIcon(),
                      ),
                    )
                  else
                    _treeIcon(),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: const TextStyle(fontStyle: FontStyle.italic, fontWeight: FontWeight.w700, fontSize: 14)),
                        const SizedBox(height: 2),
                        Text(
                          item.taggedAt != null ? 'Tagged on ${item.taggedAt}' : 'Tagged & geotagged',
                          style: const TextStyle(color: AppColors.textMedium, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          IconButton(icon: const Icon(Icons.close_rounded, size: 20, color: AppColors.textLight), onPressed: onClose),
        ],
      ),
    );
  }

  Widget _treeIcon() => Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(color: AppColors.primaryBlue.withAlpha(25), shape: BoxShape.circle),
        child: const Icon(Icons.eco_rounded, color: AppColors.primaryBlue, size: 28),
      );
}
