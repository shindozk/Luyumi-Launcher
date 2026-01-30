import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/managers/backend_manager.dart';
import '../../core/utils/python_installer.dart';
import '../../core/services/update_service.dart';
import '../../core/providers/logs_provider.dart';
import '../../core/services/audio_service.dart';
import 'home_screen.dart';

class InitScreen extends StatefulWidget {
  const InitScreen({super.key});

  @override
  State<InitScreen> createState() => _InitScreenState();
}

class _InitScreenState extends State<InitScreen> with TickerProviderStateMixin {
  late AnimationController _entranceController;
  late AnimationController _hoverController; // For idle floating effect

  late Animation<double> _logoScale;
  late Animation<double> _logoRotation;
  late Animation<double> _textReveal;
  late Animation<double> _textOpacity;
  late Animation<Offset> _textSlide;

  String _statusMessage = 'Initializing...';
  double _progress = 0.0;
  bool _hasError = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();

    // Main Entrance Controller
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    // Continuous Hover Controller (Breathing effect)
    _hoverController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    // 1. Logo Zoom & Spin (0.0 -> 0.6)
    _logoScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.0, 0.6, curve: Curves.elasticOut),
      ),
    );

    _logoRotation = Tween<double>(begin: -0.5, end: 0.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOutBack),
      ),
    );

    // 2. Text Reveal (Expansion) (0.5 -> 1.0)
    // Controls the width expansion of the text container
    _textReveal = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.5, 0.9, curve: Curves.easeOutExpo),
      ),
    );

    _textOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.6, 1.0, curve: Curves.easeIn),
      ),
    );

    _textSlide = Tween<Offset>(begin: const Offset(-0.2, 0.0), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _entranceController,
            curve: const Interval(0.5, 1.0, curve: Curves.easeOutCubic),
          ),
        );

    _startAnimationSequence();
  }

  Future<void> _startAnimationSequence() async {
    AudioService().playIntro();
    // Start animation
    await _entranceController.forward();

    // Proceed with initialization
    _initialize();
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _hoverController.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    try {
      // 0. Check for Updates
      setState(() {
        _statusMessage = 'Checking for updates...';
        _progress = 0.05;
      });

      final updateService = UpdateService();
      final updateInfo = await updateService.checkForUpdates();

      if (updateInfo.hasUpdate) {
        setState(() {
          _statusMessage = 'Updating to v${updateInfo.latestVersion}...';
          _progress = 0.1;
        });

        await updateService.performUpdate(updateInfo.downloadUrl, (
          message,
          progress,
        ) {
          setState(() {
            _statusMessage = message;
            // Map update progress (0-1) to UI progress (0.1-0.3)
            _progress = 0.1 + (progress * 0.2);
          });
        });
        // The app will exit inside performUpdate, so we stop here.
        return;
      }

      // 1. Check Python
      setState(() {
        _statusMessage = 'Checking Python installation...';
        _progress = 0.3;
      });
      await Future.delayed(const Duration(milliseconds: 500));

      final isPythonInstalled = await PythonInstaller.isPythonInstalled();

      if (!isPythonInstalled) {
        setState(() {
          _statusMessage = 'Installing Python (Required)...';
          _progress = 0.35;
        });

        final installed = await PythonInstaller.installPython(
          onProgress: (message, progress) {
            setState(() {
              _statusMessage = message;
              _progress = 0.35 + (progress * 0.15); // 0.35 -> 0.5
            });
          },
        );

        if (!installed) {
          throw Exception(
            'Failed to install Python. Please install manually from python.org',
          );
        }
      } else {
        setState(() => _progress = 0.5);
      }

      // 2. Install/Update Dependencies
      setState(() {
        _statusMessage = 'Updating backend dependencies...';
        _progress = 0.55;
      });

      await BackendManager.installDependencies(
        onProgress: (message, progress) {
          setState(() {
            _statusMessage = message;
            _progress = 0.55 + (progress * 0.35); // 0.55 -> 0.90
          });
        },
      );

      setState(() {
        _statusMessage = 'Starting backend services...';
        _progress = 0.95;
      });
      await Future.delayed(const Duration(milliseconds: 500));

      await BackendManager.init();

      // Give backend a moment to stabilize
      await Future.delayed(const Duration(milliseconds: 1000));

      // Start backend logs polling now that backend is ready
      if (mounted) {
        context.read<LogsProvider>().startBackendPolling();
      }

      setState(() {
        _statusMessage = 'Ready!';
        _progress = 1.0;
      });
      await Future.delayed(const Duration(milliseconds: 800));

      if (mounted) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                const HomeScreen(),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
                  return FadeTransition(opacity: animation, child: child);
                },
            transitionDuration: const Duration(milliseconds: 600),
          ),
        );
      }
    } catch (e, stack) {
      // Log the full error for debugging
      print('ERROR: $e');
      print('STACK: $stack');

      setState(() {
        _hasError = true;
        // Make error message more readable
        String errorMsg = e.toString();
        if (errorMsg.startsWith('Exception: ')) {
          errorMsg = errorMsg.substring(11);
        }
        _errorMessage = errorMsg;
        _statusMessage = 'Initialization failed';
      });
    }
  }

  Future<void> _retry() async {
    setState(() {
      _hasError = false;
      _errorMessage = null;
      _progress = 0.0;
      _statusMessage = 'Initializing...';
    });
    await _initialize();
  }

  Future<void> _copyErrorToClipboard() async {
    if (_errorMessage == null) return;

    final fullError =
        '''
═══════════════════════════════════════════════════════════════════════════════
LUYUMI LAUNCHER ERROR REPORT
═══════════════════════════════════════════════════════════════════════════════

ERROR MESSAGE:
$_errorMessage

STATUS: $_statusMessage

═══════════════════════════════════════════════════════════════════════════════
SYSTEM INFORMATION:
═══════════════════════════════════════════════════════════════════════════════

Platform: ${Theme.of(context).platform}
Timestamp: ${DateTime.now().toIso8601String()}

═══════════════════════════════════════════════════════════════════════════════

Please share this error report when requesting support.
''';

    await Clipboard.setData(ClipboardData(text: fullError));

    // Show snackbar confirmation
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error copied to clipboard',
            style: GoogleFonts.inter(color: Colors.white),
          ),
          backgroundColor: Colors.green[700],
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF09090B),
      body: Stack(
        children: [
          // Animated background particles
          ...List.generate(20, (index) {
            return AnimatedBuilder(
              animation: _hoverController,
              builder: (context, child) {
                final offset = _hoverController.value * 50;
                return Positioned(
                  left: (index * 100.0) % MediaQuery.of(context).size.width,
                  top:
                      (index * 50.0 + offset) %
                      MediaQuery.of(context).size.height,
                  child: Container(
                    width: 2,
                    height: 2,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                  ),
                );
              },
            );
          }),

          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo and Title Row
                Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Animated Logo (Elastic Zoom & Hover)
                    RotationTransition(
                      turns: _logoRotation,
                      child: ScaleTransition(
                        scale: _logoScale,
                        child: AnimatedBuilder(
                          animation: _hoverController,
                          builder: (context, child) {
                            return Transform.translate(
                              offset: Offset(0, -5 * _hoverController.value),
                              child: Container(
                                width: 90,
                                height: 90,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Theme.of(
                                        context,
                                      ).primaryColor.withValues(alpha: 0.4),
                                      blurRadius:
                                          20 + (10 * _hoverController.value),
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(45),
                                  child: Image.asset(
                                    'lib/assets/logo/Luyumi-Launcher_transparent.png',
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),

                    // Text Reveal (Expands width from left)
                    AnimatedBuilder(
                      animation: _textReveal,
                      builder: (context, child) {
                        return SizeTransition(
                          sizeFactor: _textReveal,
                          axis: Axis.horizontal,
                          axisAlignment: -1.0,
                          child: Padding(
                            padding: const EdgeInsets.only(left: 20.0),
                            child: FadeTransition(
                              opacity: _textOpacity,
                              child: SlideTransition(
                                position: _textSlide,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    ShaderMask(
                                      shaderCallback: (bounds) =>
                                          LinearGradient(
                                            colors: [
                                              Theme.of(context).primaryColor,
                                              Theme.of(context).primaryColor
                                                  .withValues(alpha: 0.7),
                                            ],
                                          ).createShader(bounds),
                                      child: Text(
                                        'LUYUMI',
                                        style: GoogleFonts.rajdhani(
                                          fontSize: 48,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.white,
                                          letterSpacing: 2,
                                          height: 1.0,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      'LAUNCHER',
                                      style: GoogleFonts.rajdhani(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white38,
                                        letterSpacing: 6,
                                        height: 1.0,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 80),

                // Status Message
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Text(
                    _statusMessage,
                    key: ValueKey(_statusMessage),
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: _hasError ? Colors.redAccent : Colors.white60,
                      letterSpacing: 0.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

                const SizedBox(height: 32),

                // Progress Section
                if (!_hasError) ...[
                  SizedBox(
                    width: 350,
                    child: Column(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Stack(
                            children: [
                              Container(
                                height: 6,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.05),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeOut,
                                width: 350 * _progress,
                                height: 6,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Theme.of(
                                        context,
                                      ).primaryColor.withValues(alpha: 0.8),
                                      Theme.of(context).primaryColor,
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Theme.of(
                                        context,
                                      ).primaryColor.withValues(alpha: 0.4),
                                      blurRadius: 8,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '${(_progress * 100).toInt()}%',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Theme.of(context).primaryColor,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Error Display
                if (_hasError) ...[
                  const SizedBox(height: 24),
                  Container(
                    width: 450,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.redAccent.withValues(alpha: 0.2),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.error_outline_rounded,
                          color: Colors.red[400],
                          size: 32,
                        ),
                        const SizedBox(height: 16),
                        // Error Title
                        Text(
                          'Initialization Failed',
                          style: GoogleFonts.rajdhani(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.red[300],
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Error Message (scrollable if too long)
                        Container(
                          constraints: const BoxConstraints(maxHeight: 120),
                          child: SingleChildScrollView(
                            child: Text(
                              _errorMessage ?? 'Unknown error',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: Colors.red[200],
                                height: 1.6,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        // Buttons Row
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Copy Button
                            MouseRegion(
                              cursor: SystemMouseCursors.click,
                              child: GestureDetector(
                                onTap: _copyErrorToClipboard,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[800],
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: Colors.grey[600]!,
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.content_copy_rounded,
                                        color: Colors.white,
                                        size: 16,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'COPY ERROR',
                                        style: GoogleFonts.rajdhani(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 1.2,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Retry Button
                            MouseRegion(
                              cursor: SystemMouseCursors.click,
                              child: GestureDetector(
                                onTap: _retry,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).primaryColor,
                                    borderRadius: BorderRadius.circular(10),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Theme.of(
                                          context,
                                        ).primaryColor.withValues(alpha: 0.3),
                                        blurRadius: 12,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.refresh_rounded,
                                        color: Colors.white,
                                        size: 16,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'RETRY',
                                        style: GoogleFonts.rajdhani(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 1.2,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
