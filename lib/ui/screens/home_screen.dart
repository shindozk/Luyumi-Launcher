import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'dart:async';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/window_caption.dart';
import '../widgets/animations.dart';
import '../../core/game_launcher.dart';
import '../../core/models/news_item.dart';
import '../../core/models/game_progress.dart';
import '../../core/models/game_status.dart';
import '../../core/models/launcher_update_info.dart';
import '../../core/services/news_service.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/version_service.dart';
import '../../core/services/settings_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';
import '../views/settings_view.dart';

import '../views/profile_view.dart';
import '../views/mods_view.dart';
import '../views/news_view.dart';
import '../widgets/home/minimal_sidebar.dart';
import '../widgets/home/welcome_header.dart';
import '../widgets/home/news_section.dart';
import '../widgets/home/game_action_panel.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  HomeScreenView _currentView = HomeScreenView.home;
  bool _isLoading = false;
  bool _isGameStatusLoading = false;
  bool _showProgress = false;
  String? _progressMessage;
  int? _progressPercent;
  String? _lastError;
  GameStatus? _gameStatus;
  bool _launcherUpdateRequired = false;
  LauncherUpdateInfo? _launcherUpdateInfo;
  bool _firstLaunchUpdateRequired = false;
  bool _isOpeningUpdateUrl = false;
  late Future<List<NewsItem>> _newsFuture;
  final NewsService _newsService = NewsService();
  final AuthService _authService = AuthService();
  final VersionService _versionService = VersionService();
  final SettingsService _settingsService = SettingsService();
  String? _username;
  String? _uuid;

  // Game Running State
  bool _isGameRunning = false;
  DateTime? _gameStartTime;
  Timer? _statusPollingTimer;
  Timer? _uiTimer;
  String _elapsedTime = "00:00";

  @override
  void initState() {
    super.initState();
    _newsFuture = _newsService.fetchNews();
    _refreshGameStatus();
    _checkLauncherUpdates();
    _checkFirstLaunch();
    _startGameStatusPolling();
    _loadUserIdentity();
  }

  @override
  void dispose() {
    _statusPollingTimer?.cancel();
    _uiTimer?.cancel();
    super.dispose();
  }

  void _startGameStatusPolling() {
    _statusPollingTimer = Timer.periodic(const Duration(seconds: 2), (
      timer,
    ) async {
      final status = await _versionService.getRunningGameStatus();
      if (mounted) {
        final isRunning = status['isRunning'] == true;

        if (isRunning != _isGameRunning) {
          setState(() {
            _isGameRunning = isRunning;
            if (isRunning) {
              final startTime = status['startTime'];
              if (startTime != null) {
                _gameStartTime = DateTime.fromMillisecondsSinceEpoch(
                  (startTime * 1000).toInt(),
                );
              } else {
                _gameStartTime = DateTime.now();
              }
              _startUiTimer();
            } else {
              _stopUiTimer();
            }
          });
        }
      }
    });
  }

  void _startUiTimer() {
    _uiTimer?.cancel();
    _uiTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_gameStartTime != null) {
        final duration = DateTime.now().difference(_gameStartTime!);
        final minutes = duration.inMinutes.toString().padLeft(2, '0');
        final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
        if (mounted) {
          setState(() {
            _elapsedTime = "$minutes:$seconds";
          });
        }
      }
    });
  }

  void _stopUiTimer() {
    _uiTimer?.cancel();
    if (mounted) {
      setState(() {
        _elapsedTime = "00:00";
        _gameStartTime = null;
      });
    }
  }

  Future<void> _loadUserIdentity() async {
    final savedUsername = await _authService.getSavedUsername();
    final uuid = await _authService.getSavedUuid();
    final session = await _authService.getSavedSession();
    final username = (savedUsername != null && savedUsername.trim().isNotEmpty)
        ? savedUsername.trim()
        : 'LuyumiPlayer';
    if (savedUsername == null || savedUsername.trim().isEmpty) {
      await _authService.saveUsername(username);
    }

    if (!mounted) {
      return;
    }
    setState(() {
      _username = username;
      _uuid = uuid;
    });

    if (session == null || session.mode == 'offline') {
      // Try to refresh/login silently to get online status
      _authService.login(username, uuid: uuid).then((auth) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                tr(
                  'connected_as',
                  namedArgs: {'username': username, 'mode': auth.mode},
                ),
              ),
              backgroundColor: auth.mode == 'online'
                  ? Colors.green
                  : Colors.grey,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      });
    }
  }

  Future<void> _refreshGameStatus() async {
    setState(() => _isGameStatusLoading = true);
    try {
      final status = await _versionService.getGameStatus();
      if (mounted) {
        setState(() => _gameStatus = status);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              tr('error_checking', namedArgs: {'error': e.toString()}),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isGameStatusLoading = false);
      }
    }
  }

  Future<void> _handlePrimaryAction() async {
    if (_isLoading || _isGameStatusLoading) {
      return;
    }
    if (_launcherUpdateRequired) {
      await _openLauncherUpdateDownload();
      return;
    }
    if (_firstLaunchUpdateRequired) {
      await _handleFirstLaunchUpdate();
      return;
    }
    if (_gameStatus == null) {
      await _refreshGameStatus();
      return;
    }
    if (!_gameStatus!.installed) {
      await _handleInstall();
      return;
    }
    if (_gameStatus!.updateAvailable) {
      await _handleUpdate();
      return;
    }
    await _handlePlay();
  }

  Future<void> _handleInstall() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    _lastError = null;

    try {
      _setProgressState(tr('status_installing'), null, true);

      final installResult = await _versionService.installGameWithProgress(
        _updateProgress,
      );
      final success = installResult['success'] == true;
      final error = installResult['error']?.toString();
      if (error != null && error.isNotEmpty) {
        _lastError = error;
      }

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(tr('install_complete'))),
          ); // Add translation key if needed or use simple text
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                _lastError != null
                    ? tr('failed_with_error', namedArgs: {'error': _lastError!})
                    : tr('failed_install'),
              ), // Ensure key exists or use generic error
              backgroundColor: Colors.red,
            ),
          );
        }
      }

      if (success) {
        await _refreshGameStatus();
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
        _setProgressState(null, null, false);
      }
    }
  }

  Future<void> _handleUpdate() async {
    setState(() => _isLoading = true);
    _lastError = null;
    try {
      _setProgressState(null, null, true);
      final success = await _versionService.updateGameWithProgress(
        _updateProgress,
      );
      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(tr('update_complete'))));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                _lastError != null
                    ? tr('failed_with_error', namedArgs: {'error': _lastError!})
                    : tr('failed_update'),
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
      if (success) {
        await _refreshGameStatus();
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
        _setProgressState(null, null, false);
      }
    }
  }

  Future<void> _handlePlay() async {
    String? username = await _authService.getSavedUsername();

    if (username == null || username.isEmpty) {
      username = await _showUsernameDialog();
      if (username == null || username.isEmpty) return;
    }

    setState(() => _isLoading = true);
    try {
      // Generate or retrieve UUID
      String? savedUuid = await _authService.getSavedUuid();
      final uuid = savedUuid ?? const Uuid().v4();

      // 1. Authenticate
      final authResponse = await _authService.login(username, uuid: uuid);
      if (mounted) {
        setState(() {
          _username = username;
          _uuid = uuid;
        });
      }

      // 2. Check Version
      final versionInfo = await _versionService.getLatestVersion();

      // 3. Launch
      if (_gameStatus?.clientPath == null) {
        throw Exception(tr('error_game_path_not_found'));
      }

      final profileId = await _settingsService.getActiveProfile();
      final fullscreen = await _settingsService.getFullscreen();

      final launcher = GameLauncher();
      await launcher.launchGame(
        clientPath: _gameStatus!.clientPath!,
        playerName: username,
        uuid: uuid,
        identityToken: authResponse.identityToken,
        sessionToken: authResponse.sessionToken,
        profileId: profileId,
        fullscreen: fullscreen,
        onProgress: _updateProgress,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              tr(
                'launching',
                namedArgs: {
                  'version': versionInfo.latestVersion,
                  'mode': authResponse.mode,
                },
              ),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              tr('generic_error', namedArgs: {'error': e.toString()}),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
        _setProgressState(null, null, false);
      }
    }
  }

  Future<void> _openAvatarPage() async {
    setState(() => _currentView = HomeScreenView.profile);
  }

  String _getDisplayName() {
    final value = _username?.trim();
    if (value == null || value.isEmpty) {
      return tr('default_player_name');
    }
    return value;
  }

  String _getAvatarInitial() {
    final name = _getDisplayName();
    return name.substring(0, 1).toUpperCase();
  }

  Future<String?> _showUsernameDialog() async {
    String name = '';
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: Text(
          tr('welcome_title'),
          style: const TextStyle(color: Colors.white),
        ),
        content: TextField(
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: tr('dialog_username'),
            labelStyle: const TextStyle(color: Colors.white70),
            enabledBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.white54),
            ),
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.blue),
            ),
          ),
          onChanged: (v) => name = v,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              tr('dialog_cancel'),
              style: const TextStyle(color: Colors.white54),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, name),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
            child: Text(
              tr('dialog_play'),
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _updateProgress(GameProgress progress) {
    if (mounted) {
      _setProgressState(progress.message, (progress.percent).toInt(), true);
    }
  }

  void _setProgressState(String? message, int? percent, bool show) {
    setState(() {
      _progressMessage = message;
      _progressPercent = percent;
      _showProgress = show;
    });
  }

  Future<void> _checkLauncherUpdates() async {
    final info = await _versionService.checkLauncherUpdates();
    if (!mounted) {
      return;
    }
    if (info != null && info.updateAvailable && info.downloadUrl.isNotEmpty) {
      setState(() {
        _launcherUpdateInfo = info;
        _launcherUpdateRequired = true;
      });
    }
  }

  Future<void> _openLauncherUpdateDownload() async {
    final url = _launcherUpdateInfo?.downloadUrl;
    if (url == null || url.isEmpty || _isOpeningUpdateUrl) {
      return;
    }
    setState(() => _isOpeningUpdateUrl = true);
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
    if (mounted) {
      setState(() => _isOpeningUpdateUrl = false);
    }
  }

  Future<void> _checkFirstLaunch() async {
    final status = await _versionService.getFirstLaunchStatus();
    if (!mounted) {
      return;
    }
    if (status.error != null && status.error!.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tr('first_launch_error', namedArgs: {'error': status.error!}),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
    if (status.isFirstLaunch && status.needsUpdate) {
      setState(() {
        _firstLaunchUpdateRequired = true;
      });
    }
  }

  Future<void> _handleFirstLaunchUpdate() async {
    if (_isLoading) {
      return;
    }
    setState(() => _isLoading = true);
    _lastError = null;
    try {
      _setProgressState(tr('updating_existing_install'), null, true);
      final result = await _versionService.acceptFirstLaunchUpdate();
      if (!mounted) {
        return;
      }
      if (result.error == null) {
        setState(() => _firstLaunchUpdateRequired = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(tr('update_complete'))));
        await _refreshGameStatus();
      } else {
        final error = result.error ?? tr('failed_update');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('failed_with_error', namedArgs: {'error': error})),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
        _setProgressState(null, null, false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Background Animado
          Positioned.fill(
            child: Image.network(
              'https://i.imgur.com/kvkj82r.jpeg',
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) =>
                  Container(color: const Color(0xFF050505)),
            ),
          ),
          // Cinematic Gradient Overlay
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.4),
                    const Color(0xFF050505).withValues(alpha: 0.95),
                  ],
                  stops: const [0.0, 0.8],
                ),
              ),
            ),
          ),

          Column(
            children: [
              const WindowCaption(title: "Luyumi Launcher"),
              Expanded(
                child: Row(
                  children: [
                    MinimalSidebar(
                      currentView: _currentView,
                      onViewChanged: (view) =>
                          setState(() => _currentView = view),
                      onAvatarTap: _openAvatarPage,
                      avatarInitial: _getAvatarInitial(),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(40, 20, 40, 40),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          child: _buildMainContent(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    switch (_currentView) {
      case HomeScreenView.settings:
        return const SettingsView(key: ValueKey('settings'));
      case HomeScreenView.mods:
        return const ModsView(key: ValueKey('mods'));
      case HomeScreenView.news:
        return const NewsView(key: ValueKey('news'));
      case HomeScreenView.profile:
        return ProfileView(
          key: const ValueKey('profile'),
          username: _username,
          uuid: _uuid,
          onBack: () => setState(() => _currentView = HomeScreenView.home),
          onUsernameChanged: (value) {
            if (!mounted) return;
            setState(() {
              _username = value;
            });
          },
          onUsernameSaved: (value) async {
            if (!mounted) return;
            final trimmed = value.trim();
            final normalized = trimmed.isEmpty ? 'LuyumiPlayer' : trimmed;
            setState(() {
              _username = normalized;
            });
            await _authService.saveUsername(normalized);
          },
        );
      case HomeScreenView.home:
        return Column(
          key: const ValueKey('home'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FadeInEntry(
              delay: const Duration(milliseconds: 100),
              child: WelcomeHeader(displayName: _getDisplayName()),
            ),
            const Spacer(),
            FadeInEntry(
              delay: const Duration(milliseconds: 200),
              child: NewsSection(newsFuture: _newsFuture),
            ),
            const Spacer(),
            FadeInEntry(
              delay: const Duration(milliseconds: 300),
              child: GameActionPanel(
                isLoading: _isLoading,
                isGameStatusLoading: _isGameStatusLoading,
                isGameRunning: _isGameRunning,
                isOpeningUpdateUrl: _isOpeningUpdateUrl,
                showProgress: _showProgress,
                progressMessage: _progressMessage,
                progressPercent: _progressPercent,
                gameStatus: _gameStatus,
                elapsedTime: _elapsedTime,
                launcherUpdateRequired: _launcherUpdateRequired,
                firstLaunchUpdateRequired: _firstLaunchUpdateRequired,
                onAction: _handlePrimaryAction,
              ),
            ),
            const SizedBox(height: 16),
            FadeInEntry(
              delay: const Duration(milliseconds: 400),
              child: _buildFooter(),
            ),
          ],
        );
    }
  }

  Widget _buildFooter() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(top: 8.0),
        child: Column(
          children: [
            Text(
              tr('developed_by'),
              style: GoogleFonts.inter(
                color: Colors.white38,
                fontSize: 10,
                fontWeight: FontWeight.w500,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              "Made in Brazil 🇧🇷",
              style: GoogleFonts.inter(
                color: Colors.white24,
                fontSize: 10,
                fontWeight: FontWeight.w500,
                letterSpacing: 1.0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
