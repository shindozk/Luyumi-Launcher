import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ModernProgressBar extends StatefulWidget {
  final String label;
  final double progress; // 0.0 to 1.0
  final Color accentColor;

  const ModernProgressBar({
    super.key,
    required this.label,
    required this.progress,
    required this.accentColor,
  });

  @override
  State<ModernProgressBar> createState() => _ModernProgressBarState();
}

class _ModernProgressBarState extends State<ModernProgressBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  double _normalizeProgress(double value) {
    if (value.isNaN || value.isInfinite) return 0.0;
    if (value < 0) return 0.0;
    if (value > 1) return 1.0;
    return value;
  }

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    if (_normalizeProgress(widget.progress) >= 1.0) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(ModernProgressBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    final progress = _normalizeProgress(widget.progress);
    if (progress >= 1.0 && !(_pulseController.isAnimating)) {
      _pulseController.repeat(reverse: true);
    } else if (progress < 1.0 && _pulseController.isAnimating) {
      _pulseController.stop();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progress = _normalizeProgress(widget.progress);
    final isComplete = progress >= 1.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                widget.label,
                style: GoogleFonts.inter(
                  color: Colors.white70,
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                  letterSpacing: 0.5,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              "${(progress * 100).toInt()}%",
              style: GoogleFonts.jetBrainsMono(
                color: isComplete ? Colors.greenAccent : widget.accentColor,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        AnimatedBuilder(
          animation: _pulseController,
          builder: (context, child) {
            final glowIntensity = isComplete ? _pulseController.value : 0.0;

            return Container(
              height: 6,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(3),
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return Stack(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 600),
                        curve: Curves.easeOutCubic,
                        width: constraints.maxWidth * progress,
                        height: 6,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              widget.accentColor.withValues(alpha: 0.8),
                              isComplete
                                  ? Colors.greenAccent
                                  : widget.accentColor,
                            ],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                          borderRadius: BorderRadius.circular(3),
                          boxShadow: [
                            BoxShadow(
                              color:
                                  (isComplete
                                          ? Colors.greenAccent
                                          : widget.accentColor)
                                      .withValues(
                                        alpha: 0.3 + (glowIntensity * 0.4),
                                      ),
                              blurRadius: 8 + (glowIntensity * 4),
                              spreadRadius: 0,
                            ),
                          ],
                        ),
                      ),
                      // Shimmer overlay when complete
                      if (isComplete)
                        Positioned.fill(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: FractionallySizedBox(
                              alignment: Alignment.centerLeft,
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.white.withValues(alpha: 0),
                                      Colors.white.withValues(alpha: 0.2),
                                      Colors.white.withValues(alpha: 0),
                                    ],
                                    stops: const [0.0, 0.5, 1.0],
                                    begin: Alignment(
                                      -1.0 + (_pulseController.value * 3),
                                      0.0,
                                    ),
                                    end: Alignment(
                                      0.0 + (_pulseController.value * 3),
                                      0.0,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            );
          },
        ),
      ],
    );
  }
}
