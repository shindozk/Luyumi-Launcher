<h1 align="center">Luyumi Launcher</h1>

<div align="center">

<img src="https://i.imgur.com/WCmjbkx.png" width="150" alt="Luyumi Logo">

![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)
![TypeScript](https://img.shields.io/badge/TypeScript-3178C6?style=for-the-badge&logo=typescript&logoColor=white)
![Bun](https://img.shields.io/badge/Bun-000000?style=for-the-badge&logo=bun&logoColor=white)
![Platform](https://img.shields.io/badge/Platform-Windows%20%7C%20Linux%20%7C%20macOS-lightgrey?style=for-the-badge)
![License](https://img.shields.io/badge/License-MIT-green?style=for-the-badge)

**A next-generation, cross-platform custom launcher for Hytale.**  
*Built with Flutter and TypeScript, featuring auto-build backend system.*

[Features](#-features) • [Installation](#-installation) • [Architecture](#-architecture) • [Credits](#-credits)

</div>

---

<h2 align="center">📖 About</h2>

**Luyumi Launcher** is a modern, open-source launcher designed to provide a seamless and customizable experience for Hytale players. Based on the **Hytale F2P** project, Luyumi features a revolutionary **auto-build backend system** that compiles TypeScript source code on every launch, ensuring you always have the latest features and fixes.

It extends the **Hytale F2P** ecosystem and integrates directly with **Sanasol.ws** services, providing enhanced authentication features and offline capabilities.

<h2 align="center">🖼️ Screenshots</h2>

![Screenshots 1](https://iili.io/f6jMo3x.png)
![Screenshots 2](https://iili.io/f6jVDgf.png)
![Screenshots 3](https://iili.io/f6jXhn1.png)
![Screenshots 4](https://iili.io/f6jh0iX.png)

<h2 align="center">✨ Features</h2>

<h3 align="center">Core Features</h3>

- **🚀 Auto-Build Backend**: Revolutionary system that automatically compiles the backend from TypeScript source on every launch
- **🔧 Self-Healing**: Auto-installs Bun.js if missing, ensuring zero manual setup
- **📺 Beautiful Init Screen**: Animated loading screen with logo entrance, text slide-in, and progress tracking
- **🎨 Modern UI**: Sleek, acrylic-styled interface with glassmorphism effects and smooth animations
- **🔐 Custom Authentication**: Secure integration with `sessions.sanasol.ws` for identity management
- **👕 Unlocked Skins**: Full access to all skins and character customization when using Online Mode
- **📡 Offline Mode**: Robust fallback system with local token generation
- **🖥️ Cross-Platform**: Native support for **Windows**, **Linux**, and **macOS**

<h3 align="center">Game Management</h3>

- **🛠️ Smart Patching**: Automatic binary patching for game clients to ensure compatibility
- **📦 Delta Updates**: Efficient differential patching system - only download changed files
- **🔖 Version Control**: Tracks installed game versions via metadata (`luyumi_metadata.json`) for accurate updates
- **🔍 Integrity Check**: Advanced installation detection to verify game files and identify corruption
- **🧹 Auto Cleanup**: Intelligent cache management that removes old patch files
- **☕ Java Management**: Automatic Java detection and installation
- **🎮 Game Process Control**: Launch, monitor, and gracefully stop game processes

<h3 align="center">Mod System</h3>

- **📦 Mod Management**: Full-featured mod manager with enable/disable functionality
- **🔄 Mod Sync**: Synchronize mods across different profiles
- **📋 Profile System**: Create and manage multiple game profiles with isolated mod configurations
- **📄 Butler Integration**: Native support for Butler protocol mods

<h3 align="center">UI/UX Excellence</h3>

- **🌍 Multi-Language**: 8 languages supported (EN, PT, ES, ZH, JA, KO, RU, FR)
- **🌙 Dark Mode**: Beautiful dark theme with acrylic effects
- **✨ Smooth Animations**: Micro-animations throughout the interface
- **📊 Progress Bar**: Modern animated progress indicators with completion effects
- **🎯 Version Display**: Dynamic version tracking for both launcher and game with update notifications

<h2 align="center">🏗️ Architecture</h2>

Luyumi Launcher uses an innovative **Auto-Build Client-Server** model:

<h3 align="center">Frontend (Flutter/Dart)</h3>

```
lib/
├── ui/
│   ├── screens/
│   │   ├── init_screen.dart    # Animated initialization screen
│   │   └── home_screen.dart    # Main launcher interface
│   ├── views/
│   │   ├── mods_view.dart      # Mod management UI
│   │   ├── profile_view.dart   # Profile selector
│   │   ├── settings_view.dart  # Settings panel
│   │   └── news_view.dart      # News feed
│   ├── widgets/
│   │   ├── animations.dart     # Reusable animation components
│   │   └── modern_progress_bar.dart  # Custom progress bar
│   └── theme/
│       └── app_theme.dart      # Material design theme
├── core/
│   ├── managers/
│   │   ├── backend_manager.dart    # Auto-build & backend lifecycle
│   │   ├── game_manager.dart       # Game installation & launch
│   │   └── profile_manager.dart    # Profile management
│   ├── services/
│   │   └── backend_service.dart    # HTTP client for backend API
│   └── models/
│       └── game_status.dart        # Game state models
└── assets/
    ├── logo/                   # Launcher branding
    ├── locales/                # i18n translations
    └── backend/                # Compiled backend executable
```

<h3 align="center">Backend (TypeScript/Bun)</h3>

```
lib/backend/
├── src/
│   ├── index.ts               # Elysia server entry point
│   ├── routes/
│   │   ├── auth.ts            # Authentication endpoints
│   │   ├── version.ts         # Version checking
│   │   ├── game.ts            # Game management
│   │   ├── mods.ts            # Mod operations
│   │   ├── java.ts            # Java management
│   │   └── news.ts            # News feed
│   ├── services/
│   │   ├── AuthService.ts         # EdDSA token signing
│   │   ├── GameService.ts         # Game download & install
│   │   ├── InstallationDetectionService.ts # Game integrity & status check
│   │   ├── PatcherService.ts      # Binary hex patching
│   │   ├── ModManager.ts          # Mod scanning & loading
│   │   ├── ModService.ts          # Mod installation
│   │   ├── JavaService.ts         # Java detection & install
│   │   ├── VersionService.ts      # Version management
│   │   ├── ProfileService.ts      # Profile isolation
│   │   ├── ButlerService.ts       # Butler protocol
│   │   └── UIService.ts           # Frontend communication
│   └── utils/
│       ├── paths.ts               # Path resolution
│       ├── platform.ts            # Platform detection
│       └── async.ts               # Async helpers
└── package.json               # Bun dependencies
```

<h3 align="center">Communication Flow</h3>

1. **Init Screen Phase**:
   - Check Bun.js installation → Auto-install if missing
   - Delete old backend executable
   - Compile backend from TypeScript source using `bun build --compile`
   - Start compiled backend server (Elysia on port 8080)
   - Verify backend health check

2. **Runtime Communication**:
   - Frontend ↔ Backend: RESTful HTTP API (localhost:8080)
   - Game ↔ Auth Server: Custom EdDSA token authentication
   - Mod System: Butler protocol support

<h2 align="center">🚀 Installation & Building</h2>

<h3 align="center">Prerequisites</h3>

- **Flutter SDK 3.10+**: [Install Flutter](https://flutter.dev/docs/get-started/install)
- **Bun.js** (auto-installed by launcher): [Bun Official Site](https://bun.sh)
- **Git**: [Install Git](https://git-scm.com/)

> **Note**: The launcher will automatically install Bun.js if it's not present on your system!

<h3 align="center">Quick Start</h3>

1. **Clone the repository**
   ```bash
   git clone https://github.com/shindozk/Luyumi-Launcher.git
   cd Luyumi-Launcher
   ```

2. **Install Flutter dependencies**
   ```bash
   flutter pub get
   ```

3. **Run the Launcher**
   ```bash
   flutter run -d windows
   # or
   flutter run -d linux
   # or
   flutter run -d macos
   ```

   On first run, the launcher will:
   - Display animated init screen
   - Auto-install Bun.js if needed
   - Compile the backend from source
   - Start the backend server
   - Navigate to the main screen

<h3 align="center">Building for Production</h3>

```bash
# Windows
flutter build windows --release

# Linux
flutter build linux --release

# macOS
flutter build macos --release
```

The compiled app will be in `build/{platform}/runner/Release/`

<h2 align="center">🛠️ Development</h2>

<h3 align="center">Backend Development</h3>

The backend is automatically rebuilt on every launcher start, so you can modify TypeScript files and see changes immediately:

```bash
# Backend source location
cd lib/backend

# Install dependencies (if adding new packages)
bun install

# The launcher will compile and run it automatically
# Or test manually:
bun run src/index.ts
```

<h3 align="center">Frontend Development</h3>

```bash
# Hot reload is available
flutter run

# Format code
dart format .

# Analyze for issues
flutter analyze
```

<h3 align="center">Adding New Backend Routes</h3>

1. Create route file in `lib/backend/src/routes/`
2. Create service file in `lib/backend/src/services/`  
3. Register route in `lib/backend/src/index.ts`
4. Update frontend `BackendService` to call new endpoint

<h3 align="center">Adding New Languages</h3>

1. Add locale code to `main.dart` supportedLocales
2. Create JSON file in `lib/assets/locales/{locale}.json`
3. Add translations using same keys as `en.json`

<h2 align="center">📱 Mobile Version (In Development)</h2>

> **Announcement**: An Android version is under active development!

Unlike Minecraft (pure Java), Hytale uses Java + C#. We're leveraging **FEX-Emu** (x86 to ARM emulator) to run the Linux x86 version on Android devices.

![Screenshot Mobile](https://iili.io/f6jreLJ.png)

<h2 align="center">🤝 Credits & Acknowledgements</h2>

**Luyumi Launcher developed by [ShindoZk](https://github.com/ShindoZk)**  
💬 Discord: `shindozk`  
🇧🇷 **Made in Brazil**

<h3 align="center">Special Thanks</h3>

- **[Hytale F2P](https://github.com/amiayweb/Hytale-F2P)** by **Amiayweb**: Original game launching logic and patching methods
- **Sanasol.ws**: Authentication infrastructure and game session services
- **The Flutter Team**: Amazing UI toolkit
- **The Bun Team**: Lightning-fast JavaScript runtime and bundler
- **Elysia.js**: Elegant TypeScript HTTP framework

<h2 align="center">📄 License</h2>

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

<h2 align="center">🌟 Star History</h2>

If you find this project useful, please consider giving it a star! ⭐

---

<div align="center">

**Made with ❤️ for the Hytale Community**  
🚀 Stay tuned for updates!

</div>
