import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:uuid/uuid.dart';
import 'package:window_manager/window_manager.dart';
import 'package:provider/provider.dart';

import '../../core/services/auth_service.dart';
import '../../core/services/settings_service.dart';
import '../../core/services/version_service.dart';
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
  final TextEditingController _javaPathController = TextEditingController();

  bool _isLoading = true;
  bool _customJavaEnabled = false;
  int _ramAllocation = 4096;
  bool _fullscreen = true;
  bool _discordRpc = true;
  String _gpuPreference = 'auto';
  String _language = 'en-US';
  String _uuid = '';
  String? _gamePath;
  bool _closeLauncherOnStart = false;
  bool _alwaysOnTop = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);

    final uuid = await _authService.getSavedUuid();
    _uuid = uuid ?? const Uuid().v4();

    _customJavaEnabled = await _settingsService.getCustomJavaEnabled();
    final javaPath = await _settingsService.getJavaPath();
    _javaPathController.text = javaPath ?? '';

    _ramAllocation = await _settingsService.getRamAllocation();
    _fullscreen = await _settingsService.getFullscreen();
    _discordRpc = await _settingsService.getDiscordRpc();
    _gpuPreference = await _settingsService.getGpuPreference();

    final savedLanguage = await _settingsService.getLanguage();
    if (!mounted) return;
    if (savedLanguage != null) {
      _language = savedLanguage;
    } else {
      final currentCode = context.locale.languageCode;
      switch (currentCode) {
        case 'pt':
          _language = 'pt-BR';
          break;
        case 'es':
          _language = 'es-ES';
          break;
        case 'zh':
          _language = 'zh-CN';
          break;
        case 'ja':
          _language = 'ja-JP';
          break;
        case 'ko':
          _language = 'ko-KR';
          break;
        case 'ru':
          _language = 'ru-RU';
          break;
        case 'fr':
          _language = 'fr-FR';
          break;
        default:
          _language = 'en-US';
      }
    }

    _closeLauncherOnStart = await _versionService.getCloseLauncherOnStart();
    _alwaysOnTop = await _settingsService.getAlwaysOnTop();

    String? gamePath;
    try {
      final status = await _versionService.getGameStatus();
      if (status.installed) {
        gamePath = status.gameDir;
      }
    } catch (_) {}

    if (mounted) {
      setState(() {
        _gamePath = gamePath;
        _isLoading = false;
      });
    }
  }

  Future<void> _saveSettings() async {
    await _authService.saveUuid(_uuid);
    await _settingsService.setCustomJavaEnabled(_customJavaEnabled);
    await _settingsService.setJavaPath(_javaPathController.text);
    await _settingsService.setRamAllocation(_ramAllocation);
    await _settingsService.setFullscreen(_fullscreen);
    await _settingsService.setDiscordRpc(_discordRpc);
    await _settingsService.setGpuPreference(_gpuPreference);
    await _settingsService.setLanguage(_language);
    await _versionService.setCloseLauncherOnStart(_closeLauncherOnStart);
    await _settingsService.setAlwaysOnTop(_alwaysOnTop);
    await windowManager.setAlwaysOnTop(_alwaysOnTop);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('settings_saved'), style: GoogleFonts.poppins()),
          backgroundColor: Theme.of(context).primaryColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    }
  }

  Future<void> _regenerateUuid() async {
    final newUuid = const Uuid().v4();
    setState(() => _uuid = newUuid);
    // Auto-save when regenerating? Maybe wait for explicit save.
  }

  Future<void> _copyUuid() async {
    await Clipboard.setData(ClipboardData(text: _uuid));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tr('settings_uuid_copied'),
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: Theme.of(context).primaryColor,
          duration: const Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
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
      setState(() {
        _javaPathController.text = selectedPath;
      });
    }
  }

  Future<void> _openGameFolder() async {
    final success = await _versionService.openGameFolder();
    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('settings_open_folder_error')),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _pickInstallPath() async {
    String? selectedDirectory = await FilePicker.platform.getDirectoryPath(
      dialogTitle: tr('settings_pick_install_path'),
    );

    if (selectedDirectory != null) {
      final success = await _versionService.setInstallPath(selectedDirectory);
      if (!mounted) return;
      if (success) {
        setState(() {
          _gamePath = selectedDirectory;
        });
        _loadSettings();
      }
    }
  }

  Future<void> _repairGame() async {
    String progressMessage = tr('settings_repairing');
    double progressValue = 0.0;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1E1E1E),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    tr('settings_repairing'),
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  LinearProgressIndicator(
                    value: progressValue > 0 ? progressValue : null,
                    backgroundColor: Colors.white10,
                    color: Theme.of(context).primaryColor,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "${(progressValue * 100).toInt()}% - $progressMessage",
                    style: GoogleFonts.inter(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    try {
      await _versionService.repairGame((progress) {
        // Progress handling
      });
      
      if (mounted) {
        Navigator.pop(context); // Close progress dialog
        // Refresh game status
        context.read<GameStatusProvider>().checkGameStatus(forceRefresh: true);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('settings_repair_success'))),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close progress dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${tr('settings_repair_error')}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _uninstallGame() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr('settings_uninstall_confirm_title')),
        content: Text(tr('settings_uninstall_confirm_desc')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(tr('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              tr('uninstall'),
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      setState(() => _isLoading = true);
      final success = await _versionService.uninstallGame();
      setState(() => _isLoading = false);
      if (success) {
        _loadSettings();
        if (mounted) {
          // Immediately update global game status to unlock "Install" button
          context.read<GameStatusProvider>().checkGameStatus(forceRefresh: true);
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(tr('settings_uninstall_success'))),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(tr('settings_uninstall_error')),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _viewLogs() async {
    final logs = await _versionService.getLogs();
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: const Color(0xFF1E1E1E),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    tr('settings_logs'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                color: Colors.black,
                child: SingleChildScrollView(
                  child: SelectableText(
                    logs,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    icon: const Icon(Icons.folder_open),
                    label: Text(tr('settings_open_logs_folder')),
                    onPressed: () => _versionService.openLogsFolder(),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    icon: const Icon(Icons.copy),
                    label: Text(tr('copy')),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: logs));
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text(tr('copied'))));
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(color: Theme.of(context).primaryColor),
      );
    }
    final gamePathText = (_gamePath != null && _gamePath!.isNotEmpty)
        ? _gamePath!
        : tr('error_game_path_not_found');

    return Column(
      children: [
        _buildHeader(),
        Expanded(
          child: FadeInEntry(
            delay: const Duration(milliseconds: 100),
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 0),
              children: [
                _buildSectionTitle(tr('settings_general')),
                const SizedBox(height: 16),
                _buildCard([
                  _buildUuidField(),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: _buildDropdown(
                          tr('settings_language'),
                          _language,
                          {
                            'pt-BR': 'Português (Brasil)',
                            'en-US': 'English (US)',
                            'es-ES': 'Español (España)',
                            'zh-CN': '中文 (简体)',
                            'ja-JP': '日本語',
                            'ko-KR': '한국어',
                            'ru-RU': 'Русский',
                            'fr-FR': 'Français',
                          },
                          (val) {
                            if (val != null) {
                              setState(() => _language = val);
                              final localeCode = val.split('-')[0];
                              context.setLocale(Locale(localeCode));
                              _settingsService.setLanguage(val);
                            }
                          },
                          icon: Icons.language,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildDropdown(
                          tr('settings_gpu'),
                          _gpuPreference,
                          {
                            'auto': tr('gpu_auto'),
                            'integrated': tr('gpu_integrated'),
                            'dedicated': tr('gpu_dedicated'),
                          },
                          (val) {
                            if (val != null) {
                              setState(() => _gpuPreference = val);
                            }
                          },
                          icon: Icons.memory,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _buildReadOnlyField(
                    tr('settings_game_path'),
                    gamePathText,
                    icon: Icons.folder,
                    trailing: IconButton(
                      icon: const Icon(
                        Icons.edit,
                        size: 20,
                        color: Colors.white70,
                      ),
                      onPressed: _pickInstallPath,
                      tooltip: tr('settings_pick_install_path'),
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildActionButton(
                    tr('settings_open_folder'),
                    Icons.folder_open_rounded,
                    _openGameFolder,
                  ),
                ]),

                const SizedBox(height: 32),
                _buildCard([
                  _buildActionButton(
                    tr('settings_logs'),
                    Icons.description,
                    _viewLogs,
                  ),
                  const SizedBox(height: 16),
                  _buildActionButton(
                    tr(
                      'settings_repairing',
                    ).replaceAll('...', ''), // "Repair Game"
                    Icons.build,
                    _repairGame,
                    iconColor: Colors.orange,
                    color: Colors.orange,
                  ),
                  const SizedBox(height: 16),
                  _buildActionButton(
                    tr('settings_uninstall_confirm_title'), // "Uninstall Game"
                    Icons.delete_forever,
                    _uninstallGame,
                    iconColor: Colors.red,
                    color: Colors.red,
                  ),
                ]),

                const SizedBox(height: 32),
                _buildSectionTitle(tr('settings_graphics')),
                const SizedBox(height: 16),
                _buildCard([
                  _buildSwitch(
                    tr('settings_fullscreen'),
                    tr('settings_fullscreen_desc'),
                    _fullscreen,
                    (val) => setState(() => _fullscreen = val),
                    Icons.fullscreen,
                  ),
                  const Divider(color: Colors.white10, height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        tr('settings_ram'),
                        style: GoogleFonts.inter(
                          color: Colors.white70,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        "${_ramAllocation}MB",
                        style: GoogleFonts.inter(
                          color: Theme.of(context).primaryColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  SliderTheme(
                    data: SliderThemeData(
                      activeTrackColor: Theme.of(context).primaryColor,
                      inactiveTrackColor: Colors.white10,
                      thumbColor: Colors.white,
                      overlayColor: Theme.of(
                        context,
                      ).primaryColor.withValues(alpha: 0.2),
                    ),
                    child: Slider(
                      value: _ramAllocation.toDouble(),
                      min: 1024,
                      max: 16384,
                      divisions: 15,
                      onChanged: (val) =>
                          setState(() => _ramAllocation = val.toInt()),
                    ),
                  ),
                ]),

                const SizedBox(height: 32),
                _buildSectionTitle(tr('settings_advanced')),
                const SizedBox(height: 16),
                _buildCard([
                  _buildSwitch(
                    tr('settings_close_launcher'),
                    tr('settings_close_launcher_desc'),
                    _closeLauncherOnStart,
                    (val) {
                      setState(() => _closeLauncherOnStart = val);
                      // Auto save or let main save handle it?
                      // Main save calls _saveSettings which doesn't handle this yet.
                      // Let's add it to _saveSettings or just save here.
                      // For now, _saveSettings handles saving.
                    },
                    Icons.exit_to_app,
                  ),
                  const Divider(color: Colors.white10, height: 32),
                  _buildSwitch(
                    tr('settings_always_on_top'),
                    tr('settings_always_on_top_desc'),
                    _alwaysOnTop,
                    (val) {
                      setState(() => _alwaysOnTop = val);
                      windowManager.setAlwaysOnTop(val);
                    },
                    Icons.layers,
                  ),
                  const Divider(color: Colors.white10, height: 32),
                  _buildSwitch(
                    tr('settings_discord'),
                    tr('settings_discord_desc'),
                    _discordRpc,
                    (val) => setState(() => _discordRpc = val),
                    Icons.discord,
                  ),
                  const Divider(color: Colors.white10, height: 32),
                  _buildSwitch(
                    tr('settings_java'),
                    tr('settings_java_desc'),
                    _customJavaEnabled,
                    (val) => setState(() => _customJavaEnabled = val),
                    Icons.coffee,
                  ),
                  if (_customJavaEnabled) ...[
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            tr('settings_java_path'),
                            _javaPathController,
                            icon: Icons.code,
                          ),
                        ),
                        const SizedBox(width: 12),
                        IconButton(
                          onPressed: _pickJavaPath,
                          icon: const Icon(Icons.folder_open),
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.white10,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.all(12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ]),

                const SizedBox(height: 40),

                // Save Button at the bottom
                Align(
                  alignment: Alignment.centerRight,
                  child: SizedBox(
                    width: 200,
                    child: AnimatedModernButton(
                      text: tr('settings_save'),
                      icon: Icons.check,
                      onPressed: _saveSettings,
                      isPrimary: true,
                    ),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.settings, color: Theme.of(context).primaryColor),
          ),
          const SizedBox(width: 16),
          Text(
            tr('settings_title'),
            style: GoogleFonts.inter(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return FadeInEntry(
      delay: const Duration(milliseconds: 200),
      child: Text(
        title.toUpperCase(),
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).primaryColor.withValues(alpha: 0.8),
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildCard(List<Widget> children) {
    return FadeInEntry(
      delay: const Duration(milliseconds: 300),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      ),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller, {
    IconData? icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            color: Colors.white70,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          style: GoogleFonts.inter(color: Colors.white),
          decoration: InputDecoration(
            prefixIcon: icon != null
                ? Icon(icon, color: Colors.white38, size: 20)
                : null,
            filled: true,
            fillColor: Colors.black.withValues(alpha: 0.3),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: Colors.white.withValues(alpha: 0.05),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: Theme.of(context).primaryColor,
                width: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReadOnlyField(
    String label,
    String value, {
    IconData? icon,
    Widget? trailing,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            color: Colors.white70,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              if (icon != null) ...[
                Icon(icon, color: Colors.white38, size: 20),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: SelectableText(
                  value,
                  style: GoogleFonts.inter(color: Colors.white),
                ),
              ),
              if (trailing != null) trailing,
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildUuidField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          tr('uuid_label'),
          style: GoogleFonts.inter(
            color: Colors.white70,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: Row(
            children: [
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _uuid,
                  style: GoogleFonts.jetBrainsMono(
                    color: Colors.white54,
                    fontSize: 13,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh, size: 18),
                color: Colors.white38,
                tooltip: tr('uuid_generate_tooltip'),
                onPressed: _regenerateUuid,
              ),
              IconButton(
                icon: const Icon(Icons.copy, size: 18),
                color: Colors.white38,
                tooltip: tr('uuid_copy_tooltip'),
                onPressed: _copyUuid,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDropdown(
    String label,
    String value,
    Map<String, String> items,
    Function(String?) onChanged, {
    IconData? icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            color: Colors.white70,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: items.containsKey(value) ? value : items.keys.first,
              isExpanded: true,
              dropdownColor: const Color(0xFF1E1E1E),
              icon: Icon(
                Icons.keyboard_arrow_down,
                color: Theme.of(context).primaryColor,
              ),
              style: GoogleFonts.inter(color: Colors.white),
              onChanged: onChanged,
              items: items.entries.map((entry) {
                return DropdownMenuItem<String>(
                  value: entry.key,
                  child: Row(
                    children: [
                      if (icon != null) ...[
                        Icon(icon, size: 16, color: Colors.white54),
                        const SizedBox(width: 12),
                      ],
                      Text(entry.value),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton(
    String label,
    IconData icon,
    VoidCallback onPressed, {
    Color? color,
    Color? iconColor,
  }) {
    return ScaleOnHover(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            decoration: BoxDecoration(
              color: (color ?? Colors.white).withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: (color ?? Colors.white).withValues(alpha: 0.05),
              ),
            ),
            child: Row(
              children: [
                Icon(icon, color: iconColor ?? Theme.of(context).primaryColor),
                const SizedBox(width: 16),
                Text(
                  label,
                  style: GoogleFonts.inter(
                    color: color ?? Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                Icon(
                  Icons.arrow_forward_ios,
                  color: (color ?? Colors.white).withValues(alpha: 0.38),
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSwitch(
    String title,
    String subtitle,
    bool value,
    Function(bool) onChanged,
    IconData icon,
  ) {
    return SwitchListTile(
      value: value,
      onChanged: onChanged,
      activeThumbColor: Theme.of(context).primaryColor,
      contentPadding: EdgeInsets.zero,
      title: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: value ? Theme.of(context).primaryColor : Colors.white38,
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: GoogleFonts.inter(
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(left: 32),
        child: Text(
          subtitle,
          style: GoogleFonts.inter(color: Colors.white54, fontSize: 12),
        ),
      ),
    );
  }
}
