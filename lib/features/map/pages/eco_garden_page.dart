import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/constants/app_colors.dart';
import '../../scanner/providers/scanner_provider.dart';

// Demo plantation site polygons (geo-referenced around Mumbai/Pune area)
const _sites = [
  _SiteData(
    name: 'Sanjay Gandhi National Park',
    center: LatLng(19.2147, 72.9101),
    color: AppColors.forestGreen,
    trees: 12450,
  ),
  _SiteData(
    name: 'Bhimashankar Fringe',
    center: LatLng(19.0700, 73.5300),
    color: AppColors.sageGreen,
    trees: 8200,
  ),
  _SiteData(
    name: 'Powai Lake Buffer',
    center: LatLng(19.1230, 72.9060),
    color: AppColors.forestGreen,
    trees: 2100,
  ),
];

// Demo tree markers (user-scanned trees near Mumbai)
const _treeMarkers = [
  LatLng(19.2165, 72.9120),
  LatLng(19.2130, 72.9090),
  LatLng(19.2180, 72.9060),
  LatLng(19.1240, 72.9080),
  LatLng(19.1210, 72.9100),
  LatLng(19.0720, 73.5280),
  LatLng(19.0690, 73.5320),
];

class EcoGardenPage extends ConsumerStatefulWidget {
  const EcoGardenPage({super.key});

  @override
  ConsumerState<EcoGardenPage> createState() => _EcoGardenPageState();
}

class _EcoGardenPageState extends ConsumerState<EcoGardenPage> {
  final MapController _mapController = MapController();
  _SiteData? _selectedSite;
  int? _selectedMarkerIndex;
  bool _showSites = true;
  bool _showMyTrees = true;

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final history = ref.watch(scanHistoryProvider);

