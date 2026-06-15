import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/skeletons.dart';
import '../models/event_model.dart';
import '../providers/action_provider.dart';

class EventDetailPage extends ConsumerWidget {
  final String eventId;
  const EventDetailPage({super.key, required this.eventId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final event = ref.watch(eventDetailProvider(eventId));
    final rsvpState = ref.watch(rsvpStateProvider);
    final hasRsvpd = rsvpState.value == true;

    return Scaffold(
      body: event.when(
        data: (e) => CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 240,
              pinned: true,
              flexibleSpace: FlexibleSpaceBar(
                background: e.thumbnailUrl != null
                    ? CachedNetworkImage(
                        imageUrl: e.thumbnailUrl!,
                        fit: BoxFit.cover,
                        placeholder: (_, _) => Container(color: AppColors.borderLight),
                        errorWidget: (_, _, _) => _DefaultEventHeader(),
                      )
                    : _DefaultEventHeader(),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _Tag(label: e.eventStatus ?? 'Upcoming', color: AppColors.primaryBlue),
                        if (e.isPlantationDrive) ...[
                          const SizedBox(width: 8),
                          _Tag(label: 'Plantation Drive', color: AppColors.forestGreen),
                        ],
                        const Spacer(),
                        const Icon(Icons.calendar_today_rounded, size: 13, color: AppColors.textMedium),
                        const SizedBox(width: 6),
                        Text(e.formattedDate, style: const TextStyle(color: AppColors.textMedium, fontSize: 13)),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      e.title,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700, height: 1.2),
                    ).animate().fadeIn().slideY(begin: 0.1, end: 0),
                    if (e.siteName != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.location_on_rounded, color: AppColors.terracotta, size: 16),
                          const SizedBox(width: 6),
                          Text(e.siteName!, style: const TextStyle(color: AppColors.textMedium, fontSize: 14)),
                        ],
                      ),
                    ],
                    const Divider(height: 32),
                    Row(
                      children: [
                        _StatTile(icon: Icons.people_rounded, label: 'Joined', value: '${e.participantsCount}/${e.maxParticipants}', color: AppColors.primaryBlue),
                        _StatTile(icon: Icons.park_rounded, label: 'Trees', value: '${e.treesTarget}', color: AppColors.forestGreen),
                        _StatTile(icon: Icons.eco_rounded, label: 'Planted', value: '${e.treesPlanted}', color: AppColors.sageGreen),
                      ],
                    ).animate().fadeIn(delay: 100.ms),
                    const Divider(height: 32),
                    if (e.description != null) ...[
                      Text('About this Drive', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 10),
                      Text(e.description!, style: const TextStyle(color: AppColors.textMedium, height: 1.6, fontSize: 14)),
                      const SizedBox(height: 28),
                    ],

                    // Boarding-pass QR pass — appears after RSVP
                    if (hasRsvpd)
                      _BoardingPassQr(event: e)
                          .animate()
                          .fadeIn(duration: 400.ms)
                          .slideY(begin: 0.15, end: 0, curve: Curves.easeOut),

                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
          ],
        ),
        loading: () => const SkeletonDetailPage(),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
      bottomNavigationBar: event.maybeWhen(
        data: (e) => SafeArea(
          child: Padding(
            // Raised above the shell's floating nav bar.
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            child: ElevatedButton(
              onPressed: e.isFull || rsvpState.isLoading || hasRsvpd
                  ? null
                  : () => ref.read(rsvpStateProvider.notifier).rsvp(eventId),
              style: ElevatedButton.styleFrom(
                backgroundColor: hasRsvpd ? AppColors.forestGreen : AppColors.primaryBlue,
                disabledBackgroundColor: hasRsvpd ? AppColors.forestGreen.withAlpha(180) : null,
              ),
              child: rsvpState.isLoading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(hasRsvpd ? Icons.check_circle_rounded : e.isFull ? Icons.block_rounded : Icons.qr_code_2_rounded, size: 20),
                        const SizedBox(width: 8),
                        Text(hasRsvpd ? "RSVP'd — View My Pass" : e.isFull ? 'Event Full' : 'Join as Volunteer — Get QR Pass'),
                      ],
                    ),
            ),
          ),
        ),
        orElse: () => const SizedBox.shrink(),
      ),
    );
  }
}

