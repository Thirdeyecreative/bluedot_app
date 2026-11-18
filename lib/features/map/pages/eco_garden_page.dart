import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/skeletons.dart';
import '../../scanner/data/scanner_repository.dart';
import '../../scanner/models/scan_result_model.dart';
import '../../scanner/providers/scanner_provider.dart';
import '../../scanner/widgets/scan_history_detail_sheet.dart';
import '../../auth/providers/auth_provider.dart';

/// The interactive live Eco Garden Map screen.
///
/// Performance & UX Highlights:
/// - Checks and resolves the user's exact GPS location FIRST.
/// - Zooms in close (~15.5x) to the user's surroundings.
/// - Queries ONLY the surrounding bounding box (~3.5km) via PostGIS spatial filter.
/// - Debounces viewport pans (~650ms) to lazily load surrounding trees on demand.
/// - In-memory ID-keyed map eliminates flicker and duplicate rendering.
/// - Palette directly matches the Home page (Rich Blue gradient header, frosted white controls).
class EcoGardenPage extends ConsumerStatefulWidget {
  const EcoGardenPage({super.key});

  @override
  ConsumerState<EcoGardenPage> createState() => _EcoGardenPageState();
}

class _EcoGardenPageState extends ConsumerState<EcoGardenPage> {
  final MapController _mapController = MapController();
  final Map<String, ScanHistoryItem> _treesMap = {};

  int? _selectedMarkerIndex;
  bool _showTrees = true;
  LatLng? _myLocation;
  bool _locationResolved = false;
  bool _isFetchingTrees = false;

  int? _totalPlatformTrees;
  int? _totalUserTrees;

  LatLng? _lastQueriedCenter;
  Timer? _debounceTimer;

  static const _bangaloreCenter = LatLng(bangaloreCenterLat, bangaloreCenterLng);

  List<ScanHistoryItem> get _trees => _treesMap.values.toList();

