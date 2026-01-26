import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_acrylic/flutter_acrylic.dart';
import 'package:window_manager/window_manager.dart';
import 'package:provider/provider.dart';
import 'core/managers/profile_manager.dart';
import 'core/managers/backend_manager.dart';
import 'core/providers/logs_provider.dart';
import 'core/providers/game_status_provider.dart';
import 'ui/theme/app_theme.dart';
import 'ui/screens/init_screen.dart';
import 'package:easy_localization/easy_localization.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  EasyLocalization.logger.enableLevels = [];
  await EasyLocalization.ensureInitialized();

  // Initialize Profile Manager
  await ProfileManager.init();

  // Backend initialization is now handled by InitScreen

  await windowManager.ensureInitialized();
  final supportsAcrylic = Platform.isWindows || Platform.isMacOS;
  if (supportsAcrylic) {
    await Window.initialize();
  }

  // Set window options
  WindowOptions windowOptions = const WindowOptions(
    size: Size(1100, 700),
    center: true,
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.hidden, // Custom title bar
    title: 'Luyumi Launcher',
  );

  windowManager.addListener(_WindowListener());

  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
    if (supportsAcrylic) {
      await Window.setEffect(
        effect: WindowEffect.acrylic,
        color: const Color(0xCC09090B),
        dark: true,
      );
    }
  });

  // Handle application exit (Ctrl+C or process termination)
  ProcessSignal.sigint.watch().listen((_) {
    BackendManager.stop();
    exit(0);
  });

  runApp(
    EasyLocalization(
      supportedLocales: const [
        Locale('en'),
        Locale('pt'),
        Locale('es'),
        Locale('zh'),
        Locale('ja'),
        Locale('ko'),
        Locale('ru'),
        Locale('fr'),
      ],
      path: 'lib/assets/locales',
      fallbackLocale: const Locale('en'),
      child: const MyApp(),
    ),
  );
}

class _WindowListener extends WindowListener {
  @override
  void onWindowClose() async {
    // Stop backend BEFORE closing window
    BackendManager.stop();

    // Give backend time to cleanup
    await Future.delayed(const Duration(milliseconds: 500));

    // Destroy window and exit
    await windowManager.destroy();
    exit(0);
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => LogsProvider()..init(),
          lazy: false,
        ),
        ChangeNotifierProvider(
          create: (_) => GameStatusProvider(),
        ),
      ],
      child: MaterialApp(
        title: 'Luyumi Launcher',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        localizationsDelegates: context.localizationDelegates,
        supportedLocales: context.supportedLocales,
        locale: context.locale,
        home: const InitScreen(),
      ),
    );
  }
}
