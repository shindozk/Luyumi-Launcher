import { join, dirname, resolve } from 'path';
import { existsSync, mkdirSync, lstatSync, readlinkSync, unlinkSync, readdirSync, renameSync, symlinkSync, rmSync, statSync } from 'fs';
import { platform } from 'os';
import { Mod } from '../types/Mod';
import { PROFILES_DIR, getGameModsPath } from '../utils/paths';

export class ModManager {
  
  static getProfileModsPath(profileId: string): string {
    const profileDir = join(PROFILES_DIR, profileId);
    const modsDir = join(profileDir, 'mods');
    if (!existsSync(modsDir)) {
      mkdirSync(modsDir, { recursive: true });
    }
    return modsDir;
  }

  static getGlobalModsPath(): string {
     // This is where the game looks for mods
     return getGameModsPath();
  }

  static async syncModsForProfile(profileId: string): Promise<{ success: boolean; error?: string }> {
    try {
      console.log(`[ModManager] Syncing mods for profile: ${profileId}`);

      const globalModsPath = this.getGlobalModsPath();
      const profileModsPath = this.getProfileModsPath(profileId);
      const profileDisabledModsPath = join(dirname(profileModsPath), 'DisabledMods');

      if (!existsSync(profileDisabledModsPath)) {
        mkdirSync(profileDisabledModsPath, { recursive: true });
      }

      // Symlink / Migration Logic
      let needsLink = false;

      if (existsSync(globalModsPath)) {
        const stats = lstatSync(globalModsPath);
        
        if (stats.isSymbolicLink()) {
          const linkTarget = readlinkSync(globalModsPath);
          // Normalize paths for comparison
          if (resolve(linkTarget) !== resolve(profileModsPath)) {
            console.log(`[ModManager] Updating symlink from ${linkTarget} to ${profileModsPath}`);
            unlinkSync(globalModsPath);
            needsLink = true;
          }
        } else if (stats.isDirectory()) {
          // MIGRATION: It's a real directory. Move contents to profile.
          console.log('[ModManager] Migrating global mods folder to profile folder...');
          const files = readdirSync(globalModsPath);
          for (const file of files) {
            const src = join(globalModsPath, file);
            const dest = join(profileModsPath, file);
            if (!existsSync(dest)) {
               renameSync(src, dest);
            }
          }
          
          // Also migrate DisabledMods if it exists globally
          const globalDisabledPath = join(dirname(globalModsPath), 'DisabledMods');
          if (existsSync(globalDisabledPath) && lstatSync(globalDisabledPath).isDirectory()) {
             const dFiles = readdirSync(globalDisabledPath);
             for (const file of dFiles) {
                 const src = join(globalDisabledPath, file);
                 const dest = join(profileDisabledModsPath, file);
                 if (!existsSync(dest)) {
                     renameSync(src, dest);
                 }
             }
             try { rmSync(globalDisabledPath, { recursive: true, force: true }); } catch(e) {} 
          }

          try {
              rmSync(globalModsPath, { recursive: true, force: true });
              needsLink = true;
          } catch (e) {
              console.error('Failed to remove global mods dir:', e);
              throw new Error('Failed to migrate mods directory.');
          }
        }
      } else {
        needsLink = true;
      }

      if (needsLink) {
        console.log(`[ModManager] Creating symlink: ${globalModsPath} -> ${profileModsPath}`);
        try {
           const type = platform() === 'win32' ? 'junction' : 'dir';
           symlinkSync(profileModsPath, globalModsPath, type); 
        } catch (err: any) {
          console.error('[ModManager] Failed to create symlink:', err);
          // Fallback: create dir
          if (!existsSync(globalModsPath)) {
             mkdirSync(globalModsPath, { recursive: true });
          }
        }
      }

      return { success: true };
    } catch (error: any) {
      console.error('[ModManager] Error syncing mods:', error);
      return { success: false, error: error.message };
    }
  }

  // TODO: Implement toggle, download, uninstall methods here that were in ModService
}
