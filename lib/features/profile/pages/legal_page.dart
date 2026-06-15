import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/constants/app_colors.dart';

/// A single titled block of legal copy.
class LegalSection {
  final String heading;
  final String body;
  const LegalSection(this.heading, this.body);
}

/// Reusable in-app legal document page (Terms, Privacy, etc.).
class LegalPage extends StatelessWidget {
  final String title;
  final IconData icon;
  final String intro;
  final String lastUpdated;
  final List<LegalSection> sections;

  const LegalPage({
    super.key,
    required this.title,
    required this.icon,
    required this.intro,
    required this.lastUpdated,
    required this.sections,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundCream,
      appBar: AppBar(
        title: Text(title),
        leading: const BackButton(),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 130),
            children: [
              // Header card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primaryBlue, Color(0xFF2D3A8C)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(30),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(icon, color: Colors.white, size: 26),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 4),
                          Text('Last updated: $lastUpdated', style: TextStyle(color: Colors.white.withAlpha(170), fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn().slideY(begin: 0.08, end: 0),
              const SizedBox(height: 20),

              Text(
                intro,
                style: const TextStyle(color: AppColors.textMedium, fontSize: 14, height: 1.6),
              ),
              const SizedBox(height: 12),

              for (int i = 0; i < sections.length; i++)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            margin: const EdgeInsets.only(top: 1),
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: AppColors.primaryBlue.withAlpha(20),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            alignment: Alignment.center,
                            child: Text('${i + 1}', style: const TextStyle(color: AppColors.primaryBlue, fontWeight: FontWeight.w800, fontSize: 12)),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              sections[i].heading,
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.textDark),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.only(left: 34),
                        child: Text(
                          sections[i].body,
                          style: const TextStyle(color: AppColors.textMedium, fontSize: 13.5, height: 1.6),
                        ),
                      ),
                    ],
                  ),
                ).animate().fadeIn(delay: (40 * i).ms),

              const SizedBox(height: 28),
              Center(
                child: Text(
                  'BlueDot · Climate Action, Gamified.',
                  style: TextStyle(color: AppColors.textLight.withAlpha(180), fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Concrete documents ────────────────────────────────────────────────────────

class TermsPage extends StatelessWidget {
  const TermsPage({super.key});

  @override
  Widget build(BuildContext context) => const LegalPage(
        title: 'Terms & Conditions',
        icon: Icons.description_outlined,
        lastUpdated: '12 June 2026',
        intro:
            'Welcome to BlueDot. By creating an account and using our app, you agree to these Terms & '
            'Conditions. Please read them carefully — they govern your participation in tree-tagging, '
            'volunteer drives, donations, and the rewards programme.',
        sections: [
          LegalSection(
            'Eligibility & Account',
            'You must be at least 13 years old to use BlueDot. You are responsible for keeping your '
                'account and registered phone number secure. You agree to provide accurate information '
                'and to keep it up to date in your profile.',
          ),
          LegalSection(
            'Tree Tagging & Verification',
            'Impact points are awarded for genuine, on-location tree tags verified through GPS and image '
                'recognition. Submitting false, duplicate, or fraudulent tags may result in point reversal '
                'or account suspension.',
          ),
          LegalSection(
            'Volunteer Drives & Passes',
            'Event passes (QR codes) are personal and non-transferable. Attendance and contribution '
                'records are used to generate volunteer certificates. BlueDot is not liable for personal '
                'injury or loss during third-party organised drives.',
          ),
          LegalSection(
            'Donations & 80G Receipts',
            'Donations made through the app are routed to verified restoration campaigns. 80G tax '
                'receipts are issued only against a valid PAN and successfully settled payments. Donations '
                'are generally non-refundable except as required by law.',
          ),
          LegalSection(
            'Rewards & Points',
            'Impact points and badges have no monetary value, cannot be exchanged for cash, and may be '
                'adjusted to correct errors or abuse. We may change the rewards structure with notice in '
                'the app.',
          ),
          LegalSection(
            'Acceptable Use',
            'You agree not to misuse the platform, attempt to game the rewards system, upload unlawful '
                'content, or interfere with other users. We may suspend accounts that violate these terms.',
          ),
          LegalSection(
            'Changes to These Terms',
            'We may update these Terms from time to time. Continued use of BlueDot after changes take '
                'effect constitutes acceptance of the revised Terms.',
          ),
          LegalSection(
            'Contact',
            'Questions about these Terms? Reach us at support@bluedot.org.',
          ),
        ],
      );
}

class PrivacyPage extends StatelessWidget {
  const PrivacyPage({super.key});

  @override
  Widget build(BuildContext context) => const LegalPage(
        title: 'Privacy Policy',
        icon: Icons.privacy_tip_outlined,
        lastUpdated: '12 June 2026',
        intro:
            'Your privacy matters to us. This policy explains what information BlueDot collects, how we '
            'use it, and the choices you have. We collect only what we need to run the climate-action '
            'experience.',
        sections: [
          LegalSection(
            'Information We Collect',
            'Account details (name, phone, email, city), tree-tag locations and photos, event '
                'participation, donation history, and device information such as app version and push token.',
          ),
          LegalSection(
            'How We Use Your Data',
            'To verify tree tags, award impact points, issue volunteer certificates and 80G receipts, '
                'show your position on leaderboards, send relevant notifications, and improve the app.',
          ),
          LegalSection(
            'Location Data',
            'Location is used only while tagging a tree or suggesting a restoration site, to verify the '
                'contribution is genuine. We do not track your location in the background.',
          ),
          LegalSection(
            'Sharing & Disclosure',
            'We never sell your personal data. We share limited data with payment processors (for '
                'donations), our media CDN (for photos), and authorities only where legally required.',
          ),
          LegalSection(
            'Data Security',
            'Sensitive details such as your PAN are encrypted. We apply industry-standard safeguards, '
                'though no system is perfectly secure. Report concerns to us promptly.',
          ),
          LegalSection(
            'Your Rights',
            'You can view and edit your profile, request a copy of your data, or delete your account from '
                'Settings. Deleting your account removes your personal data, subject to legal retention of '
                'donation and tax records.',
          ),
          LegalSection(
            'Notifications',
            'You control push and email notifications from Settings. Transactional messages (like receipts) '
                'may still be sent where required.',
          ),
          LegalSection(
            'Contact',
            'For privacy questions or data requests, contact privacy@bluedot.org.',
          ),
        ],
      );
}
