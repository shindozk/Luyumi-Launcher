import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../core/models/game_status.dart';
import '../animations.dart';
import 'modern_progress_bar.dart';

class GameActionPanel extends StatelessWidget {
  final bool isLoading;
  final bool isGameStatusLoading;
  final bool isGameRunning;
  final bool isOpeningUpdateUrl;
  final bool showProgress;
  final String? progressMessage;
  final int? progressPercent;
  final GameStatus? gameStatus;
  final String elapsedTime;
  final bool launcherUpdateRequired;
  final bool firstLaunchUpdateRequired;
  final VoidCallback onAction;

  const GameActionPanel({
    super.key,
    required this.isLoading,
    required this.isGameStatusLoading,
    required this.isGameRunning,
    required this.isOpeningUpdateUrl,
    required this.showProgress,
    required this.progressMessage,
    required this.progressPercent,
    required this.gameStatus,
    required this.elapsedTime,
    required this.launcherUpdateRequired,
    required this.firstLaunchUpdateRequired,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final isPrimaryActionDisabled =
        isLoading || isGameStatusLoading || isGameRunning || isOpeningUpdateUrl;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (gameStatus != null) ...[
              Padding(
                padding: const EdgeInsets.only(
                  bottom: 8.0,
                ), // Align with version text height on the right
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: gameStatus!.installed
                            ? Theme.of(context).primaryColor
                            : Colors.orange,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      "Launcher v1.0.0",
                      style: GoogleFonts.jetBrainsMono(
                        color: Colors.white38,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ] else
              const SizedBox(),

            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 500),
                      reverseDuration: const Duration(milliseconds: 400),
                      switchInCurve: Curves.easeOutBack,
                      switchOutCurve: Curves.easeInQuad,
                      transitionBuilder:
                          (Widget child, Animation<double> animation) {
                            return FadeTransition(
                              opacity: animation,
                              child: SizeTransition(
                                sizeFactor: animation,
                                axis: Axis.horizontal,
                                axisAlignment: -1,
                                child: child,
                              ),
                            );
                          },
                      child: showProgress
                          ? Container(
                              key: const ValueKey('progress_bar'),
                              width: 400,
                              padding: const EdgeInsets.only(right: 16),
                              child: ModernProgressBar(
                                label: progressMessage ?? tr('processing'),
                                progress: progressPercent != null
                                    ? progressPercent! / 100
                                    : 0,
                                accentColor: Theme.of(context).primaryColor,
                              ),
                            )
                          : const SizedBox.shrink(key: ValueKey('empty')),
                    ),
                    AnimatedModernButton(
                      text: _getPrimaryButtonLabel(),
                      icon: isGameRunning
                          ? Icons.stop_circle_outlined
                          : Icons.play_arrow_rounded,
                      onPressed: isPrimaryActionDisabled ? null : onAction,
                      isPrimary: true,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Visibility(
                  visible: (gameStatus != null),
                  maintainSize: true,
                  maintainAnimation: true,
                  maintainState: true,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 4.0),
                    child: Text(
                      gameStatus?.installedVersion != null
                          ? "v${gameStatus!.installedVersion} ${gameStatus!.updateAvailable ? '(Update: v${gameStatus!.latestVersion})' : ''}"
                          : "Latest: v${gameStatus?.latestVersion ?? '...'}",
                      style: GoogleFonts.jetBrainsMono(
                        color: Colors.white24,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  String _getPrimaryButtonLabel() {
    if (isGameRunning) {
      return tr('running_with_time', namedArgs: {'time': elapsedTime});
    }

    if (isLoading) {
      if (gameStatus != null && !gameStatus!.installed) {
        return tr('status_installing');
      }
      if (gameStatus != null && gameStatus!.updateAvailable) {
        return tr('status_updating');
      }
      return tr('status_launching');
    }

    if (isGameStatusLoading || gameStatus == null) return tr('checking');
    if (launcherUpdateRequired) return tr('update_launcher');
    if (firstLaunchUpdateRequired) return tr('update_game');
    if (!gameStatus!.installed) return tr('install');
    if (gameStatus!.updateAvailable) return tr('update');
    return tr('play_now');
  }
}
