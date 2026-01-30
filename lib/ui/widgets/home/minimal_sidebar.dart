import 'package:flutter/material.dart';
import '../../../../core/services/audio_service.dart';

import '../animations.dart';

enum HomeScreenView { home, settings, profile, mods, news }

class MinimalSidebar extends StatelessWidget {
  final HomeScreenView currentView;
  final Function(HomeScreenView) onViewChanged;
  final VoidCallback onAvatarTap;
  final String avatarInitial;

  const MinimalSidebar({
    super.key,
    required this.currentView,
    required this.onViewChanged,
    required this.onAvatarTap,
    required this.avatarInitial,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 80,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.2),
        border: Border(
          right: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 24),
          // Brand or Back Button
          if (currentView != HomeScreenView.home)
            InkWell(
              onTap: () {
                AudioService().playClick();
                onViewChanged(HomeScreenView.home);
              },
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.arrow_back, color: Colors.white),
              ),
            )
          else
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Image.asset(
                'lib/assets/logo/Luyumi-Launcher_transparent.png',
                fit: BoxFit.contain,
              ),
            ),
          const SizedBox(height: 48),

          _buildSidebarItem(
            Icons.home_filled,
            currentView == HomeScreenView.home,
            onTap: () {
              AudioService().playClick();
              onViewChanged(HomeScreenView.home);
            },
          ),
          _buildSidebarItem(
            Icons.explore_outlined,
            currentView == HomeScreenView.mods,
            onTap: () {
              AudioService().playClick();
              onViewChanged(HomeScreenView.mods);
            },
          ),
          _buildSidebarItem(
            Icons.article_outlined,
            currentView == HomeScreenView.news,
            onTap: () {
              AudioService().playClick();
              onViewChanged(HomeScreenView.news);
            },
          ),

          const Spacer(),

          _buildSidebarItem(
            Icons.settings_outlined,
            currentView == HomeScreenView.settings,
            onTap: () {
              AudioService().playClick();
              onViewChanged(HomeScreenView.settings);
            },
          ),
          const SizedBox(height: 24),

          InkWell(
            onTap: () {
              AudioService().playClick();
              onAvatarTap();
            },
            child: Container(
              width: 40,
              height: 40,
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: currentView == HomeScreenView.profile
                      ? Theme.of(context).primaryColor
                      : Theme.of(context).primaryColor.withValues(alpha: 0.5),
                  width: 2,
                ),
                image: const DecorationImage(
                  image: AssetImage('lib/assets/images/hytale-layered-2-(1).png'),
                  fit: BoxFit.cover,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarItem(
    IconData icon,
    bool isActive, {
    VoidCallback? onTap,
  }) {
    return ScaleOnHover(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 48,
          height: 48,
          margin: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isActive
                ? Colors.white.withValues(alpha: 0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: isActive
                ? Colors.white
                : Colors.white.withValues(alpha: 0.4),
            size: 24,
          ),
        ),
      ),
    );
  }
}
