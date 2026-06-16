import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../../core/widgets/skeletons.dart';
import '../data/action_repository.dart';
import '../models/event_model.dart';
import '../providers/action_provider.dart';

class EventDetailPage extends ConsumerStatefulWidget {
  final String eventId;
  const EventDetailPage({super.key, required this.eventId});

  @override
  ConsumerState<EventDetailPage> createState() => _EventDetailPageState();
}

class _EventDetailPageState extends ConsumerState<EventDetailPage> {
  @override
  void initState() {
    super.initState();
    // Seed notifier states once the event detail loads
    Future.microtask(() {
      final event = ref.read(eventDetailProvider(widget.eventId));
      event.whenData((e) {
        ref.read(rsvpStateProvider.notifier).seed(e.isUserRsvped);
        ref.read(volunteerStateProvider.notifier).seed(e.isUserVolunteered);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final eventAsync = ref.watch(eventDetailProvider(widget.eventId));
    final rsvpState = ref.watch(rsvpStateProvider);
    final volunteerState = ref.watch(volunteerStateProvider);

    // Seed states when event detail first arrives
    ref.listen(eventDetailProvider(widget.eventId), (_, next) {
      next.whenData((e) {
        final rsvpNotifier = ref.read(rsvpStateProvider.notifier);
        final volNotifier = ref.read(volunteerStateProvider.notifier);
        // Only seed if notifier is still at default (avoid overwriting in-flight changes)
        if (rsvpState is AsyncData<bool> && rsvpState.value == false && e.isUserRsvped) {
          rsvpNotifier.seed(true);
        }
        if (volunteerState is AsyncData<bool> && volunteerState.value == false && e.isUserVolunteered) {
          volNotifier.seed(true);
        }
      });
    });

    final isRsvped = switch (rsvpState) { AsyncData(:final value) => value, _ => false };
    final isVolunteered = switch (volunteerState) { AsyncData(:final value) => value, _ => false };
    final isRegistered = isRsvped || isVolunteered;

    return Scaffold(
      body: eventAsync.when(
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
                    // Status tags
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

                    // ── Capacity stats row ──────────────────────────────────
                    _CapacityRow(event: e).animate().fadeIn(delay: 100.ms),
                    const Divider(height: 32),

                    // ── Tree stats (plantation drives) ──────────────────────
                    if (e.isPlantationDrive && e.treesTarget > 0) ...[
                      Row(
                        children: [
                          _StatTile(icon: Icons.park_rounded, label: 'Trees Target', value: '${e.treesTarget}', color: AppColors.forestGreen),
                          _StatTile(icon: Icons.eco_rounded, label: 'Trees Planted', value: '${e.treesPlanted}', color: AppColors.sageGreen),
                        ],
                      ).animate().fadeIn(delay: 150.ms),
                      const Divider(height: 32),
                    ],

                    // ── About section ───────────────────────────────────────
                    if (e.description != null) ...[
                      Text('About this Drive', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 10),
                      Text(e.description!, style: const TextStyle(color: AppColors.textMedium, height: 1.6, fontSize: 14)),
                      const SizedBox(height: 28),
                    ],

                    // ── Plantation drive donation tile ──────────────────────
                    if (e.isPlantationDrive)
                      _DonationTile(eventId: widget.eventId)
                          .animate()
                          .fadeIn(delay: 200.ms),

                    // ── Scan QR button (only after registered) ─────────────
                    if (isRegistered) ...[
                      const SizedBox(height: 16),
                      _ScanQrButton(eventId: widget.eventId, role: isVolunteered ? 'Volunteer' : 'Attendee')
                          .animate()
                          .fadeIn(delay: 250.ms)
                          .slideY(begin: 0.1, end: 0),
                    ],

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

      // ── Bottom action bar ──────────────────────────────────────────────────
      bottomNavigationBar: eventAsync.maybeWhen(
        data: (e) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            child: _ActionBar(
              event: e,
              isRsvped: isRsvped,
              isVolunteered: isVolunteered,
              rsvpLoading: rsvpState.isLoading,
              volunteerLoading: volunteerState.isLoading,
              onRsvp: () => _handleRsvp(e),
              onVolunteer: () => _handleVolunteer(e),
            ),
          ),
        ),
        orElse: () => const SizedBox.shrink(),
      ),
    );
  }

  Future<void> _handleRsvp(PlantationEvent e) async {
    try {
      await ref.read(rsvpStateProvider.notifier).toggle(widget.eventId);
      if (!mounted) return;
      final isNowRsvped = switch (ref.read(rsvpStateProvider)) {
        AsyncData(:final value) => value,
        _ => false,
      };
      AppFeedback.showSuccess(context, isNowRsvped ? 'RSVP confirmed! See you there.' : 'RSVP cancelled.');
    } catch (err) {
      if (!mounted) return;
      AppFeedback.showError(context, err);
    }
  }

  Future<void> _handleVolunteer(PlantationEvent e) async {
    try {
      await ref.read(volunteerStateProvider.notifier).toggle(widget.eventId);
      if (!mounted) return;
      final isNowVol = switch (ref.read(volunteerStateProvider)) {
        AsyncData(:final value) => value,
        _ => false,
      };
      AppFeedback.showSuccess(context, isNowVol ? "You're registered as a Volunteer!" : 'Volunteer registration cancelled.');
    } catch (err) {
      if (!mounted) return;
      AppFeedback.showError(context, err);
    }
  }
}

// ── Capacity row ──────────────────────────────────────────────────────────────

class _CapacityRow extends StatelessWidget {
  final PlantationEvent event;
  const _CapacityRow({required this.event});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _CapacityChip(
            icon: Icons.people_rounded,
            label: 'Attendees',
            count: event.attendeesCount,
            max: event.maxParticipants,
            color: AppColors.primaryBlue,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _CapacityChip(
            icon: Icons.volunteer_activism_rounded,
            label: 'Volunteers',
            count: event.volunteersCount,
            max: event.volunteersRequired,
            color: AppColors.forestGreen,
          ),
        ),
      ],
    );
  }
}

