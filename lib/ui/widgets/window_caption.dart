import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import '../../core/services/audio_service.dart';

class WindowCaption extends StatelessWidget {
  final String title;

  const WindowCaption({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 32,
      child: Row(
        children: [
          const SizedBox(width: 16),
          Text(
            title,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.white54,
              fontSize: 12,
            ),
          ),
          Expanded(
            child: GestureDetector(
              onPanStart: (details) {
                windowManager.startDragging();
              },
              behavior: HitTestBehavior.translucent,
              child: Container(),
            ),
          ),
          WindowCaptionButton.minimize(
            onPressed: () => windowManager.minimize(),
          ),
          WindowCaptionButton.maximize(
            onPressed: () async {
              if (await windowManager.isMaximized()) {
                windowManager.restore();
              } else {
                windowManager.maximize();
              }
            },
          ),
          WindowCaptionButton.close(
            onPressed: () => windowManager.close(),
          ),
        ],
      ),
    );
  }
}

class WindowCaptionButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final bool isClose;

  const WindowCaptionButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.isClose = false,
  });

  factory WindowCaptionButton.minimize({required VoidCallback onPressed}) {
    return WindowCaptionButton(icon: Icons.minimize, onPressed: onPressed);
  }

  factory WindowCaptionButton.maximize({required VoidCallback onPressed}) {
    return WindowCaptionButton(icon: Icons.crop_square, onPressed: onPressed);
  }

  factory WindowCaptionButton.close({required VoidCallback onPressed}) {
    return WindowCaptionButton(
        icon: Icons.close, onPressed: onPressed, isClose: true);
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        AudioService().playClick();
        onPressed();
      },
      hoverColor: isClose ? Colors.red : Colors.white.withValues(alpha: 0.1),
      child: SizedBox(
        width: 46,
        height: 32,
        child: Icon(
          icon,
          size: 16,
          color: Colors.white70,
        ),
      ),
    );
  }
}