  @override
  void initState() {
    super.initState();
    _initLocationAndFetch();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  /// 1. Check user's exact location first.
  /// 2. Move camera to user's location with high-detail zoom.
  /// 3. Fetch data surrounding the user first via bounding box API.
  Future<void> _initLocationAndFetch() async {
    LatLng targetCenter = _bangaloreCenter;

    try {
      final permission = await Permission.locationWhenInUse.request();
      if (permission.isGranted) {
        Position? position;
        try {
          // Fast high-accuracy attempt with a 4-second timeout
          position = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              timeLimit: Duration(seconds: 4),
            ),
          );
        } catch (_) {
          // Fallback to cached last known position if immediate GPS lock takes too long
          position = await Geolocator.getLastKnownPosition();
        }

        if (position != null) {
          targetCenter = LatLng(position.latitude, position.longitude);
          _myLocation = targetCenter;
        }
      }
    } catch (_) {
      // Graceful fallback to default center
    } finally {
      if (mounted) {
        setState(() {
          _locationResolved = true;
        });

        // Fetch surrounding trees for the resolved location immediately (~3.5km box)
        await _fetchTreesAround(targetCenter, radiusDegrees: 0.035);
      }
    }
  }

  /// Queries the backend PostGIS API for trees within a bounding box centered at [center],
  /// while also updating the whole platform tree count and the user's total tagged count.
  Future<void> _fetchTreesAround(LatLng center, {double radiusDegrees = 0.035}) async {
    _lastQueriedCenter = center;
    if (!mounted) return;
    setState(() => _isFetchingTrees = true);

    try {
      final currentUser = ref.read(currentUserProvider);
      final result = await ref.read(scannerRepositoryProvider).fetchMapTreesWithStats(
            minLat: center.latitude - radiusDegrees,
            minLng: center.longitude - radiusDegrees,
            maxLat: center.latitude + radiusDegrees,
            maxLng: center.longitude + radiusDegrees,
            userId: currentUser?.id,
          );

      if (mounted) {
        setState(() {
          for (final item in result.trees) {
            if (item.hasLocation) {
              _treesMap[item.id] = item;
            }
          }
          if (result.totalCount > 0) {
            _totalPlatformTrees = result.totalCount;
          }
          if (result.userTreesCount > 0) {
            _totalUserTrees = result.userTreesCount;
          }
        });
      }
    } catch (_) {
      // Non-blocking network catch
    } finally {
      if (mounted) setState(() => _isFetchingTrees = false);
    }
  }

  /// Debounced listener that fetches new trees as the user pans or explores other regions.
  void _onMapPositionChanged(MapCamera camera, bool hasGesture) {
    if (!hasGesture) return;
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 650), () {
      if (!mounted) return;
      final newCenter = camera.center;
      if (_lastQueriedCenter == null) {
        _fetchTreesAround(newCenter);
        return;
      }
      // If user moved more than ~1.5 km from the last query center, load new viewport
      final dLat = (newCenter.latitude - _lastQueriedCenter!.latitude).abs();
      final dLng = (newCenter.longitude - _lastQueriedCenter!.longitude).abs();
      if (dLat > 0.015 || dLng > 0.015) {
        _fetchTreesAround(newCenter);
      }
    });
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
    final currentUser = ref.watch(currentUserProvider);

    // Skeleton shimmer while resolving user location on cold start
    if (!_locationResolved) {
      return Scaffold(
        backgroundColor: AppColors.backgroundCream,
        body: AppSkeleton(
          child: Stack(
            children: [
              Container(width: double.infinity, height: double.infinity, color: Colors.transparent),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      Bone(width: 44, height: 44, borderRadius: BorderRadius.circular(22)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Bone(height: 44, borderRadius: BorderRadius.circular(50)),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                top: 80,
                right: 16,
                child: SafeArea(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Bone(width: 110, height: 36, borderRadius: BorderRadius.circular(20)),
                      const SizedBox(height: 8),
                      Bone(width: 44, height: 44, borderRadius: BorderRadius.circular(22)),
                      const SizedBox(height: 8),
                      Bone(width: 44, height: 44, borderRadius: BorderRadius.circular(22)),
                      const SizedBox(height: 8),
                      Bone(width: 44, height: 44, borderRadius: BorderRadius.circular(22)),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: 16,
                right: 16,
                bottom: 24,
                child: Bone(width: double.infinity, height: 90, borderRadius: BorderRadius.circular(20)),
              ),
            ],
          ),
        ),
      );
    }

    final trees = _trees;

    return Scaffold(
      body: Stack(
        children: [
          // ── 1. Full-screen Live Map ──────────────────────────────────────
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _myLocation ?? _bangaloreCenter,
              initialZoom: _myLocation != null ? 15.5 : 12.5,
              minZoom: 4,
              maxZoom: 20,
              onPositionChanged: _onMapPositionChanged,
              onTap: (_, _) => setState(() => _selectedMarkerIndex = null),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.bluedot.app',
              ),

              // Tagged tree markers
              if (_showTrees)
                MarkerLayer(
                  markers: trees.asMap().entries.where((e) => e.value.hasLocation).map((entry) {
                    final i = entry.key;
                    final tree = entry.value;
                    final isSelected = _selectedMarkerIndex == i;
                    final isMine = tree.userId != null && currentUser != null && tree.userId == currentUser.id;

                    final markerColor = isMine
                        ? (tree.status == 1 ? AppColors.forestGreen : AppColors.warningAmber)
                        : (tree.status == 1 ? AppColors.primaryBlue : AppColors.warningAmber);

                    final double pillSize = isSelected ? 48 : 40;
                    final bool hasImage = tree.imageUrl != null && tree.imageUrl!.trim().isNotEmpty;

                    return Marker(
                      point: LatLng(tree.lat!, tree.lng!),
                      width: 52,
                      height: 58,
                      alignment: Alignment.bottomCenter,
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedMarkerIndex = i),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            AnimatedContainer(
                              duration: 200.ms,
                              width: pillSize,
                              height: pillSize,
                              padding: const EdgeInsets.all(2.5),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(22),
                                border: Border.all(color: markerColor, width: isSelected ? 3 : 2),
                                boxShadow: [
                                  BoxShadow(
                                    color: markerColor.withOpacity(isSelected ? 0.45 : 0.25),
                                    blurRadius: isSelected ? 12 : 6,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(18),
                                child: hasImage
                                    ? CachedNetworkImage(
                                        imageUrl: tree.imageUrl!,
                                        fit: BoxFit.cover,
                                        placeholder: (_, _) => _MarkerFallbackIcon(
                                          color: markerColor,
                                          status: tree.status,
                                        ),
                                        errorWidget: (_, _, _) => _MarkerFallbackIcon(
                                          color: markerColor,
                                          status: tree.status,
                                        ),
                                      )
                                    : _MarkerFallbackIcon(
                                        color: markerColor,
                                        status: tree.status,
                                      ),
                              ),
                            ),
                            Container(
                              width: 3,
                              height: 6,
                              decoration: BoxDecoration(
                                color: markerColor,
                                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(2)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),

              // "You are here" pin with animated sapphire pulse
              if (_myLocation != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _myLocation!,
                      width: 34,
                      height: 34,
                      child: IgnorePointer(
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: AppColors.primaryBlue.withOpacity(0.22),
                                shape: BoxShape.circle,
                              ),
                            ),
                            Container(
                              width: 16,
                              height: 16,
                              decoration: BoxDecoration(
                                color: AppColors.primaryBlue,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2.5),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.22),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),

          // ── 2. Top App Bar (Rich Blue Gradient) ──────────────────────────
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  _MapButton(
                    icon: Icons.arrow_back_rounded,
                    onTap: () => context.pop(),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AppColors.primaryBlue,
                            Color(0xFF28367F),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(50),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primaryBlue.withOpacity(0.35),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.eco_rounded, color: Colors.white, size: 20),
                          const SizedBox(width: 8),
                          const Text(
                            'My Eco Garden',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15.5,
                              color: Colors.white,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const Spacer(),
                          if (_isFetchingTrees)
                            const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white70),
                              ),
                            )
                          else
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.18),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${_totalPlatformTrees ?? trees.length} tagged',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── 3. Layer Toggles & Action Controls ───────────────────────────
          Positioned(
            top: 76,
            right: 16,
            child: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _LayerToggle(
                    icon: Icons.eco_rounded,
                    label: 'Tagged Trees',
                    active: _showTrees,
                    onTap: () => setState(() => _showTrees = !_showTrees),
                  ),
                  const SizedBox(height: 10),
                  _MapButton(
                    icon: Icons.refresh_rounded,
                    tooltip: 'Refresh Nearby Trees',
                    onTap: () {
                      final center = _mapController.camera.center;
                      _fetchTreesAround(center);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Updating nearby trees...'),
                          duration: Duration(seconds: 1),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                  ),
                  _MapButton(
                    icon: Icons.my_location_rounded,
                    tooltip: 'Zoom to My Location',
                    iconColor: _myLocation != null ? AppColors.primaryBlue : AppColors.textMedium,
                    onTap: () {
                      if (_myLocation != null) {
                        _mapController.move(_myLocation!, 15.5);
                        _fetchTreesAround(_myLocation!);
                      } else {
                        _initLocationAndFetch();
                      }
                    },
                  ),
                  _MapButton(
                    icon: Icons.add_rounded,
                    tooltip: 'Zoom In',
                    onTap: () => _zoomBy(1),
                  ),
                  _MapButton(
                    icon: Icons.remove_rounded,
                    tooltip: 'Zoom Out',
                    onTap: () => _zoomBy(-1),
                  ),
                ],
              ),
            ),
          ),

          // ── 4. Bottom Stats Floating Dock ────────────────────────────────
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Builder(
              builder: (context) {
                final userTrees = _totalUserTrees ??
                    currentUser?.treesTagged ??
                    trees.where((t) => currentUser != null && t.userId == currentUser.id).length;
                final totalTrees = _totalPlatformTrees ?? trees.length;
                final communityTrees = (totalTrees >= userTrees) ? (totalTrees - userTrees) : totalTrees;

                return _StatsBar(
                  treeCount: communityTrees,
                  yourTreeCount: userTrees,
                );
              },
            ),
          ),

          // ── 5. Selected Tree Detail Overlay Card ─────────────────────────
          if (_selectedMarkerIndex != null && _selectedMarkerIndex! < trees.length)
            Positioned(
              left: 16,
              right: 16,
              bottom: 110,
              child: _TreeInfoCard(
                item: trees[_selectedMarkerIndex!],
                onClose: () => setState(() => _selectedMarkerIndex = null),
                onTap: () => _showTreeDetail(trees[_selectedMarkerIndex!]),
              ).animate().fadeIn(duration: 200.ms).slideY(begin: 0.15, end: 0),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SUPPORTING MAP CONTROLS & WIDGETS
// ─────────────────────────────────────────────────────────────────────────────

class _MapButton extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final String? tooltip;
  final VoidCallback onTap;

  const _MapButton({
    required this.icon,
    this.iconColor,
    this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.borderLight,
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Icon(
              icon,
              color: iconColor ?? AppColors.textDark,
              size: 20,
            ),
          ),
        ),
      ),
    );
  }
}