class _CapacityChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;
  final int? max;
  final Color color;
  const _CapacityChip({required this.icon, required this.label, required this.count, this.max, required this.color});

  @override
  Widget build(BuildContext context) {
    final isFull = max != null && count >= max!;
    final text = max != null ? '$count / $max' : '$count';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withAlpha(15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(40)),
      ),
      child: Row(
        children: [
          Icon(isFull ? Icons.block_rounded : icon, color: color, size: 18),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
              Text(isFull ? 'Full' : text, style: TextStyle(color: isFull ? AppColors.terracotta : color, fontSize: 13, fontWeight: FontWeight.w700)),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Bottom action bar ─────────────────────────────────────────────────────────

class _ActionBar extends StatelessWidget {
  final PlantationEvent event;
  final bool isRsvped;
  final bool isVolunteered;
  final bool rsvpLoading;
  final bool volunteerLoading;
  final VoidCallback onRsvp;
  final VoidCallback onVolunteer;

  const _ActionBar({
    required this.event,
    required this.isRsvped,
    required this.isVolunteered,
    required this.rsvpLoading,
    required this.volunteerLoading,
    required this.onRsvp,
    required this.onVolunteer,
  });

  @override
  Widget build(BuildContext context) {
    final isRegistered = isRsvped || isVolunteered;

    if (isRegistered) {
      return _RegisteredBadge(isVolunteer: isVolunteered);
    }

    return Row(
      children: [
        // RSVP as Attendee
        Expanded(
          child: OutlinedButton.icon(
            onPressed: event.isAttendeeFull || rsvpLoading ? null : onRsvp,
            icon: rsvpLoading
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : Icon(event.isAttendeeFull ? Icons.block_rounded : Icons.how_to_reg_rounded, size: 18),
            label: Text(event.isAttendeeFull ? 'Full' : 'RSVP'),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.primaryBlue),
              foregroundColor: AppColors.primaryBlue,
            ),
          ),
        ),
        const SizedBox(width: 10),
        // Join as Volunteer
        Expanded(
          flex: 2,
          child: ElevatedButton.icon(
            onPressed: event.isVolunteerFull || volunteerLoading ? null : onVolunteer,
            icon: volunteerLoading
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : Icon(event.isVolunteerFull ? Icons.block_rounded : Icons.volunteer_activism_rounded, size: 18),
            label: Text(event.isVolunteerFull ? 'Volunteer Full' : 'Join as Volunteer'),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.forestGreen),
          ),
        ),
      ],
    );
  }
}

