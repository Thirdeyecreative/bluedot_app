import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../home/models/campaign_model.dart';
import '../../home/providers/home_provider.dart';
import 'action_hub_page.dart'; // To reuse _DonationSheet

class CampaignDetailPage extends ConsumerWidget {
  final String campaignId;
  const CampaignDetailPage({super.key, required this.campaignId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final campaignsAsync = ref.watch(campaignsProvider);

    return Scaffold(
      backgroundColor: AppColors.backgroundCream,
      body: campaignsAsync.when(
        data: (campaigns) {
          final campaign = campaigns.firstWhere(
            (c) => c.id == campaignId,
            orElse: () => const Campaign(id: '', title: 'Not Found', targetAmount: 0, currentAmountRaised: 0),
          );

          if (campaign.id.isEmpty) {
            return const Center(child: Text('Campaign not found.'));
          }

          final pct = campaign.progressPercent;
          final isNearlyFunded = pct >= 0.75;

          return CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 280,
                pinned: true,
                backgroundColor: AppColors.primaryBlue,
                iconTheme: const IconThemeData(color: Colors.white),
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (campaign.thumbnailUrl != null)
                        CachedNetworkImage(
                          imageUrl: campaign.thumbnailUrl!,
                          fit: BoxFit.cover,
                          placeholder: (_, _) => Container(color: AppColors.primaryBlue),
                          errorWidget: (_, _, _) => Container(color: AppColors.primaryBlue),
                        )
                      else
                        Container(
                          color: AppColors.primaryBlue.withAlpha(20),
                          child: const Icon(Icons.volunteer_activism_rounded, color: Colors.white, size: 60),
                        ),
                      // Gradient overlay for text readability
                      Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.transparent, Colors.black87],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            stops: [0.5, 1.0],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              campaign.title,
                              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
                            ),
                          ),
                          if (isNearlyFunded) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(color: AppColors.terracotta.withAlpha(20), borderRadius: BorderRadius.circular(8)),
                              child: const Text('Nearly Funded', style: TextStyle(color: AppColors.terracotta, fontSize: 11, fontWeight: FontWeight.w700)),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 24),
                      // Progress Section
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4)),
                          ],
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('₹${_fmt(campaign.currentAmountRaised)} raised',
                                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 20, color: AppColors.primaryBlue)),
                                    Text('of ₹${_fmt(campaign.targetAmount)} goal', style: const TextStyle(color: AppColors.textMedium, fontSize: 13)),
                                  ],
                                ),
                                Text('${(pct * 100).toInt()}%',
                                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 26, color: isNearlyFunded ? AppColors.terracotta : AppColors.primaryYellow)),
                              ],
                            ),
                            const SizedBox(height: 14),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: LinearProgressIndicator(value: pct.clamp(0, 1), backgroundColor: AppColors.borderLight, color: AppColors.primaryYellow, minHeight: 12),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text('About this Campaign', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      if (campaign.description != null && campaign.description!.isNotEmpty)
                        Text(
                          campaign.description!.replaceAll(RegExp(r'<[^>]*>'), '').replaceAll('**', ''),
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            height: 1.6,
                            color: AppColors.textDark,
                          ),
                        )
                      else
                        const Text('No detailed description available.', style: TextStyle(color: AppColors.textMedium)),
                      
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primaryBlue)),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
          child: ElevatedButton(
            onPressed: () {
              final campaigns = campaignsAsync.asData?.value;
              if (campaigns == null) return;
              final campaign = campaigns.firstWhere((c) => c.id == campaignId, orElse: () => const Campaign(id: '', title: '', targetAmount: 0, currentAmountRaised: 0));
              if (campaign.id.isEmpty) return;
              
              showModalBottomSheet(
                context: context,
                useRootNavigator: true,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => DonationSheet(campaign: campaign),
              );
            },
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 54),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: const Text('Donate Now', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ),
        ),
      ),
    );
  }

  String _fmt(double v) {
    if (v >= 100000) return '${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(0)}K';
    return v.toStringAsFixed(0);
  }
}
