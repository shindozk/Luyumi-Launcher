import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:uuid/uuid.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/services/auth_service.dart';
import '../../core/services/settings_service.dart';
import '../../core/services/version_service.dart';
import '../../core/services/update_service.dart';
import '../../core/services/audio_service.dart';
import '../../core/providers/game_status_provider.dart';
import '../widgets/animations.dart';

class SettingsView extends StatefulWidget {
  const SettingsView({super.key});

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  final AuthService _authService = AuthService();
  final SettingsService _settingsService = SettingsService();
  final VersionService _versionService = VersionService();
  final UpdateService _updateService = UpdateService();
  
  // State
  int _selectedIndex = 0;
  int? _hoveredIndex;
  bool _isLoading = true;
  
  // Settings Values
  String _uuid = '';
  String _language = 'en-US';
  bool _closeLauncherOnStart = false;
  bool _alwaysOnTop = false;
  String? _gamePath;
  bool _fullscreen = true;
  int _ramAllocation = 4096;
  bool _customJavaEnabled = false;
  final TextEditingController _javaPathController = TextEditingController();
  String _gpuPreference = 'auto';
  bool _discordRpc = true;
  
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _javaPathController.addListener(_onJavaPathChanged);
    _loadSettings();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _javaPathController.removeListener(_onJavaPathChanged);
    _javaPathController.dispose();
    super.dispose();
  }

  void _onJavaPathChanged() {
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 1000), () {
      _settingsService.setJavaPath(_javaPathController.text);
    });
  }

  Future<void> _loadSettings() async {
    // Load local defaults first for instant feel
    final savedUuid = await _authService.getSavedUuid();
    _uuid = savedUuid ?? const Uuid().v4();
    
    // Parallel loading
    final results = await Future.wait([
      _settingsService.getLanguage(),
      _versionService.getCloseLauncherOnStart(),
      _settingsService.getAlwaysOnTop(),
      _settingsService.getFullscreen(),
      _settingsService.getRamAllocation(),
      _settingsService.getCustomJavaEnabled(),
      _settingsService.getJavaPath(),
      _settingsService.getGpuPreference(),
      _settingsService.getDiscordRpc(),
      _fetchGamePath(),
    ]);

    if (!mounted) return;

    setState(() {
      // Language
      final savedLang = results[0] as String?;
      if (savedLang != null) {
        _language = savedLang;
      } else {
        _language = _detectSystemLanguage();
      }

      _closeLauncherOnStart = results[1] as bool;
      _alwaysOnTop = results[2] as bool;
      _fullscreen = results[3] as bool;
      _ramAllocation = results[4] as int;
      _customJavaEnabled = results[5] as bool;
      _javaPathController.text = (results[6] as String?) ?? '';
      _gpuPreference = results[7] as String;
      _discordRpc = results[8] as bool;
      _gamePath = results[9] as String?;
      
      _isLoading = false;
    });
  }

  String _detectSystemLanguage() {
    final currentCode = context.locale.languageCode;
    switch (currentCode) {
      case 'pt': return 'pt-BR';
      case 'es': return 'es-ES';
      case 'zh': return 'zh-CN';
      case 'ja': return 'ja-JP';
      case 'ko': return 'ko-KR';
      case 'ru': return 'ru-RU';
      case 'fr': return 'fr-FR';
      default: return 'en-US';
    }
  }

  Future<String?> _fetchGamePath() async {
    try {
      final status = await _versionService.getGameStatus();
      if (status.installed) return status.gameDir;
    } catch (_) {}
    return null;
  }

  // --- Actions ---

  Future<void> _copyUuid() async {
    await Clipboard.setData(ClipboardData(text: _uuid));
    if (mounted) {
      _showSnack(tr('settings_uuid_copied'));
    }
  }

  Future<void> _pickJavaPath() async {
    FilePickerResult? result;
    if (Platform.isWindows) {
      result = await FilePicker.platform.pickFiles(
        dialogTitle: tr('settings_pick_java'),
        type: FileType.custom,
        allowedExtensions: ['exe'],
      );
    } else {
      result = await FilePicker.platform.pickFiles(
        dialogTitle: tr('settings_pick_java'),
        type: FileType.any,
      );
    }

    final selectedPath = result?.files.single.path;
    if (selectedPath != null) {
      setState(() => _javaPathController.text = selectedPath);
    }
  }

  Future<void> _pickInstallPath() async {
    String? selectedDirectory = await FilePicker.platform.getDirectoryPath(
      dialogTitle: tr('settings_pick_install_path'),
    );

    if (selectedDirectory != null) {
      final success = await _versionService.setInstallPath(selectedDirectory);
      if (mounted && success) {
        setState(() => _gamePath = selectedDirectory);
        _loadSettings();
      }
    }
  }

  Future<void> _openGameFolder() async {
    final success = await _versionService.openGameFolder();
    if (!success && mounted) {
      _showSnack(tr('settings_open_folder_error'), isError: true);
    }
  }

  Future<void> _repairGame() async {
    _showProgressDialog(tr('settings_repairing'));
    try {
      await _versionService.repairGame((progress) {});
      if (mounted) {
        Navigator.pop(context);
        context.read<GameStatusProvider>().checkGameStatus(forceRefresh: true);
        _showSnack(tr('settings_repair_success'));
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        _showSnack('${tr('settings_repair_error')}: $e', isError: true);
      }
    }
  }

  Future<void> _uninstallGame() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: Text(tr('settings_uninstall_confirm_title'), style: const TextStyle(color: Colors.white)),
        content: Text(tr('settings_uninstall_confirm_desc'), style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () {
              AudioService().playClick();
              Navigator.pop(context, false);
            },
            child: Text(tr('cancel'), style: const TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () {
              AudioService().playClick();
              Navigator.pop(context, true);
            },
            child: Text(tr('uninstall'), style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      setState(() => _isLoading = true);
      final success = await _versionService.uninstallGame();
      setState(() => _isLoading = false);
      
      if (mounted) {
        if (success) {
          context.read<GameStatusProvider>().checkGameStatus(forceRefresh: true);
          _showSnack(tr('settings_uninstall_success'));
          _loadSettings();
        } else {
          _showSnack(tr('settings_uninstall_error'), isError: true);
        }
      }
    }
  }
  
  Future<void> _viewLogs() async {
    final logs = await _versionService.getLogs();
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => _LogsDialog(
        logs: logs, 
        onOpenFolder: _versionService.openLogsFolder,
      ),
    );
  }

  Future<void> _checkForUpdates() async {
    _showProgressDialog(tr('checking'));
    try {
      final info = await _updateService.checkForUpdates();
      if (!mounted) return;
      Navigator.pop(context);

      if (info.hasUpdate) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: const Color(0xFF1E1E1E),
            title: Text(tr('update_available'), style: const TextStyle(color: Colors.white)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr('update_available_desc', namedArgs: {'version': info.latestVersion}),
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 10),
                Text(
                  info.releaseNotes,
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                  maxLines: 5,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  AudioService().playClick();
                  Navigator.pop(context);
                },
                child: Text(tr('cancel'), style: const TextStyle(color: Colors.white54)),
              ),
              TextButton(
                onPressed: () {
                   AudioService().playClick();
                   Navigator.pop(context);
                   _performUpdate(info.downloadUrl);
                },
                child: Text(tr('update_now'), style: TextStyle(color: Theme.of(context).primaryColor)),
              ),
            ],
          ),
        );
      } else {
        _showSnack(tr('up_to_date', namedArgs: {'version': info.latestVersion}));
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        _showSnack(tr('update_error', namedArgs: {'error': e.toString()}), isError: true);
      }
    }
  }

  Future<void> _performUpdate(String url) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _UpdateProgressDialog(
        updateService: _updateService,
        downloadUrl: url,
      ),
    );
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.inter()),
        backgroundColor: isError ? Colors.red.shade800 : Theme.of(context).primaryColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _showProgressDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Theme.of(context).primaryColor),
              const SizedBox(height: 16),
              Text(message, style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }

  // --- Build UI ---

  @override
  Widget build(BuildContext context) {
    final sections = [
      _buildGeneralSection(),
      _buildGameSection(),
      _buildJavaSection(),
      _buildAdvancedSection(),
    ];

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Row(
        children: [
          // Sidebar
          Container(
            width: 240,
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF141414).withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(4, 0),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 40),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(LucideIcons.settings, color: Theme.of(context).primaryColor, size: 32),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        tr('settings_sidebar_title'),
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildSidebarItem(0, tr('settings_general'), LucideIcons.user),
                _buildSidebarItem(1, tr('settings_graphics'), LucideIcons.gamepad2), // "Game"
                _buildSidebarItem(2, tr('settings_java_title'), LucideIcons.coffee),
                _buildSidebarItem(3, tr('settings_advanced'), LucideIcons.terminal),
              ],
            ),
          ),
          // Content
          Expanded(
            child: _isLoading 
              ? Center(child: CircularProgressIndicator(color: Theme.of(context).primaryColor))
              : FadeInEntry(
                  key: ValueKey(_selectedIndex),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(40),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _getSectionTitle(_selectedIndex),
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _getSectionSubtitle(_selectedIndex),
                          style: GoogleFonts.inter(
                            color: Colors.white54,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 32),
                        sections[_selectedIndex],
                      ],
                    ),
                  ),
                ),
          ),
        ],
      ),
    );
  }

  String _getSectionTitle(int index) {
    switch (index) {
      case 0: return tr('settings_general');
      case 1: return tr('settings_graphics'); // Reusing translation key for "Game"
      case 2: return tr('settings_java_title');
      case 3: return tr('settings_advanced');
      default: return '';
    }
  }

  String _getSectionSubtitle(int index) {
    switch (index) {
      case 0: return tr('settings_subtitle_general');
      case 1: return tr('settings_subtitle_game');
      case 2: return tr('settings_subtitle_java');
      case 3: return tr('settings_subtitle_advanced');
      default: return '';
    }
  }

  Widget _buildSidebarItem(int index, String title, IconData icon) {
    final isSelected = _selectedIndex == index;
    final isHovered = _hoveredIndex == index;

    return MouseRegion(
      onEnter: (_) => setState(() => _hoveredIndex = index),
      onExit: (_) => setState(() => _hoveredIndex = null),
      child: GestureDetector(
        onTap: () {
          AudioService().playClick();
          setState(() => _selectedIndex = index);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            color: isSelected 
                ? Theme.of(context).primaryColor.withValues(alpha: 0.15) 
                : isHovered 
                    ? Colors.white.withValues(alpha: 0.05) 
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected 
                  ? Theme.of(context).primaryColor.withValues(alpha: 0.3) 
                  : Colors.transparent,
              width: 1,
            ),
          ),
          child: Row(
            children: [
              AnimatedScale(
                scale: isSelected || isHovered ? 1.1 : 1.0,
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  icon,
                  color: isSelected ? Theme.of(context).primaryColor : Colors.white54,
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.inter(
                    color: isSelected ? Colors.white : Colors.white70,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    fontSize: 14,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isSelected)
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // --- Section Widgets ---

  Widget _buildGeneralSection() {
    return Column(
      children: [
        _SettingsCard(
          title: 'Account',
          children: [
            _SettingsTile(
              title: 'UUID',
              subtitle: _uuid,
              icon: LucideIcons.fingerprint,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(LucideIcons.copy, size: 18),
                    onPressed: () {
                      AudioService().playClick();
                      _copyUuid();
                    },
                    tooltip: tr('copy'),
                    color: Colors.white54,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        _SettingsCard(
          title: tr('settings_general'),
          children: [
            _SettingsDropdown(
              title: tr('settings_language'),
              value: _language,
              items: const {
                'pt-BR': 'Português (Brasil)',
                'en-US': 'English (US)',
                'es-ES': 'Español (España)',
                'zh-CN': '中文 (简体)',
                'ja-JP': '日本語',
                'ko-KR': '한국어',
                'ru-RU': 'Русский',
                'fr-FR': 'Français',
              },
              onChanged: (val) {
                if (val != null) {
                  setState(() => _language = val);
                  final localeCode = val.split('-')[0];
                  context.setLocale(Locale(localeCode));
                  _settingsService.setLanguage(val);
                }
              },
              icon: LucideIcons.languages,
            ),
            const Divider(color: Colors.white10, height: 1),
            _SettingsSwitch(
              title: tr('settings_close_launcher'),
              subtitle: tr('settings_close_launcher_desc'),
              value: _closeLauncherOnStart,
              onChanged: (val) {
                setState(() => _closeLauncherOnStart = val);
                _versionService.setCloseLauncherOnStart(val);
              },
              icon: LucideIcons.doorClosed,
            ),
            const Divider(color: Colors.white10, height: 1),
            _SettingsSwitch(
              title: 'Always on Top',
              subtitle: 'Keep launcher window above other windows',
              value: _alwaysOnTop,
              onChanged: (val) {
                setState(() => _alwaysOnTop = val);
                _settingsService.setAlwaysOnTop(val);
              },
              icon: LucideIcons.arrowUp,
            ),
          ],
        ),
        const SizedBox(height: 24),
        _SettingsCard(
          title: 'About',
          children: [
            _SettingsActionTile(
              title: tr('check_updates'),
              icon: LucideIcons.refreshCw,
              onTap: _checkForUpdates,
            ),
            const Divider(color: Colors.white10, height: 1),
            _SettingsTile(
              title: tr('developed_by'),
              icon: LucideIcons.code,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildGameSection() {
    final gamePathText = (_gamePath != null && _gamePath!.isNotEmpty)
        ? _gamePath!
        : tr('error_game_path_not_found');

    return Column(
      children: [
        _SettingsCard(
          title: 'Installation',
          children: [
            _SettingsTile(
              title: tr('settings_game_path'),
              subtitle: gamePathText,
              icon: LucideIcons.folder,
              onTap: _pickInstallPath,
              trailing: const Icon(LucideIcons.chevronRight, color: Colors.white24),
            ),
            const Divider(color: Colors.white10, height: 1),
            _SettingsActionTile(
              title: tr('settings_open_folder'),
              icon: LucideIcons.externalLink,
              onTap: _openGameFolder,
            ),
          ],
        ),
        const SizedBox(height: 24),
        _SettingsCard(
          title: 'Display',
          children: [
            _SettingsSwitch(
              title: tr('settings_fullscreen'),
              subtitle: tr('settings_fullscreen_desc'),
              value: _fullscreen,
              onChanged: (val) {
                setState(() => _fullscreen = val);
                _settingsService.setFullscreen(val);
              },
              icon: LucideIcons.maximize,
            ),
          ],
        ),
        const SizedBox(height: 24),
        _SettingsCard(
          title: 'Maintenance',
          children: [
            _SettingsActionTile(
              title: tr('settings_repairing').replaceAll('...', ''),
              icon: LucideIcons.wrench,
              color: Colors.orange,
              onTap: _repairGame,
            ),
            const Divider(color: Colors.white10, height: 1),
            _SettingsActionTile(
              title: tr('settings_uninstall_confirm_title'),
              icon: LucideIcons.trash2,
              color: Colors.red,
              onTap: _uninstallGame,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildJavaSection() {
    return Column(
      children: [
        _SettingsCard(
          title: 'Memory Allocation',
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(tr('settings_ram'), style: GoogleFonts.inter(color: Colors.white, fontSize: 16)),
                      Text(
                        "${_ramAllocation}MB",
                        style: GoogleFonts.inter(color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SliderTheme(
                    data: SliderThemeData(
                      activeTrackColor: Theme.of(context).primaryColor,
                      inactiveTrackColor: Colors.white10,
                      thumbColor: Colors.white,
                      overlayColor: Theme.of(context).primaryColor.withValues(alpha: 0.2),
                      trackHeight: 4,
                    ),
                    child: Slider(
                      value: _ramAllocation.toDouble(),
                      min: 1024,
                      max: 16384,
                      divisions: 15,
                      onChanged: (val) => setState(() => _ramAllocation = val.toInt()),
                      onChangeEnd: (val) {
                        AudioService().playClick();
                        _settingsService.setRamAllocation(val.toInt());
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        _SettingsCard(
          title: 'Java Runtime',
          children: [
            _SettingsSwitch(
              title: 'Custom Java Path',
              subtitle: 'Use a specific Java installation',
              value: _customJavaEnabled,
              onChanged: (val) {
                setState(() => _customJavaEnabled = val);
                _settingsService.setCustomJavaEnabled(val);
              },
              icon: LucideIcons.coffee,
            ),
            if (_customJavaEnabled) ...[
              const Divider(color: Colors.white10, height: 1),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _javaPathController,
                        style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'Path to javaw.exe',
                          hintStyle: GoogleFonts.inter(color: Colors.white24),
                          filled: true,
                          fillColor: Colors.white.withValues(alpha: 0.05),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    IconButton.filled(
                      onPressed: () {
                        AudioService().playClick();
                        _pickJavaPath();
                      },
                      icon: const Icon(LucideIcons.folderOpen, size: 20),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white.withValues(alpha: 0.1),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildAdvancedSection() {
    return Column(
      children: [
        _SettingsCard(
          title: 'System',
          children: [
            _SettingsDropdown(
              title: tr('settings_gpu'),
              value: _gpuPreference,
              items: {
                'auto': tr('gpu_auto'),
                'integrated': tr('gpu_integrated'),
                'dedicated': tr('gpu_dedicated'),
              },
              onChanged: (val) {
                if (val != null) {
                  setState(() => _gpuPreference = val);
                  _settingsService.setGpuPreference(val);
                }
              },
              icon: LucideIcons.cpu,
            ),
          ],
        ),
        const SizedBox(height: 24),
        _SettingsCard(
          title: 'Integration',
          children: [
            _SettingsSwitch(
              title: 'Discord RPC',
              subtitle: 'Show game status on Discord profile',
              value: _discordRpc,
              onChanged: (val) {
                setState(() => _discordRpc = val);
                _settingsService.setDiscordRpc(val);
              },
              icon: LucideIcons.gamepad,
            ),
          ],
        ),
        const SizedBox(height: 24),
        _SettingsCard(
          title: 'Diagnostics',
          children: [
            _SettingsActionTile(
              title: tr('settings_logs'),
              icon: LucideIcons.fileText,
              onTap: _viewLogs,
            ),
          ],
        ),
      ],
    );
  }
}

// --- Reusable Widgets ---

class _SettingsCard extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SettingsCard({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            title.toUpperCase(),
            style: GoogleFonts.inter(
              color: Colors.white38,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.title,
    this.subtitle,
    required this.icon,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap != null ? () {
          AudioService().playClick();
          onTap!();
        } : null,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Icon(icon, color: Colors.white70, size: 22),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: GoogleFonts.inter(color: Colors.white, fontSize: 16)),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(subtitle!, style: GoogleFonts.inter(color: Colors.white38, fontSize: 13)),
                    ],
                  ],
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsSwitch extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final IconData icon;

  const _SettingsSwitch({
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return _SettingsTile(
      title: title,
      subtitle: subtitle,
      icon: icon,
      trailing: Switch(
        value: value,
        onChanged: (val) {
          AudioService().playClick();
          onChanged(val);
        },
        activeColor: Theme.of(context).primaryColor,
      ),
      onTap: () => onChanged(!value),
    );
  }
}

class _SettingsActionTile extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color? color;
  final VoidCallback onTap;

  const _SettingsActionTile({
    required this.title,
    required this.icon,
    this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? Colors.white;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Icon(icon, color: effectiveColor, size: 22),
              const SizedBox(width: 20),
              Text(
                title,
                style: GoogleFonts.inter(
                  color: effectiveColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsDropdown extends StatelessWidget {
  final String title;
  final String value;
  final Map<String, String> items;
  final ValueChanged<String?> onChanged;
  final IconData icon;

  const _SettingsDropdown({
    required this.title,
    required this.value,
    required this.items,
    required this.onChanged,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return _SettingsTile(
      title: title,
      icon: icon,
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(8),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: items.containsKey(value) ? value : null,
            dropdownColor: const Color(0xFF2C2C2C),
            icon: const Icon(LucideIcons.chevronDown, color: Colors.white54, size: 16),
            style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
            items: items.entries.map((e) {
              return DropdownMenuItem(
                value: e.key,
                child: Text(e.value),
              );
            }).toList(),
            onChanged: (val) {
              AudioService().playClick();
              onChanged(val);
            },
          ),
        ),
      ),
    );
  }
}

class _LogsDialog extends StatelessWidget {
  final String logs;
  final VoidCallback onOpenFolder;

  const _LogsDialog({required this.logs, required this.onOpenFolder});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1E1E1E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 800,
        height: 600,
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  tr('settings_logs'),
                  style: GoogleFonts.inter(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(LucideIcons.x, color: Colors.white),
                  onPressed: () {
                    AudioService().playClick();
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white10),
                ),
                child: SingleChildScrollView(
                  child: SelectableText(
                    logs,
                    style: GoogleFonts.jetBrainsMono(color: Colors.white70, fontSize: 12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  icon: const Icon(LucideIcons.folderOpen, size: 18),
                  label: Text(tr('settings_open_logs_folder')),
                  onPressed: () {
                    AudioService().playClick();
                    onOpenFolder();
                  },
                  style: TextButton.styleFrom(foregroundColor: Colors.white70),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  icon: const Icon(LucideIcons.copy, size: 18),
                  label: Text(tr('copy')),
                  onPressed: () {
                    AudioService().playClick();
                    Clipboard.setData(ClipboardData(text: logs));
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('copied'))));
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _UpdateProgressDialog extends StatefulWidget {
  final UpdateService updateService;
  final String downloadUrl;

  const _UpdateProgressDialog({
    required this.updateService,
    required this.downloadUrl,
  });

  @override
  State<_UpdateProgressDialog> createState() => _UpdateProgressDialogState();
}

class _UpdateProgressDialogState extends State<_UpdateProgressDialog> {
  String _status = 'Starting update...';
  double _progress = 0.0;

  @override
  void initState() {
    super.initState();
    _startUpdate();
  }

  Future<void> _startUpdate() async {
    try {
      await widget.updateService.performUpdate(
        widget.downloadUrl,
        (message, progress) {
          if (mounted) {
            setState(() {
              _status = message;
              _progress = progress;
            });
          }
        },
      );
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Update failed: $e'),
            backgroundColor: Colors.red.shade800,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1E1E1E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Updating Launcher',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            LinearProgressIndicator(
              value: _progress,
              backgroundColor: Colors.white10,
              valueColor: AlwaysStoppedAnimation<Color>(
                Theme.of(context).primaryColor,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _status,
              style: GoogleFonts.inter(color: Colors.white70, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