class _RegisteredBadge extends StatelessWidget {
  final bool isVolunteer;
  const _RegisteredBadge({required this.isVolunteer});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: (isVolunteer ? AppColors.forestGreen : AppColors.primaryBlue).withAlpha(15),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: (isVolunteer ? AppColors.forestGreen : AppColors.primaryBlue).withAlpha(60)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isVolunteer ? Icons.volunteer_activism_rounded : Icons.how_to_reg_rounded,
              color: isVolunteer ? AppColors.forestGreen : AppColors.primaryBlue,
              size: 20,
            ),
            const SizedBox(width: 10),
            Text(
              isVolunteer ? "Registered as Volunteer" : "RSVP'd as Attendee",
              style: TextStyle(
                color: isVolunteer ? AppColors.forestGreen : AppColors.primaryBlue,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
}

// ── Scan QR button ────────────────────────────────────────────────────────────

class _ScanQrButton extends StatelessWidget {
  final String eventId;
  final String role;
  const _ScanQrButton({required this.eventId, required this.role});

  @override
  Widget build(BuildContext context) => ElevatedButton.icon(
        onPressed: () => context.push('/action-hub/event/$eventId/checkin'),
        icon: const Icon(Icons.qr_code_scanner_rounded, size: 20),
        label: Text('Scan QR at Venue to Check In ($role)'),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryBlue,
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      );
}

// ── Donation tile (plantation drives only) ────────────────────────────────────

class _DonationTile extends StatefulWidget {
  final String eventId;
  const _DonationTile({required this.eventId});

  @override
  State<_DonationTile> createState() => _DonationTileState();
}

class _DonationTileState extends State<_DonationTile> {
  static const _amounts = [500, 1000, 2500, 5000];
  bool _loading = false;

  Future<void> _donate(BuildContext context, WidgetRef ref, int amount) async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      final repo = ref.read(actionRepositoryProvider);
      await repo.donateForEvent(widget.eventId, amount);
      if (!context.mounted) return;
      await AppFeedback.showThankYou(
        context,
        title: 'Thank You! 🌳',
        message: 'Your ₹$amount donation will help plant trees at this drive.',
        xpLabel: 'Impact recorded',
      );
    } catch (e) {
      if (!context.mounted) return;
      AppFeedback.showError(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.forestGreen.withAlpha(10),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.forestGreen.withAlpha(40)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.park_rounded, color: AppColors.forestGreen, size: 20),
                const SizedBox(width: 8),
                const Text('Donate for Trees', style: TextStyle(color: AppColors.forestGreen, fontWeight: FontWeight.w700, fontSize: 15)),
              ],
            ),
            const SizedBox(height: 4),
            const Text('Funds this event\'s plantation directly', style: TextStyle(color: AppColors.textMedium, fontSize: 12)),
            const SizedBox(height: 14),
            Row(
              children: _amounts.map((amt) => Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: OutlinedButton(
                    onPressed: _loading ? null : () => _donate(context, ref, amt),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.forestGreen),
                      foregroundColor: AppColors.forestGreen,
                      padding: EdgeInsets.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text('₹$amt', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                ),
              )).toList(),
            ),
          ],
        ),
      ),
    );
  }
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
