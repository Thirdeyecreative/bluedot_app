import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/skeletons.dart';
import '../../home/models/campaign_model.dart';
import '../../home/providers/home_provider.dart';
import '../models/event_model.dart';
import '../providers/action_provider.dart';

class ActionHubPage extends ConsumerStatefulWidget {
  const ActionHubPage({super.key});

  @override
  ConsumerState<ActionHubPage> createState() => _ActionHubPageState();
}

class _ActionHubPageState extends ConsumerState<ActionHubPage> with SingleTickerProviderStateMixin {
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (_, _) => [
          SliverAppBar(
            floating: true,
            snap: true,
            title: Text('Action Hub', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: GestureDetector(
                  onTap: () => context.push('/action-hub/suggest-site'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: AppColors.forestGreen.withAlpha(20),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.forestGreen.withAlpha(60)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.add_location_alt_rounded, color: AppColors.forestGreen, size: 16),
                        SizedBox(width: 6),
                        Text('Suggest Site', style: TextStyle(color: AppColors.forestGreen, fontWeight: FontWeight.w600, fontSize: 13)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
            bottom: TabBar(
              controller: _tab,
              labelColor: AppColors.primaryBlue,
              unselectedLabelColor: AppColors.slateBlue,
              indicatorColor: AppColors.primaryBlue,
              indicatorWeight: 3,
              labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w400, fontSize: 14),
              tabs: const [
                Tab(text: 'Campaigns'),
                Tab(text: 'Events'),
              ],
            ),
          ),
        ],
        body: TabBarView(
          controller: _tab,
          children: [
            _CampaignsTab(),
            _DrivesTab(),
          ],
        ),
      ),
    );
  }
}

// ── Tab 1: Upcoming Drives ────────────────────────────────────────────────────

class _DrivesTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final events = ref.watch(eventsProvider);
    return RefreshIndicator(
      onRefresh: () => ref.refresh(eventsProvider.future),
      color: AppColors.primaryBlue,
      backgroundColor: AppColors.surfaceCard,
      child: events.when(
        data: (list) => list.isEmpty
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 100),
                  Center(child: Text('No upcoming drives. Check back soon!')),
                ],
              )
            : ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
                itemCount: list.length,
                itemBuilder: (_, i) => _EventDriveCard(event: list[i])
                    .animate()
                    .fadeIn(delay: (80 * i).ms)
                    .slideY(begin: 0.05, end: 0, delay: (80 * i).ms),
              ),
        loading: () => const SkeletonCardList(count: 3, height: 220),
        error: (e, _) => ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(height: 100),
            Center(child: Text('Error: $e')),
          ],
        ),
      ),
    );
  }
}

class _EventDriveCard extends StatelessWidget {
  final PlantationEvent event;
  const _EventDriveCard({required this.event});