    return Scaffold(
      body: Stack(
        children: [
          // ── Full-screen map ───────────────────────────────────────────
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: const LatLng(19.1850, 72.9280),
              initialZoom: 11.5,
              minZoom: 8,
              maxZoom: 18,
              onTap: (_, _) => setState(() {
                _selectedSite = null;
                _selectedMarkerIndex = null;
              }),
            ),
            children: [
              // CartoDB Positron — clean, minimal tile style
              TileLayer(
                urlTemplate: 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
                subdomains: const ['a', 'b', 'c', 'd'],
                userAgentPackageName: 'com.bluedot.app',
              ),

              // Plantation site circles (simulated polygons)
              if (_showSites)
                CircleLayer(
                  circles: _sites
                      .map(
                        (s) => CircleMarker(
                          point: s.center,
                          radius: 800,
                          color: s.color.withAlpha(35),
                          borderColor: s.color.withAlpha(160),
                          borderStrokeWidth: 2,
                          useRadiusInMeter: true,
                        ),
                      )
                      .toList(),
                ),

              // Site tap zones (larger invisible hit targets)
              if (_showSites)
                MarkerLayer(
                  markers: _sites.asMap().entries.map((e) {
                    final s = e.value;
                    return Marker(
                      point: s.center,
                      width: 120,
                      height: 44,
                      child: GestureDetector(
                        onTap: () => setState(() {
                          _selectedSite = s;
                          _selectedMarkerIndex = null;
                        }),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: s.color.withAlpha(220),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.forest_rounded, color: Colors.white, size: 14),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  s.name.split(' ').first,
                                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),

              // User-scanned tree markers (yellow pins)
              if (_showMyTrees)
                MarkerLayer(
                  markers: _treeMarkers.asMap().entries.map((entry) {
                    final i = entry.key;
                    final pt = entry.value;
                    final isSelected = _selectedMarkerIndex == i;
                    return Marker(
                      point: pt,
                      width: 36,
                      height: 44,
                      child: GestureDetector(
                        onTap: () => setState(() {
                          _selectedMarkerIndex = i;
                          _selectedSite = null;
                        }),
                        child: Column(
                          children: [
                            AnimatedContainer(
                              duration: 200.ms,
                              width: isSelected ? 36 : 28,
                              height: isSelected ? 36 : 28,
                              decoration: BoxDecoration(
                                color: AppColors.primaryYellow,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primaryYellow.withAlpha(100),
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
                              color: AppColors.primaryYellow,
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
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
                    icon: Icons.forest_rounded,
                    label: 'Sites',
                    active: _showSites,
                    color: AppColors.forestGreen,
                    onTap: () => setState(() => _showSites = !_showSites),
                  ),
                  const SizedBox(height: 8),
                  _LayerToggle(
                    icon: Icons.eco_rounded,
                    label: 'My Trees',
                    active: _showMyTrees,
                    color: AppColors.primaryYellow,
                    onTap: () => setState(() => _showMyTrees = !_showMyTrees),
                  ),
                  const SizedBox(height: 8),
                  _MapButton(
                    icon: Icons.my_location_rounded,
                    onTap: () => _mapController.move(const LatLng(19.1850, 72.9280), 11.5),
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
            child: _StatsBar(
              treeCount: _treeMarkers.length,
              siteCount: _sites.length,
            ),
          ),

          // ── Site info card ────────────────────────────────────────────
          if (_selectedSite != null)
            Positioned(
              left: 16,
              right: 16,
              bottom: 100,
              child: _SiteInfoCard(
                site: _selectedSite!,
                onClose: () => setState(() => _selectedSite = null),
              ).animate().fadeIn(duration: 200.ms).slideY(begin: 0.2, end: 0),
            ),

          // ── Tree info card ────────────────────────────────────────────
          if (_selectedMarkerIndex != null)
            Positioned(
              left: 16,
              right: 16,
              bottom: 100,
              child: _TreeInfoCard(
                index: _selectedMarkerIndex!,
                history: history,
                onClose: () => setState(() => _selectedMarkerIndex = null),
              ).animate().fadeIn(duration: 200.ms).slideY(begin: 0.2, end: 0),
            ),
        ],
      ),
    );
  }
}

// ── Supporting widgets ────────────────────────────────────────────────────────

class _SiteData {
  final String name;
  final LatLng center;
  final Color color;
  final int trees;
  const _SiteData({required this.name, required this.center, required this.color, required this.trees});
}

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
  final int siteCount;
  const _StatsBar({required this.treeCount, required this.siteCount});

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
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _StatItem(icon: Icons.eco_rounded, value: '$treeCount', label: 'Trees Tagged', color: AppColors.primaryYellow),
            Container(width: 1, height: 36, color: AppColors.borderLight),
            _StatItem(icon: Icons.forest_rounded, value: '$siteCount', label: 'My Sites', color: AppColors.forestGreen),
            Container(width: 1, height: 36, color: AppColors.borderLight),
            _StatItem(icon: Icons.cloud_done_rounded, value: '${(treeCount * 21.8).toStringAsFixed(0)} kg', label: 'CO₂/year', color: AppColors.primaryBlue),
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

class _SiteInfoCard extends StatelessWidget {
  final _SiteData site;
  final VoidCallback onClose;
  const _SiteInfoCard({required this.site, required this.onClose});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withAlpha(25), blurRadius: 16)],
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(color: site.color.withAlpha(25), shape: BoxShape.circle),
              child: Icon(Icons.forest_rounded, color: site.color, size: 28),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(site.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  const SizedBox(height: 2),
                  Text('${site.trees.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')} trees documented',
                      style: const TextStyle(color: AppColors.textMedium, fontSize: 13)),
                ],
              ),
            ),
            IconButton(icon: const Icon(Icons.close_rounded, size: 20, color: AppColors.textLight), onPressed: onClose),
          ],
        ),
      );
}

class _TreeInfoCard extends StatelessWidget {
  final int index;
  final AsyncValue<dynamic> history;
  final VoidCallback onClose;
  const _TreeInfoCard({required this.index, required this.history, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final name = history.maybeWhen(
      data: (list) {
        final items = list as List;
        if (index < items.length) {
          return items[index].plantnetSummary?['scientific_name'] as String? ?? 'Unknown species';
        }
        return 'Unknown species';
      },
      orElse: () => 'Unknown species',
    );

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(25), blurRadius: 16)],
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(color: AppColors.primaryYellow.withAlpha(25), shape: BoxShape.circle),
            child: const Icon(Icons.eco_rounded, color: AppColors.primaryYellow, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontStyle: FontStyle.italic, fontWeight: FontWeight.w700, fontSize: 14)),
                const SizedBox(height: 2),
                const Text('Scanned & Geotagged by you', style: TextStyle(color: AppColors.textMedium, fontSize: 12)),
              ],
            ),
          ),
          IconButton(icon: const Icon(Icons.close_rounded, size: 20, color: AppColors.textLight), onPressed: onClose),
        ],
      ),
    );
  }
}
