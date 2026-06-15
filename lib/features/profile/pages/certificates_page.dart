import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/skeletons.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/certificate_model.dart';
import '../providers/profile_provider.dart';

class CertificatesPage extends ConsumerWidget {
  const CertificatesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final certs = ref.watch(certificatesProvider);

    return Scaffold(
      backgroundColor: AppColors.backgroundCream,
      appBar: AppBar(
        title: const Text('My Certificates'),
        leading: const BackButton(),
      ),
      body: certs.when(
        loading: () => const SkeletonCardList(count: 3, height: 150),
        error: (e, _) => Center(child: Text('Could not load certificates.\n$e', textAlign: TextAlign.center)),
        data: (list) {
          if (list.isEmpty) return const _EmptyCertificates();
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 130),
            children: [
              // Summary banner
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.forestGreen, Color(0xFF3F5244)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.workspace_premium_rounded, color: AppColors.primaryYellow, size: 34),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${list.length} certificate${list.length == 1 ? '' : 's'} earned',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Tap any certificate to view and download it.',
                            style: TextStyle(color: Colors.white.withAlpha(190), fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn().slideY(begin: 0.08, end: 0),
              const SizedBox(height: 16),

              for (int i = 0; i < list.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _CertificateListCard(cert: list[i])
                      .animate()
                      .fadeIn(delay: (80 * i).ms)
                      .slideY(begin: 0.06, end: 0, delay: (80 * i).ms),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _EmptyCertificates extends StatelessWidget {
  const _EmptyCertificates();

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.workspace_premium_outlined, size: 64, color: AppColors.slateBlue.withAlpha(120)),
              const SizedBox(height: 16),
              const Text('No certificates yet', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: AppColors.textDark)),
              const SizedBox(height: 8),
              const Text(
                'Join a volunteer drive and complete it to earn your first contribution certificate.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textMedium, fontSize: 13, height: 1.5),
              ),
            ],
          ),
        ),
      );
}

class _CertificateListCard extends StatelessWidget {
  final VolunteerCertificate cert;
  const _CertificateListCard({required this.cert});

  void _open(BuildContext context) {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CertificateSheet(cert: cert),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _open(context),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.borderLight),
        ),
        child: Row(
          children: [
            Container(
              width: 64,
              height: 96,
              margin: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primaryBlue, Color(0xFF2D3A8C)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.workspace_premium_rounded, color: AppColors.primaryYellow, size: 30),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(cert.eventTitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.calendar_today_rounded, size: 12, color: AppColors.textMedium),
                        const SizedBox(width: 4),
                        Text(cert.dateLabel, style: const TextStyle(color: AppColors.textMedium, fontSize: 12)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _MiniStat(icon: Icons.park_rounded, label: '${cert.treesPlanted} trees', color: AppColors.forestGreen),
                        const SizedBox(width: 10),
                        _MiniStat(icon: Icons.schedule_rounded, label: '${cert.hours}h', color: AppColors.slateBlue),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(right: 12),
              child: Icon(Icons.chevron_right_rounded, color: AppColors.textLight),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _MiniStat({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: color.withAlpha(20), borderRadius: BorderRadius.circular(8)),
        child: Row(
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
          ],
        ),
      );
}

// ── Certificate preview sheet ─────────────────────────────────────────────────

class _CertificateSheet extends ConsumerWidget {
  final VolunteerCertificate cert;
  const _CertificateSheet({required this.cert});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final name = user?.fullName ?? 'BlueDot Volunteer';

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(
          color: AppColors.backgroundCream,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12),
              decoration: BoxDecoration(color: AppColors.borderMedium, borderRadius: BorderRadius.circular(2)),
            ),
            Expanded(
              child: ListView(
                controller: controller,
                padding: EdgeInsets.fromLTRB(20, 16, 20, 24 + MediaQuery.of(context).viewPadding.bottom),
                children: [
                  _CertificateArtwork(cert: cert, recipientName: name),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Certificate shared')),
                          ),
                          icon: const Icon(Icons.share_rounded, size: 18),
                          label: const Text('Share'),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, 50),
                            side: const BorderSide(color: AppColors.primaryBlue),
                            foregroundColor: AppColors.primaryBlue,
                            shape: const StadiumBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Certificate downloaded as PDF'), backgroundColor: AppColors.forestGreen),
                          ),
                          icon: const Icon(Icons.download_rounded, size: 18),
                          label: const Text('Download'),
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(0, 50),
                            shape: const StadiumBorder(),
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
      ),
    );
  }
}

class _CertificateArtwork extends StatelessWidget {
  final VolunteerCertificate cert;
  final String recipientName;
  const _CertificateArtwork({required this.cert, required this.recipientName});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primaryYellow.withAlpha(120), width: 2),
        boxShadow: [BoxShadow(color: AppColors.primaryBlue.withAlpha(25), blurRadius: 24, offset: const Offset(0, 10))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          children: [
            // Crest
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primaryBlue, Color(0xFF2D3A8C)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.eco_rounded, color: AppColors.primaryYellow, size: 30),
            ),
            const SizedBox(height: 12),
            const Text('BlueDot', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: AppColors.primaryBlue, letterSpacing: 0.5)),
            const Text('CERTIFICATE OF CONTRIBUTION', style: TextStyle(fontSize: 10, letterSpacing: 2, color: AppColors.textMedium, fontWeight: FontWeight.w600)),
            const SizedBox(height: 20),

            const Text('This certifies that', style: TextStyle(color: AppColors.textMedium, fontSize: 12)),
            const SizedBox(height: 6),
            Text(
              recipientName,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 24, color: AppColors.textDark),
            ),
            Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              height: 2,
              width: 120,
              color: AppColors.primaryYellow,
            ),
            Text(
              'contributed as a $role at',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textMedium, fontSize: 12),
            ),
            const SizedBox(height: 4),
            Text(
              cert.eventTitle,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: AppColors.forestGreen),
            ),
            Text(cert.siteName, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textMedium, fontSize: 12)),
            const SizedBox(height: 18),

            // Impact stats
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _CertStat(value: '${cert.treesPlanted}', label: 'Trees Planted'),
                _CertDivider(),
                _CertStat(value: '${cert.hours}h', label: 'Volunteered'),
                _CertDivider(),
                _CertStat(value: cert.dateLabel.split(' ').first, label: cert.dateLabel.split(' ').sublist(1).join(' ')),
              ],
            ),
            const SizedBox(height: 20),

            // Footer: signature + cert no
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(width: 90, height: 1.4, color: AppColors.borderMedium),
                    const SizedBox(height: 4),
                    const Text('Programme Director', style: TextStyle(fontSize: 10, color: AppColors.textMedium)),
                  ],
                ),
                const Spacer(),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Icon(Icons.verified_rounded, color: AppColors.forestGreen.withAlpha(180), size: 28),
                    const SizedBox(height: 2),
                    Text(cert.certificateNo, style: const TextStyle(fontSize: 9, color: AppColors.textLight)),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String get role => cert.role;
}

class _CertStat extends StatelessWidget {
  final String value;
  final String label;
  const _CertStat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: AppColors.primaryBlue)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textMedium)),
        ],
      );
}

class _CertDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(width: 1, height: 30, color: AppColors.borderLight);
}
