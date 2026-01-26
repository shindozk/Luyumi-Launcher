import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../core/models/mod_model.dart';
import '../../core/services/mod_service.dart';
import '../../core/services/settings_service.dart';
import '../widgets/animations.dart';

class ModsView extends StatefulWidget {
  const ModsView({super.key});

  @override
  State<ModsView> createState() => _ModsViewState();
}

class _ModsViewState extends State<ModsView> with TickerProviderStateMixin {
  final SettingsService _settingsService = SettingsService();
  final ModService _modService = ModService();
  
  // Tab Controller
  late TabController _tabController;

  // Shared State
  String _activeProfileId = 'default';
  
  // Installed Tab State
  final TextEditingController _installedSearchController = TextEditingController();
  List<ModModel> _mods = [];
  bool _isLoadingInstalled = true;
  String _filterStatus = 'all'; // all, enabled, disabled, missing
  final String _sortBy = 'name_asc'; // name_asc, name_desc, author

  // Explore Tab State
  final TextEditingController _exploreSearchController = TextEditingController();
  List<dynamic> _exploreMods = [];
  bool _isLoadingExplore = false;
  int _explorePage = 0;
  final ScrollController _exploreScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadProfileAndMods();
    
    _installedSearchController.addListener(() => setState(() {}));
    