// ── Boarding Pass ─────────────────────────────────────────────────────────────

class _BoardingPassQr extends StatefulWidget {
  final PlantationEvent event;
  const _BoardingPassQr({required this.event});

  @override
  State<_BoardingPassQr> createState() => _BoardingPassQrState();
}

class _BoardingPassQrState extends State<_BoardingPassQr> {
  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: AppColors.primaryBlue.withAlpha(30), blurRadius: 24, offset: const Offset(0, 8))],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Role header (Blue = Volunteer)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primaryBlue, Color(0xFF2D3A8C)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.volunteer_activism_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                const Text('VOLUNTEER PASS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14, letterSpacing: 2)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: AppColors.primaryYellow, borderRadius: BorderRadius.circular(6)),
                  child: const Text('CONFIRMED', style: TextStyle(color: AppColors.textDark, fontWeight: FontWeight.w800, fontSize: 10, letterSpacing: 1)),
                ),
              ],
            ),
          ),

          // Event name + date
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.event.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17, color: AppColors.textDark)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.calendar_today_rounded, size: 13, color: AppColors.textMedium),
                    const SizedBox(width: 6),
                    Text(widget.event.formattedDate, style: const TextStyle(color: AppColors.textMedium, fontSize: 13)),
                    if (widget.event.siteName != null) ...[
                      const SizedBox(width: 14),
                      const Icon(Icons.location_on_rounded, size: 13, color: AppColors.textMedium),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(widget.event.siteName!, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.textMedium, fontSize: 13)),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          // Perforation divider
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Row(
              children: [
                _DashEdge(left: true),
                Expanded(
                  child: LayoutBuilder(
                    builder: (_, c) => Row(
                      children: List.generate(
                        (c.maxWidth / 8).floor(),
                        (_) => Expanded(child: Container(height: 1, color: AppColors.borderLight, margin: const EdgeInsets.symmetric(horizontal: 2))),
                      ),
                    ),
                  ),
                ),
                _DashEdge(left: false),
              ],
            ),
          ),

          // QR Code — large, high-contrast for sunlight scanning
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: AppColors.borderLight, width: 1.5),
                borderRadius: BorderRadius.circular(16),
              ),
              child: QrImageView(
                data: 'bluedot://event/${widget.event.id}/attend',
                version: QrVersions.auto,
                size: 200,
                backgroundColor: Colors.white,
                eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: AppColors.textDark),
                dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: AppColors.textDark),
              ),
            ),
          ),

          const SizedBox(height: 12),
          const Text('Show this to the coordinator at the venue entrance', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textLight, fontSize: 12)),
          const SizedBox(height: 6),
          Text('ID: ${widget.event.id}', style: const TextStyle(color: AppColors.borderMedium, fontSize: 10, fontFamily: 'monospace')),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _DashEdge extends StatelessWidget {
  final bool left;
  const _DashEdge({required this.left});

  @override
  Widget build(BuildContext context) => Transform.translate(
        offset: Offset(left ? -12 : 12, 0),
        child: Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: AppColors.backgroundCream,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.borderLight),
          ),
        ),
      );
}

// ── Supporting widgets ────────────────────────────────────────────────────────

class _DefaultEventHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(colors: [AppColors.forestGreen, Color(0xFF3A5240)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        ),
        child: const Center(child: Icon(Icons.forest_rounded, color: Colors.white, size: 64)),
      );
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _StatTile({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 15)),
            Text(label, style: const TextStyle(color: AppColors.textLight, fontSize: 12)),
          ],
        ),
      );
}

class _Tag extends StatelessWidget {
  final String label;
  final Color color;
  const _Tag({required this.label, required this.color});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: color.withAlpha(20), borderRadius: BorderRadius.circular(8)),
        child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
      );
}
