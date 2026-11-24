import 'dart:io';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

class AiAnalyzingOverlay extends StatelessWidget {
  final File? backdropImage;
  const AiAnalyzingOverlay({super.key, this.backdropImage});

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xff101c42),
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox.square(
                dimension: 140,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    const CircularProgressIndicator(
                      color: AppColors.primaryYellow,
                      backgroundColor: Colors.white24,
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: ClipOval(
                        child: backdropImage == null
                            ? const Icon(Icons.eco, color: Colors.white)
                            : Image.file(
                                backdropImage!,
                                fit: BoxFit.cover,
                                excludeFromSemantics: true,
                              ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              Semantics(
                liveRegion: true,
                child: const Text(
                  'Identifying your tree',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Your scan result will appear here.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
