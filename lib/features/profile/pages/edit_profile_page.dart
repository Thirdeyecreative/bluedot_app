import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../auth/providers/auth_provider.dart';

class EditProfilePage extends ConsumerStatefulWidget {
  const EditProfilePage({super.key});

  @override
  ConsumerState<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends ConsumerState<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _cityCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final user = ref.read(currentUserProvider);
    _nameCtrl = TextEditingController(text: user?.fullName ?? '');
    _emailCtrl = TextEditingController(text: user?.email ?? '');
    _cityCtrl = TextEditingController(text: user?.city ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _cityCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    // Demo: persist to local state. (Wire to PATCH /app/profile when the
    // app-side profile endpoint lands.)
    await Future<void>.delayed(const Duration(milliseconds: 600));
    ref.read(currentUserProvider.notifier).update(
          fullName: _nameCtrl.text.trim(),
          email: _emailCtrl.text.trim(),
          city: _cityCtrl.text.trim(),
        );
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profile updated'), backgroundColor: AppColors.forestGreen),
    );
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final initial = (user?.fullName?.isNotEmpty ?? false)
        ? user!.fullName!.trim()[0].toUpperCase()
        : '?';

    return Scaffold(
      backgroundColor: AppColors.backgroundCream,
      appBar: AppBar(
        title: const Text('Edit Profile'),
        leading: const BackButton(),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 130),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Avatar with edit affordance
                  Center(
                    child: Stack(
                      children: [
                        Container(
                          width: 96,
                          height: 96,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [AppColors.primaryBlue, Color(0xFF2D3A8C)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(color: AppColors.primaryBlue.withAlpha(60), blurRadius: 16, offset: const Offset(0, 6)),
                            ],
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            initial,
                            style: const TextStyle(color: Colors.white, fontSize: 38, fontWeight: FontWeight.w800),
                          ),
                        ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: GestureDetector(
                            onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Photo upload coming soon')),
                            ),
                            child: Container(
                              padding: const EdgeInsets.all(7),
                              decoration: BoxDecoration(
                                color: AppColors.primaryYellow,
                                shape: BoxShape.circle,
                                border: Border.all(color: AppColors.backgroundCream, width: 3),
                              ),
                              child: const Icon(Icons.camera_alt_rounded, size: 16, color: AppColors.textDark),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ).animate().fadeIn().scaleXY(begin: 0.85, end: 1, curve: Curves.easeOut),
                  const SizedBox(height: 28),

                  _FieldLabel('Full Name'),
                  TextFormField(
                    controller: _nameCtrl,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      hintText: 'Your name',
                      prefixIcon: Icon(Icons.person_outline_rounded),
                    ),
                    validator: (v) => (v == null || v.trim().length < 2) ? 'Please enter your name' : null,
                  ),
                  const SizedBox(height: 18),

                  _FieldLabel('Email'),
                  TextFormField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      hintText: 'you@example.com',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                    validator: (v) {
                      final value = v?.trim() ?? '';
                      if (value.isEmpty) return null; // optional
                      final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value);
                      return ok ? null : 'Enter a valid email';
                    },
                  ),
                  const SizedBox(height: 18),

                  _FieldLabel('City'),
                  TextFormField(
                    controller: _cityCtrl,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      hintText: 'Your city',
                      prefixIcon: Icon(Icons.location_city_rounded),
                    ),
                  ),
                  const SizedBox(height: 18),

                  _FieldLabel('Phone'),
                  TextFormField(
                    initialValue: user?.phone ?? '',
                    enabled: false,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.phone_rounded),
                      suffixIcon: const Icon(Icons.lock_outline_rounded, size: 18, color: AppColors.textLight),
                      fillColor: AppColors.borderLight.withAlpha(60),
                      filled: true,
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.only(top: 6, left: 4),
                    child: Text(
                      'Your phone number is your login ID and cannot be changed.',
                      style: TextStyle(fontSize: 11, color: AppColors.textLight),
                    ),
                  ),
                  const SizedBox(height: 32),

                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: _saving
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.check_rounded),
                      label: const Text('Save Changes'),
                      style: ElevatedButton.styleFrom(shape: const StadiumBorder()),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8, left: 2),
        child: Text(
          text,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textDark),
        ),
      );
}
