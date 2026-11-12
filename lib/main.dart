import 'dart:ui';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:media_kit/media_kit.dart';
import 'core/config/api_config.dart';
import 'core/router/app_router.dart';
import 'core/services/fcm_push_adapter.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/connectivity_gate.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };

  MediaKit.ensureInitialized();
  await ApiConfig.init();
  
  await Supabase.initialize(
    url: 'https://luklinptoewincftfpse.supabase.co',
    publishableKey: 'sb_publishable_x29m8ohDHQAZEF-2VR62NA_vPFhHtS4',
  );

  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark);
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);
  runApp(const ProviderScope(child: BlueDotApp()));
}

class BlueDotApp extends ConsumerWidget {
  const BlueDotApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'BlueDot',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      routerConfig: router,
      builder: (context, child) => ConnectivityGate(
        child: child ?? const SizedBox.shrink(),
      ),
    );
  }
}