  @override
  Widget build(BuildContext context) {
    final filled = (event.maxParticipants != null && event.maxParticipants! > 0) ? event.attendeesCount / event.maxParticipants! : 0.0;
    final isNearFull = filled >= 0.85;

    return GestureDetector(
      onTap: () => context.push('/action-hub/event/${event.id}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.borderLight),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (event.thumbnailUrl != null)
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(17)),
                child: CachedNetworkImage(
                  imageUrl: event.thumbnailUrl!,
                  height: 160,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  placeholder: (_, _) => Container(height: 160, color: AppColors.borderLight),
                  errorWidget: (_, _, _) => _EventImageFallback(),
                ),
              )
            else
              _EventImageFallback(radius: const BorderRadius.vertical(top: Radius.circular(17))),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _Tag(label: event.eventStatus ?? 'Upcoming', color: AppColors.primaryBlue),
                      if (isNearFull && !event.isAttendeeFull) ...[
                        const SizedBox(width: 8),
                        _Tag(label: 'Almost Full', color: AppColors.terracotta),
                      ],
                      if (event.isAttendeeFull) ...[
                        const SizedBox(width: 8),
                        _Tag(label: 'Full', color: AppColors.errorRed),
                      ],
                      const Spacer(),
                      if (event.isPlantationDrive)
                        const Icon(Icons.park_rounded, size: 16, color: AppColors.forestGreen),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(event.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.calendar_today_rounded, size: 13, color: AppColors.textMedium),
                      const SizedBox(width: 5),
                      Text(event.formattedDate, style: const TextStyle(color: AppColors.textMedium, fontSize: 12)),
                      if (event.siteName != null) ...[
                        const SizedBox(width: 14),
                        const Icon(Icons.location_on_rounded, size: 13, color: AppColors.textMedium),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(event.siteName!, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.textMedium, fontSize: 12)),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${event.attendeesCount}/${event.maxParticipants ?? '∞'} Slots Filled',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: isNearFull ? AppColors.terracotta : AppColors.textMedium),
                      ),
                      Text(
                        '${(filled * 100).toInt()}%',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: isNearFull ? AppColors.terracotta : AppColors.primaryBlue),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: filled.clamp(0, 1),
                      backgroundColor: AppColors.borderLight,
                      color: isNearFull ? AppColors.terracotta : AppColors.primaryBlue,
                      minHeight: 6,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EventImageFallback extends StatelessWidget {
  final BorderRadius? radius;
  const _EventImageFallback({this.radius});
  @override
  Widget build(BuildContext context) => Container(
        height: 120,
        width: double.infinity,
        decoration: BoxDecoration(color: AppColors.primaryBlue.withAlpha(15), borderRadius: radius),
        child: const Center(child: Icon(Icons.forest_rounded, color: AppColors.primaryBlue, size: 44)),
      );
}

// ── Tab 2: Active Campaigns ───────────────────────────────────────────────────

class _CampaignsTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final campaigns = ref.watch(campaignsProvider);
    return RefreshIndicator(
      onRefresh: () => ref.refresh(campaignsProvider.future),
      color: AppColors.primaryBlue,
      backgroundColor: AppColors.surfaceCard,
      child: campaigns.when(
        data: (list) => list.isEmpty
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 100),
                  Center(child: Text('No active campaigns right now.')),
                ],
              )
            : ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
                itemCount: list.length,
                itemBuilder: (_, i) => _CampaignFundingCard(campaign: list[i])
                    .animate()
                    .fadeIn(delay: (80 * i).ms)
                    .slideY(begin: 0.05, end: 0, delay: (80 * i).ms),
              ),
        loading: () => const SkeletonCardList(count: 3, height: 220),
        error: (e, _) => ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(height: 100),
            const Center(child: Text('Could not load campaigns.')),
          ],
        ),
      ),
    );
  }
}

class _CampaignFundingCard extends StatelessWidget {
  final Campaign campaign;
  const _CampaignFundingCard({required this.campaign});

  @override
  Widget build(BuildContext context) {
    final pct = campaign.progressPercent;
    final isNearlyFunded = pct >= 0.75;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Campaign image header
          if (campaign.thumbnailUrl != null)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(17)),
              child: CachedNetworkImage(
                imageUrl: campaign.thumbnailUrl!,
                height: 160,
                width: double.infinity,
                fit: BoxFit.cover,
                placeholder: (_, _) => Container(height: 160, color: AppColors.borderLight),
                errorWidget: (_, _, _) => _CampaignImageFallback(),
              ),
            )
          else
            _CampaignImageFallback(radius: const BorderRadius.vertical(top: Radius.circular(17))),

          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: Text(campaign.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16))),
              if (isNearlyFunded) ...[
                const SizedBox(width: 8),
                _Tag(label: 'Nearly Funded', color: AppColors.terracotta),
              ],
            ],
          ),
          if (campaign.description != null) ...[
            const SizedBox(height: 6),
            Text(campaign.description!, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.textMedium, fontSize: 13, height: 1.4)),
          ],
          const SizedBox(height: 18),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(value: pct.clamp(0, 1), backgroundColor: AppColors.borderLight, color: AppColors.primaryYellow, minHeight: 10),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('₹${_fmt(campaign.currentAmountRaised)} raised',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: AppColors.primaryBlue)),
                  Text('of ₹${_fmt(campaign.targetAmount)} goal', style: const TextStyle(color: AppColors.textMedium, fontSize: 12)),
                ],
              ),
              Text('${(pct * 100).toInt()}%',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 22, color: isNearlyFunded ? AppColors.terracotta : AppColors.primaryYellow)),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              for (final amount in [500, 1000, 2500])
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: OutlinedButton(
                      onPressed: () => _showDonation(context, amount),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 40),
                        padding: EdgeInsets.zero,
                        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                        side: const BorderSide(color: AppColors.primaryBlue),
                      ),
                      child: Text('₹$amount'),
                    ),
                  ),
                ),
            ],
          ),
        ],
            ),
          ),
        ],
      ),
    );
  }

  String _fmt(double v) {
    if (v >= 100000) return '${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(0)}K';
    return v.toStringAsFixed(0);
  }

  void _showDonation(BuildContext context, int amount) {
    showModalBottomSheet(
      context: context,
      // Root navigator so the sheet renders above the shell's floating nav bar.
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DonationSheet(campaign: campaign, presetAmount: amount),
    );
  }
}