class _LayerToggle extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _LayerToggle({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: active ? AppColors.softBluePill : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: active ? AppColors.primaryBlue.withOpacity(0.4) : AppColors.borderLight,
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: active ? AppColors.primaryBlue : AppColors.textMedium,
                size: 15,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: active ? AppColors.primaryBlue : AppColors.textDark,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatsBar extends StatelessWidget {
  final int treeCount;
  final int yourTreeCount;

  const _StatsBar({
    required this.treeCount,
    required this.yourTreeCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.borderLight, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _StatItem(
              icon: Icons.eco_rounded,
              value: '$treeCount',
              label: 'Community Trees',
              color: AppColors.primaryBlue,
            ),
          ),
          Container(
            width: 1,
            height: 36,
            color: AppColors.borderLight,
          ),
          Expanded(
            child: _StatItem(
              icon: Icons.park_rounded,
              value: '$yourTreeCount',
              label: 'Your Tagged Trees',
              color: AppColors.forestGreen,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _StatItem({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 5),
            Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: color,
                fontSize: 16,
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.textMedium,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _TreeInfoCard extends StatelessWidget {
  final ScanHistoryItem item;
  final VoidCallback onClose;
  final VoidCallback onTap;

  const _TreeInfoCard({
    required this.item,
    required this.onClose,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final name = item.species?.localName.isNotEmpty == true
        ? item.species!.localName
        : item.species?.scientificName ??
            item.plantnetData?.commonName ??
            item.plantnetData?.scientificName ??
            'Unidentified Plant';

    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.borderLight, width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: onTap,
                behavior: HitTestBehavior.opaque,
                child: Row(
                  children: [
                    if (item.imageUrl != null && item.imageUrl!.isNotEmpty)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: CachedNetworkImage(
                          imageUrl: item.imageUrl!,
                          width: 52,
                          height: 52,
                          fit: BoxFit.cover,
                          placeholder: (_, _) => _treeIcon(),
                          errorWidget: (_, _, _) => _treeIcon(),
                        ),
                      )
                    else
                      _treeIcon(),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 14.5,
                              color: AppColors.textDark,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            item.taggedAt != null ? 'Tagged: ${item.taggedAt}' : 'Geotagged & verified',
                            style: const TextStyle(
                              color: AppColors.textMedium,
                              fontSize: 11.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close_rounded, size: 20, color: AppColors.textMedium),
              onPressed: onClose,
            ),
          ],
        ),
      ),
    );
  }

  Widget _treeIcon() => Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: AppColors.softBluePill,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(Icons.eco_rounded, color: AppColors.primaryBlue, size: 26),
      );
}

class _MarkerFallbackIcon extends StatelessWidget {
  final Color color;
  final int status;

  const _MarkerFallbackIcon({
    required this.color,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: color,
      child: Center(
        child: Icon(
          status == 1 ? Icons.eco_rounded : Icons.hourglass_top_rounded,
          color: Colors.white,
          size: 18,
        ),
      ),
    );
  }
}