    // Add listener for pagination
    _exploreScrollController.addListener(() {
      if (_exploreScrollController.position.pixels >= 
          _exploreScrollController.position.maxScrollExtent - 200) {
        if (!_isLoadingExplore) {
          _searchExploreMods(loadMore: true);
        }
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _installedSearchController.dispose();
    _exploreSearchController.dispose();
    _exploreScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadProfileAndMods() async {
    final profileId = await _settingsService.getActiveProfile();
    if (mounted) {
      setState(() => _activeProfileId = profileId);
      await _loadMods();
      _searchExploreMods(); // Initial load for explore tab (popular mods)
    }
  }

  // --- Installed Tab Logic ---

  List<ModModel> get _filteredMods {
    List<ModModel> filtered = List.from(_mods);

    // 1. Search
    if (_installedSearchController.text.isNotEmpty) {
      final query = _installedSearchController.text.toLowerCase();
      filtered = filtered.where((mod) {
        return mod.name.toLowerCase().contains(query) || 
               mod.fileName.toLowerCase().contains(query) ||
               mod.author.toLowerCase().contains(query);
      }).toList();
    }

    // 2. Filter Status
    if (_filterStatus == 'enabled') {
      filtered = filtered.where((m) => m.enabled && !m.missing).toList();
    } else if (_filterStatus == 'disabled') {
      filtered = filtered.where((m) => !m.enabled && !m.missing).toList();
    } else if (_filterStatus == 'missing') {
      filtered = filtered.where((m) => m.missing).toList();
    }

    // 3. Sort
    filtered.sort((a, b) {
      if (_sortBy == 'name_asc') {
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      } else if (_sortBy == 'name_desc') {
        return b.name.toLowerCase().compareTo(a.name.toLowerCase());
      } else if (_sortBy == 'author') {
        return a.author.toLowerCase().compareTo(b.author.toLowerCase());
      }
      return 0;
    });

    return filtered;
  }

  Future<void> _loadMods() async {
    setState(() => _isLoadingInstalled = true);
    final mods = await _modService.getMods(_activeProfileId);
    if (mounted) {
      setState(() {
        if (mods.isEmpty) {
          _mods = []; 
        } else {
          _mods = mods;
        }
        _isLoadingInstalled = false;
      });
    }
  }

  Future<void> _syncMods() async {
    setState(() => _isLoadingInstalled = true);
    final success = await _modService.syncMods(_activeProfileId);
    if (success) {
      await _loadMods();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(tr('mods_sync_success'))));
      }
    } else {
      if (mounted) {
        setState(() => _isLoadingInstalled = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('mods_sync_error')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _toggleMod(ModModel mod, bool value) async {
    final index = _mods.indexWhere((m) => m.id == mod.id);
    if (index == -1) return;

    final oldState = _mods[index];
    setState(() {
      _mods[index] = ModModel(
        id: mod.id,
        name: mod.name,
        version: mod.version,
        description: mod.description,
        author: mod.author,
        enabled: value,
        fileName: mod.fileName,
        fileSize: mod.fileSize,
        dateInstalled: mod.dateInstalled,
        curseForgeId: mod.curseForgeId,
        curseForgeFileId: mod.curseForgeFileId,
        missing: mod.missing,
      );
    });

    final success = await _modService.toggleMod(
      _activeProfileId,
      mod.id,
      value,
    );
    if (!success) {
      if (mounted) {
        setState(() {
          _mods[index] = oldState;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('mods_toggle_error')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _uninstallMod(ModModel mod) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: Text(tr('settings_manage_mods'), style: GoogleFonts.inter(color: Colors.white)),
        content: Text(tr('mods_uninstall_confirm'), style: GoogleFonts.inter(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(tr('dialog_cancel'), style: GoogleFonts.inter(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              tr('settings_uninstall'),
              style: GoogleFonts.inter(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await _modService.uninstallMod(_activeProfileId, mod.id);
      if (success) {
        await _loadMods();
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(tr('mods_uninstall_success'))));
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(tr('mods_uninstall_error')),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  // --- Explore Tab Logic ---

  Future<void> _searchExploreMods({bool loadMore = false}) async {
    if (_isLoadingExplore && !loadMore) return;
    if (_isLoadingExplore && loadMore) return;
    
    setState(() => _isLoadingExplore = true);
    
    if (!loadMore) {
      _explorePage = 0;
      _exploreMods = [];
    } else {
      _explorePage++;
    }

    try {
      final result = await _modService.searchMods(
        _exploreSearchController.text, 
        index: _explorePage * 20
      );
      
      if (mounted) {
        setState(() {
          if (result['data'] != null) {
            final newMods = List<dynamic>.from(result['data']);
            if (loadMore) {
              _exploreMods.addAll(newMods);
            } else {
              _exploreMods = newMods;
            }
          }
          _isLoadingExplore = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingExplore = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error searching mods: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _installModFromCF(dynamic cfMod) async {
    if (cfMod['latestFiles'] == null || (cfMod['latestFiles'] as List).isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No files available for this mod')),
      );
      return;
    }

    final latestFile = cfMod['latestFiles'][0];
    final downloadUrl = latestFile['downloadUrl'];
    final fileName = latestFile['fileName'];

    if (downloadUrl == null) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Downloading ${cfMod['name']}...')),
    );

    final success = await _modService.installModCF(downloadUrl, fileName, _activeProfileId);

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Installed ${cfMod['name']} successfully!')),
        );
        _loadMods();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to install ${cfMod['name']}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildExploreTab(),
                _buildInstalledTab(),
              ],
            ),
          ),
        ],
      ),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.extension, color: Theme.of(context).primaryColor),
              ),
              const SizedBox(width: 16),
              Text(
                tr('mods_title'),
                style: GoogleFonts.inter(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const Spacer(),
              _buildIconButton(
                icon: Icons.sync,
                tooltip: tr('mods_sync'),
                onPressed: _isLoadingInstalled ? null : _syncMods,
              ),
              const SizedBox(width: 8),
              _buildIconButton(
                icon: Icons.folder_open_rounded,
                tooltip: tr('mods_folder'),
                onPressed: () => _modService.openModsFolder(_activeProfileId),
              ),
            ],
          ),
          const SizedBox(height: 24),
          TabBar(
            controller: _tabController,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            indicator: UnderlineTabIndicator(
              borderSide: BorderSide(
                width: 2.0,
                color: Theme.of(context).primaryColor,
              ),
            ),
            labelColor: Theme.of(context).primaryColor,
            unselectedLabelColor: Colors.white54,
            labelStyle: GoogleFonts.inter(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
            unselectedLabelStyle: GoogleFonts.inter(
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
            dividerColor: Colors.transparent,
            overlayColor: WidgetStateProperty.all(Colors.transparent),
            tabs: [
              Tab(text: tr('mods_tab_explore')),
              Tab(text: tr('mods_tab_installed')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildIconButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback? onPressed,
  }) {
    return IconButton(
      onPressed: onPressed,
      icon: Icon(icon, size: 20),
      tooltip: tooltip,
      style: IconButton.styleFrom(
        backgroundColor: Colors.white.withValues(alpha: 0.05),
        foregroundColor: Colors.white70,
        padding: const EdgeInsets.all(12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  // --- Explore Tab UI ---
  Widget _buildExploreTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tr('mods_explore_search_hint'),
                style: GoogleFonts.inter(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _exploreSearchController,
                style: GoogleFonts.inter(color: Colors.white),
                onSubmitted: (_) => _searchExploreMods(),
                decoration: InputDecoration(
                  hintText: tr('mods_search_hint'),
                  hintStyle: GoogleFonts.inter(color: Colors.white30),
                  prefixIcon: const Icon(Icons.search, color: Colors.white30),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.arrow_forward, color: Colors.white70),
                    onPressed: () => _searchExploreMods(),
                  ),
                  filled: true,
                  fillColor: Colors.black.withValues(alpha: 0.3),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: Theme.of(context).primaryColor,
                      width: 1.5,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _isLoadingExplore && _exploreMods.isEmpty
            ? Center(child: CircularProgressIndicator(color: Theme.of(context).primaryColor))
            : _exploreMods.isEmpty
              ? _buildExploreEmptyState()
              : FadeInEntry(
                  delay: const Duration(milliseconds: 200),
                  child: GridView.builder(
                    controller: _exploreScrollController,
                    padding: const EdgeInsets.fromLTRB(32, 0, 32, 32),
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 400,
                      mainAxisExtent: 140,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                    ),
                    itemCount: _exploreMods.length,
                    itemBuilder: (context, index) {
                       return _buildExploreCard(_exploreMods[index]);
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildExploreEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 64, color: Colors.white12),
          const SizedBox(height: 16),
          Text(
            tr('mods_explore_no_results'),
            style: GoogleFonts.inter(color: Colors.white54, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildExploreCard(dynamic mod) {
    final String name = mod['name'] ?? 'Unknown';
    final String summary = mod['summary'] ?? '';
    final String author = (mod['authors'] != null && (mod['authors'] as List).isNotEmpty) 
        ? mod['authors'][0]['name'] 
        : 'Unknown';
    final String? iconUrl = mod['logo'] != null ? mod['logo']['thumbnailUrl'] : null;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () {}, // Maybe show details later
          borderRadius: BorderRadius.circular(16),
          hoverColor: Colors.white.withValues(alpha: 0.02),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(12),
                    image: iconUrl != null 
                      ? DecorationImage(image: NetworkImage(iconUrl), fit: BoxFit.cover)
                      : null,
                  ),
                  child: iconUrl == null ? Icon(Icons.extension, color: Colors.white24) : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'by $author',
                        style: GoogleFonts.inter(color: Theme.of(context).primaryColor, fontSize: 12, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        summary,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(color: Colors.white54, fontSize: 11, height: 1.2),
                      ),
                    ],
                  ),
                ),
                Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.download_rounded),
                      color: Theme.of(context).primaryColor,
                      onPressed: () => _installModFromCF(mod),
                      tooltip: tr('mods_install_button'),
                      style: IconButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                        padding: EdgeInsets.all(8),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- Installed Tab UI ---
  Widget _buildInstalledTab() {
    final filtered = _filteredMods;
    
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tr('mods_search_hint'),
                style: GoogleFonts.inter(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _installedSearchController,
                      style: GoogleFonts.inter(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: tr('mods_search_hint'),
                        hintStyle: GoogleFonts.inter(color: Colors.white30),
                        prefixIcon: const Icon(Icons.search, color: Colors.white30),
                        filled: true,
                        fillColor: Colors.black.withValues(alpha: 0.3),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: Theme.of(context).primaryColor,
                            width: 1.5,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  _buildFilterBar(),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: _isLoadingInstalled
              ? Center(
                  child: CircularProgressIndicator(
                    color: Theme.of(context).primaryColor,
                  ),
                )
              : filtered.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(32, 0, 32, 32),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final mod = filtered[index];
                        return FadeInEntry(
                          delay: Duration(milliseconds: 30 * index),
                          child: _buildModTile(mod),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _filterStatus,
          dropdownColor: const Color(0xFF1E1E1E),
          style: GoogleFonts.inter(color: Colors.white70, fontSize: 13),
          icon: const Icon(Icons.filter_list, color: Colors.white54, size: 20),
          items: [
            DropdownMenuItem(value: 'all', child: Text(tr('mods_filter_all'))),
            DropdownMenuItem(value: 'enabled', child: Text(tr('mods_filter_enabled'))),
            DropdownMenuItem(value: 'disabled', child: Text(tr('mods_filter_disabled'))),
            DropdownMenuItem(value: 'missing', child: Text(tr('mods_filter_missing'))),
          ],
          onChanged: (val) {
            if (val != null) setState(() => _filterStatus = val);
          },
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.extension_off, size: 64, color: Colors.white12),
          const SizedBox(height: 16),
          Text(
            tr('mods_empty'),
            style: GoogleFonts.inter(color: Colors.white54, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildModTile(ModModel mod) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: mod.missing 
              ? Colors.red.withValues(alpha: 0.3) 
              : Colors.white.withValues(alpha: 0.05),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: mod.missing 
                ? Colors.red.withValues(alpha: 0.1) 
                : Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            mod.missing ? Icons.broken_image : Icons.extension,
            color: mod.missing ? Colors.red : Theme.of(context).primaryColor,
          ),
        ),
        title: Text(
          mod.name,
          style: GoogleFonts.inter(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            decoration: mod.enabled ? null : TextDecoration.lineThrough,
            decorationColor: Colors.white30,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (mod.missing)
              Text(
                tr('mods_missing'),
                style: GoogleFonts.inter(color: Colors.redAccent, fontSize: 12),
              )
            else
              Text(
                '${mod.fileName} • ${mod.version}',
                style: GoogleFonts.inter(color: Colors.white38, fontSize: 12),
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Switch(
              value: mod.enabled,
              onChanged: mod.missing ? null : (val) => _toggleMod(mod, val),
              activeThumbColor: Theme.of(context).primaryColor,
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 20),
              color: Colors.white38,
              onPressed: () => _uninstallMod(mod),
              tooltip: tr('settings_uninstall'),
            ),
          ],
        ),
      ),
    );
  }
}