class _CampaignImageFallback extends StatelessWidget {
  final BorderRadius? radius;
  const _CampaignImageFallback({this.radius});
  @override
  Widget build(BuildContext context) => Container(
        height: 160,
        width: double.infinity,
        decoration: BoxDecoration(color: AppColors.forestGreen.withAlpha(20), borderRadius: radius),
        child: const Center(child: Icon(Icons.volunteer_activism_rounded, color: AppColors.forestGreen, size: 44)),
      );
}

// ── Donation Sheet ────────────────────────────────────────────────────────────

class _DonationSheet extends StatefulWidget {
  final Campaign campaign;
  final int presetAmount;
  const _DonationSheet({required this.campaign, required this.presetAmount});
  @override
  State<_DonationSheet> createState() => _DonationSheetState();
}

class _DonationSheetState extends State<_DonationSheet> {
  late int _selected;
  final _panCtrl = TextEditingController();
  bool _showPan = false;

  @override
  void initState() {
    super.initState();
    _selected = widget.presetAmount;
  }

  @override
  void dispose() {
    _panCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(color: AppColors.backgroundCream, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
        child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
            24, 20, 24, 24 + MediaQuery.of(context).viewPadding.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.borderMedium, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 20),
            Text('Support Campaign', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(widget.campaign.title, style: const TextStyle(color: AppColors.textMedium, fontSize: 13)),
            const SizedBox(height: 20),
            Row(
              children: [
                for (final a in [500, 1000, 2500, 5000])
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () => setState(() => _selected = a),
                        child: AnimatedContainer(
                          duration: 150.ms,
                          height: 44,
                          decoration: BoxDecoration(
                            color: _selected == a ? AppColors.primaryBlue : AppColors.surfaceCard,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: _selected == a ? AppColors.primaryBlue : AppColors.borderLight),
                          ),
                          child: Center(
                            child: Text('₹$a',
                                style: TextStyle(fontWeight: FontWeight.w700, color: _selected == a ? Colors.white : AppColors.textDark, fontSize: 13)),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            if (_showPan) ...[
              const SizedBox(height: 20),
              Text('PAN Number', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              TextField(
                controller: _panCtrl,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(hintText: 'ABCDE1234F', prefixIcon: Icon(Icons.lock_outline_rounded), helperText: 'Required for 80G tax exemption certificate'),
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () {
                  if (!_showPan) {
                    setState(() => _showPan = true);
                  } else {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Donation of ₹$_selected initiated!'), backgroundColor: AppColors.forestGreen),
                    );
                  }
                },
                child: Text(_showPan ? 'Proceed to Pay ₹$_selected' : 'Donate ₹$_selected'),
              ),
            ),
            if (!_showPan)
              Center(
                child: TextButton(
                  onPressed: () => setState(() => _showPan = true),
                  child: const Text('Unlock 80G Tax Benefit →', style: TextStyle(color: AppColors.primaryBlue, fontSize: 13)),
                ),
              ),
          ],
        ),
        ),
      ),
    );
  }
}

// ── Shared helpers ────────────────────────────────────────────────────────────

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
