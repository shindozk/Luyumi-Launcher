import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/services/audio_service.dart';
import '../widgets/auth_dialog.dart';
import '../widgets/animations.dart'; // Keeping this for FadeInEntry

class ProfileView extends StatefulWidget {
  final String? username;
  final String? uuid;
  final VoidCallback? onBack;
  final ValueChanged<String>? onUsernameChanged;
  final ValueChanged<String>? onUsernameSaved;

  const ProfileView({
    super.key,
    this.username,
    this.uuid,
    this.onBack,
    this.onUsernameChanged,
    this.onUsernameSaved,
  });

  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> {
  Map<String, dynamic>? _currentUser;
  bool _isLoggedIn = false;

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    // Ideally check if we have a stored session that matches a DB user
    // For now, we rely on the AuthDialog to set the state, or check local prefs
    // If you want to persist login across restarts, you'd need to save the token/user info locally
    // and load it here.
    
    // For this implementation, I'll rely on the parent or fresh login, 
    // but I'll check if the widget.username corresponds to a logged in user if feasible.
  }

  Future<void> _showAuthDialog() async {
    final user = await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AuthDialog(),
    );

    if (user != null && user is Map<String, dynamic>) {
      setState(() {
        _currentUser = user;
        _isLoggedIn = true;
      });
      
      // Update the parent/legacy system with the new username
      widget.onUsernameSaved?.call(user['username']);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Welcome back, ${user['username']}!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _logout() {
    setState(() {
      _currentUser = null;
      _isLoggedIn = false;
    });
    // Revert to default or offline name if needed
    widget.onUsernameSaved?.call("Player");
  }

  String _getDisplayUsername() {
    if (_isLoggedIn && _currentUser != null) {
      return _currentUser!['username'];
    }
    return widget.username ?? "Player";
  }

  String _getDisplayBio() {
    if (_isLoggedIn && _currentUser != null) {
      return _currentUser!['bio'] ?? "No bio available.";
    }
    return "You are currently in Offline Mode. Log in to access cloud features, friends, and more.";
  }

  @override
  Widget build(BuildContext context) {
    final displayName = _getDisplayUsername();
    final displayBio = _getDisplayBio();
    
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: FadeInEntry(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Banner Section
              _buildProfileBanner(displayName),
              
              const SizedBox(height: 24),
              
              // Info & Bio Section
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left Column: Stats / Info
                  Expanded(
                    flex: 1,
                    child: Column(
                      children: [
                        _buildInfoCard(
                          title: "Status",
                          content: _isLoggedIn ? "Online" : "Offline",
                          icon: Icons.circle,
                          iconColor: _isLoggedIn ? Colors.green : Colors.grey,
                        ),
                        const SizedBox(height: 16),
                        _buildInfoCard(
                          title: "Account Type",
                          content: _isLoggedIn ? "Luyumi Account" : "Local Account",
                          icon: Icons.shield_outlined,
                        ),
                         const SizedBox(height: 16),
                         if (!_isLoggedIn)
                           _buildLoginPromptCard(),
                      ],
                    ),
                  ),
                  
                  const SizedBox(width: 24),
                  
                  // Right Column: Bio & Details
                  Expanded(
                    flex: 2,
                    child: Column(
                      children: [
                        _buildBioCard(displayBio),
                        const SizedBox(height: 24),
                        if (_isLoggedIn)
                           _buildActionButtons(),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileBanner(String username) {
    return Container(
      height: 280,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        color: const Color(0xFF27272A),
        image: const DecorationImage(
          image: AssetImage('lib/assets/images/blog_cover_4666219169b117610c44205c41707e4f_e208b945a93c8dc6a00a8257309badb9_undergroundjungledinorun_01_raw.png'),
          fit: BoxFit.cover,
          opacity: 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 30,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Gradient Overlay
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(32),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.8),
                ],
              ),
            ),
          ),
          
          // User Info
          Positioned(
            bottom: 32,
            left: 32,
            child: Row(
              children: [
                // Avatar
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                    image: _currentUser != null && _currentUser!['avatarUrl'] != null
                        ? DecorationImage(
                            image: NetworkImage(_currentUser!['avatarUrl']),
                            fit: BoxFit.cover,
                          )
                        : const DecorationImage(
                            image: AssetImage('lib/assets/images/hytale-layered-2-(1).png'),
                            fit: BoxFit.cover,
                          ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 24),
                
                // Name & Tag
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      username,
                      style: GoogleFonts.inter(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        shadows: [
                           const Shadow(blurRadius: 10, color: Colors.black54, offset: Offset(0, 2)),
                        ]
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                      ),
                      child: Text(
                        _isLoggedIn ? "Premium User" : "Guest",
                        style: GoogleFonts.inter(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Edit/Settings Button (Top Right)
          Positioned(
            top: 24,
            right: 24,
            child: IconButton(
              onPressed: () {
                // Settings action
              },
              style: IconButton.styleFrom(
                backgroundColor: Colors.black.withValues(alpha: 0.3),
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.settings),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard({required String title, required String content, required IconData icon, Color? iconColor}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF18181B).withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: iconColor ?? Colors.white54),
              const SizedBox(width: 12),
              Text(
                title,
                style: GoogleFonts.inter(
                  color: Colors.white54,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            content,
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBioCard(String bio) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: const Color(0xFF18181B).withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.format_quote_rounded, color: Colors.white24, size: 32),
              const SizedBox(width: 16),
              Text(
                "About Me",
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            bio,
            style: GoogleFonts.inter(
              color: Colors.white70,
              fontSize: 16,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginPromptCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).primaryColor.withValues(alpha: 0.2),
            Theme.of(context).primaryColor.withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Theme.of(context).primaryColor.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Text(
            "Sync your data",
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Login to save your progress and customize your profile.",
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _showAuthDialog,
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: Text(
              "Login / Register",
              style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildActionButtons() {
     return Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
           TextButton.icon(
              onPressed: () {
                AudioService().playClick();
                _logout();
              },
              icon: const Icon(Icons.logout, color: Colors.redAccent),
              label: Text("Logout", style: GoogleFonts.inter(color: Colors.redAccent)),
           ),
        ],
     );
  }
}
