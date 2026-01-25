# 🌌 Luyumi Launcher

<div align="center">

<img src="https://i.imgur.com/WCmjbkx.png" width="150" alt="Luyumi Logo">

![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)
![Python](https://img.shields.io/badge/Python-3776AB?style=for-the-badge&logo=python&logoColor=white)
![Platform](https://img.shields.io/badge/Platform-Windows%20%7C%20Linux%20%7C%20macOS-lightgrey?style=for-the-badge)
![License](https://img.shields.io/badge/License-MIT-green?style=for-the-badge)

**A next-generation, cross-platform custom launcher for Hytale.**  
*Built with the power of Flutter and Python.*

[Features](#-features) • [Installation](#-installation) • [Architecture](#-architecture) • [Credits](#-credits)

</div>

---

## 📖 About

**Luyumi Launcher** is a modern, open-source launcher designed to provide a seamless and customizable experience for Hytale players. Based on the **Hytale F2P** project, Luyumi leverages the responsiveness of **Flutter** for the UI and the robustness of **Python** for backend operations, offering a unique hybrid architecture that ensures performance and flexibility.

It extends the **Hytale F2P** ecosystem and integrates directly with **Sanasol.ws** services, providing enhanced authentication features and offline capabilities.

## 🖼️ Screenshots

![Screenshots 1](https://iili.io/f6jMo3x.png)
![Screenshots 2](https://iili.io/f6jVDgf.png)
![Screenshots 3](https://iili.io/f6jXhn1.png)
![Screenshots 4](https://iili.io/f6jh0iX.png)

## ✨ Features

- **🚀 Hybrid Architecture**: Combines a beautiful, fluid Flutter frontend with a powerful Python backend for game management.
- **🔐 Custom Authentication**: Secure integration with `sessions.sanasol.ws` for identity management.
- **👕 Unlocked Skins**: Full access to all skins and character customization features when using the Online Mode.
- **📡 Offline Mode**: Robust fallback system that generates local tokens, allowing you to play even without an internet connection.
- **🖥️ Cross-Platform**: Native support for **Windows**, **Linux** (including Wayland), and **macOS**.
- **🛠️ Smart Patching**: Automatic binary patching for game clients to ensure compatibility with custom authentication servers.
- **📦 Smart Installer**: A dedicated Flutter-based installer that can fetch the latest releases from GitHub or install a bundled local version.
- **🎨 Modern UI**: sleek, acrylic-styled interface with support for themes and localization.
- **📦 Mod Management**: (In Progress) Sync and manage mods directly from the launcher.

## 📱 Mobile Version (In Development)

> **Announcement**: An Android version of the launcher is currently under active development!

This is a challenging but possible endeavor. Unlike Minecraft (pure Java), Hytale is built with Java and C#, which prevents us from using the same approach as *PojavLauncher*.

To overcome this, we are leveraging **FEX-Emu**, a powerful x86 to ARM emulator. Since there is no native ARM Linux version of Hytale yet, we will emulate the **Linux x86** version of the game on Android devices.

Stay tuned for updates on the Luyumi Launcher for Android! 🚀

![Screenshot Mobile](https://iili.io/f6jreLJ.png)

## 🏗️ Architecture

Luyumi Launcher uses a **Client-Server** model running locally:

1.  **Frontend (Dart/Flutter)**: Handles the User Interface, animations, and user input.
2.  **Backend (Python)**: Runs as a subprocess. Handles heavy lifting like:
    -   Game process launching and monitoring.
    -   File downloading and verification (Java, Game Assets).
    -   Binary patching (Hex editing for domain redirection).
    -   Authentication logic (EdDSA token signing).
3.  **Communication**: The frontend and backend communicate via **IPC (Inter-Process Communication)** using JSON messages over `stdin`/`stdout`, with an HTTP fallback.

## 🚀 Installation & Building

### Prerequisites

-   **Flutter SDK**: [Install Flutter](https://flutter.dev/docs/get-started/install)
-   **Python 3.10+**: [Install Python](https://www.python.org/downloads/)
-   **Git**: [Install Git](https://git-scm.com/)

### Steps

1.  **Clone the repository**
    ```bash
    git clone https://github.com/YourUsername/Luyumi_Launcher.git
    cd Luyumi_Launcher
    ```

2.  **Install Flutter dependencies**
    ```bash
    flutter pub get
    ```

3.  **Setup Python Environment**
    Ensure you have the required Python packages (see `requirements.txt` if available, or install core deps):
    ```bash
    pip install requests flask
    # Note: The backend uses standard libraries mostly, but check for specific requirements.
    ```

4.  **Run the Launcher**
    ```bash
    flutter run
    ```

## 🤝 Credits & Acknowledgements

**Luyumi Launcher developed by [ShindoZk](https://github.com/ShindoZk)**  
💬 Discord: `shindozk`

This project stands on the shoulders of giants. Special thanks to:

-   **[Hytale F2P](https://github.com/amiayweb/Hytale-F2P)** by **Amiayweb**: For the foundational work on the game launching logic, patching methods, and API structures. Luyumi's backend borrows logic from the F2P reference implementation.
-   **Sanasol.ws**: For providing the authentication infrastructure and game session services.
-   **The Flutter Team**: For the amazing UI toolkit.

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

<div align="center">
Made with ❤️ for the Hytale Community
<br>
Made in Brazil 🇧🇷
</div>
