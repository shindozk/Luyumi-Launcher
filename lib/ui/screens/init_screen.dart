import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/utils/bun_installer.dart';
import '../../core/managers/backend_manager.dart';
import '../../core/providers/logs_provider.dart';
import 'home_screen.dart';

class InitScreen extends StatefulWidget {
  const InitScreen({super.key});

  @override
  State<InitScreen> createState() => _InitScreenState();
}

class _InitScreenState extends State<InitScreen> with TickerProviderStateMixin {
  late AnimationController _logoController;
  late AnimationController _splitController;
  late AnimationController _pulseController;

  late Animation<double> _logoScale;
  late Animation<double> _logoOpacity;
  late Animation<Offset> _logoSlide;
  
  late Animation<Offset> _textSlide;
  late Animation<double> _textOpacity;

  String _statusMessage = 'Initializing...';
  double _progress = 0.0;
  bool _hasError = false;
  String? _errorMessage;
  bool _animationsComplete = false;

  @override
  void initState() {
    super.initState();

    // 1. Initial Logo Appearance (Pop-in)
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _logoScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: Curves.easeOutBack, // Modern pop effect
      ),
    );

    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeIn),
      ),
    );

    // 2. Split Animation (Logo Left, Text Reveal)
    _splitController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    // Logo slides slightly left to make room
    _logoSlide = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(-0.2, 0.0),
    ).animate(
      CurvedAnimation(
        parent: _splitController,
        curve: Curves.easeInOutCubic,
      ),
    );

    // Text slides out from "behind" the logo (Right to Center-ish)
    _textSlide = Tween<Offset>(
      begin: const Offset(0.5, 0.0), // Starts closer to logo center
      end: const Offset(0.05, 0.0), // Ends slightly right of center
    ).animate(
      CurvedAnimation(
        parent: _splitController,
        curve: Curves.easeOutCubic,
      ),
    );

    _textOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _splitController,
        curve: const Interval(0.2, 1.0, curve: Curves.easeIn),
      ),
    );

    // Pulse animation (subtle breathing)
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    _startAnimationSequence();
  }

  Future<void> _startAnimationSequence() async {
    // Phase 1: Logo pops in
    await _logoController.forward();
    
    // Short pause for impact
    await Future.delayed(const Duration(milliseconds: 200));

    // Phase 2: Split and Reveal Text
    await _splitController.forward();

    setState(() => _animationsComplete = true);
    await Future.delayed(const Duration(milliseconds: 300));
    _initialize();
  }

  @override
  void dispose() {
    _logoController.dispose();
    _splitController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    try {
      setState(() {
        _statusMessage = 'Checking Bun installation...';
        _progress = 0.1;
      });
      await Future.delayed(const Duration(milliseconds: 500));

      final isBunInstalled = await BunInstaller.isBunInstalled();

      if (!isBunInstalled) {
        setState(() {
          _statusMessage = 'Installing Bun.js...';
          _progress = 0.2;
        });

        final installed = await BunInstaller.installBun(
          onProgress: (message, progress) {
            setState(() {
              _statusMessage = message;
              _progress = 0.2 + (progress * 0.2); // 0.2 -> 0.4
            });
          },
        );

        if (!installed) {
          throw Exception(
            'Failed to install Bun. Please install manually from https://bun.sh',
          );
        }
      } else {
        setState(() => _progress = 0.4);
      }

      setState(() {
        _statusMessage = 'Preparing backend environment...';
        _progress = 0.45;
      });
      await Future.delayed(const Duration(milliseconds: 500));

      await BackendManager.rebuildBackend(
        onProgress: (message, progress) {
          setState(() {
            _statusMessage = message;
            // Map 0.0-1.0 from backend to 0.45-0.90
            _progress = 0.45 + (progress * 0.45);
          });
        },
      );

      setState(() {
        _statusMessage = 'Starting backend services...';
        _progress = 0.95;
      });
      await Future.delayed(const Duration(milliseconds: 500));

      await BackendManager.init();

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
    } catch (e) {
      setState(() {
        _hasError = true;
        _errorMessage = e.toString();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF09090B),
      body: Stack(
        children: [
          // Animated background particles
          ...List.generate(20, (index) {
            return AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                final offset = _pulseController.value * 100;
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
                    // Animated Logo
                    AnimatedBuilder(
                      animation: Listenable.merge([
                        _logoController,
                        _splitController,
                        _pulseController,
                      ]),
                      builder: (context, child) {
                        final pulse = _animationsComplete
                            ? _pulseController.value * 0.03
                            : 0.0;
                        return SlideTransition(
                          position: _logoSlide,
                          child: Transform.scale(
                            scale: _logoScale.value * (1.0 + pulse),
                            child: Opacity(
                              opacity: _logoOpacity.value,
                              child: Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Theme.of(context).primaryColor
                                          .withValues(
                                            alpha:
                                                0.3 +
                                                (_pulseController.value * 0.2),
                                          ),
                                      blurRadius:
                                          30 + (_pulseController.value * 10),
                                      spreadRadius: 5,
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(40),
                                  child: Image.asset(
                                    'lib/assets/logo/Luyumi-Launcher_transparent.png',
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),

                    // Animated spacing
                    AnimatedBuilder(
                      animation: _splitController,
                      builder: (context, child) {
                        return SizedBox(width: 24 * _textOpacity.value);
                      },
                    ),

                    // Animated Title Text
                    SlideTransition(
                      position: _textSlide,
                      child: FadeTransition(
                        opacity: _textOpacity,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ShaderMask(
                              shaderCallback: (bounds) => LinearGradient(
                                colors: [
                                  Theme.of(context).primaryColor,
                                  Theme.of(
                                    context,
                                  ).primaryColor.withValues(alpha: 0.7),
                                ],
                              ).createShader(bounds),
                              child: Text(
                                'LUYUMI',
                                style: GoogleFonts.rajdhani(
                                  fontSize: 42,
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
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.white38,
                                letterSpacing: 4,
                                height: 1.0,
                              ),
                            ),
                          ],
                        ),
                      ),
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
                    width: 400,
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
                      children: [
                        Icon(
                          Icons.error_outline_rounded,
                          color: Colors.red[400],
                          size: 32,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _errorMessage ?? 'Unknown error',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: Colors.red[300],
                            height: 1.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: GestureDetector(
                            onTap: _retry,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 32,
                                vertical: 14,
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
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'RETRY',
                                    style: GoogleFonts.rajdhani(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 1.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
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
