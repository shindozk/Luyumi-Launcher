import path from 'path';
import os from 'os';
import fs from 'fs';

function getAppDir(): string {
  const home = os.homedir();
  if (process.platform === 'win32') {
    return path.join(process.env.APPDATA || path.join(home, 'AppData', 'Roaming'), 'LuyumiLauncher');
  } else if (process.platform === 'darwin') {
    return path.join(home, 'Library', 'Application Support', 'LuyumiLauncher');
  } else {
    return path.join(home, '.luyumilauncher');
  }
}

// Initialize with IIFE to ensure synchronous execution
export const APP_DIR = (() => getAppDir())();
export const CACHE_DIR = (() => path.join(APP_DIR, 'cache'))();
export const TOOLS_DIR = (() => path.join(APP_DIR, 'butler'))();
export const GAME_DIR = (() => path.join(APP_DIR, 'install', 'release', 'package', 'game', 'latest'))();
export const JRE_DIR = (() => path.join(APP_DIR, 'install', 'release', 'package', 'jre', 'latest'))();
export const PROFILES_DIR = (() => path.join(APP_DIR, 'profiles'))();

export function getResolvedAppDir(customPath?: string): string {
  if (customPath && customPath.trim()) {
    return path.join(customPath.trim(), 'LuyumiLauncher');
  }
  try {
    const configFile = path.join(APP_DIR, 'config.json');
    if (fs.existsSync(configFile)) {
      const config = JSON.parse(fs.readFileSync(configFile, 'utf8'));
      if (config.installPath && config.installPath.trim()) {
        return path.join(config.installPath.trim(), 'LuyumiLauncher');
      }
    }
  } catch (err) {
    // Ignore config errors, use default
  }
  return APP_DIR;
}

export function expandHome(inputPath: string | null | undefined): string | null {
  if (!inputPath) {
    return null;
  }
  if (inputPath === '~') {
    return os.homedir();
  }
  if (inputPath.startsWith('~/') || inputPath.startsWith('~\\')) {
    return path.join(os.homedir(), inputPath.slice(2));
  }
  return inputPath;
}

export function getClientCandidates(gameLatest: string) {
  const candidates: string[] = [];
  if (process.platform === 'win32') {
    // Windows - Only HytaleClient.exe
    candidates.push(path.join(gameLatest, 'Client', 'HytaleClient.exe'));
  } else if (process.platform === 'darwin') {
    // macOS
    candidates.push(path.join(gameLatest, 'Client', 'Hytale.app', 'Contents', 'MacOS', 'HytaleClient'));
    candidates.push(path.join(gameLatest, 'Client', 'HytaleClient'));
    candidates.push(path.join(gameLatest, 'Hytale.app', 'Contents', 'MacOS', 'HytaleClient'));
  } else {
    // Linux
    candidates.push(path.join(gameLatest, 'Client', 'HytaleClient'));
    candidates.push(path.join(gameLatest, 'HytaleClient'));
  }
  return candidates;
}

export function findUserDataPath(gameLatest: string): string | null {
  function searchDirectory(dir: string): string | null {
    try {
      const items = fs.readdirSync(dir, { withFileTypes: true });
      for (const item of items) {
        if (item.isDirectory()) {
          const fullPath = path.join(dir, item.name);
          if (item.name === 'UserData') {
            return fullPath;
          }
          // Limit recursion depth if needed, or rely on game structure being shallow enough
          const found = searchDirectory(fullPath);
          if (found) return found;
        }
      }
    } catch (error) {
      // Ignore access errors
    }
    return null;
  }

  if (!fs.existsSync(gameLatest)) {
    return null;
  }

  // First check common locations to avoid deep scan
  const candidates = [
    path.join(gameLatest, 'UserData'),
    path.join(gameLatest, 'Client', 'UserData')
  ];

  for (const candidate of candidates) {
    if (fs.existsSync(candidate)) return candidate;
  }

  return searchDirectory(gameLatest);
}

export function getGameModsPath(): string {
  // Try to find UserData
  const userData = findUserDataPath(GAME_DIR);
  if (userData) {
    return path.join(userData, 'Mods');
  }
  // Fallback if UserData not found (e.g. game not installed yet)
  return path.join(GAME_DIR, 'Client', 'UserData', 'Mods');
}

export function findClientPath(gameLatest: string) {
  const candidates = getClientCandidates(gameLatest);
  for (const candidate of candidates) {
    if (fs.existsSync(candidate)) {
      return candidate;
    }
  }
  return null;
}
