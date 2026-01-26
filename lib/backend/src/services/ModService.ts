import fs from 'fs';
import path from 'path';
import crypto from 'crypto';
import { spawn } from 'child_process';
import { PROFILES_DIR } from '../utils/paths';
import { downloadFile } from '../utils/file';
import { ProfileService } from './ProfileService';
import { ModManager } from './ModManager';

export class ModService {
    // Helper to get mods from active profile
    static getProfileModsPath(profileId: string) {
        const profileDir = path.join(PROFILES_DIR, profileId);
        const modsDir = path.join(profileDir, 'mods');

        if (!fs.existsSync(modsDir)) {
            fs.mkdirSync(modsDir, { recursive: true });
        }

        return modsDir;
    }

    static generateModId(filename: string) {
        return crypto.createHash('md5').update(filename).digest('hex').substring(0, 8);
    }

    static extractModName(filename: string): string {
        let name = path.parse(filename).name;
        name = name.replace(/-v?\d+\.[\d\.]+.*$/i, '');
        name = name.replace(/-\d+\.[\d\.]+.*$/i, '');
        name = name.replace(/[-_]/g, ' ');
        name = name.replace(/\b\w/g, l => l.toUpperCase());
        return name || 'Unknown Mod';
    }

    static extractVersion(filename: string): string | null {
        const versionMatch = filename.match(/v?(\d+\.[\d\.]+)/);
        return versionMatch ? versionMatch[1] : null;
    }

    static async loadInstalledMods(profileId: string) {
        try {
            // 1. Get current profile config
            const profile = ProfileService.getProfiles()[profileId];
            if (!profile) return [];

            const configMods = profile.mods || [];
            
            const profileModsPath = this.getProfileModsPath(profileId);
            const profileDisabledModsPath = path.join(path.dirname(profileModsPath), 'DisabledMods');

            if (!fs.existsSync(profileModsPath)) fs.mkdirSync(profileModsPath, { recursive: true });
            if (!fs.existsSync(profileDisabledModsPath)) fs.mkdirSync(profileDisabledModsPath, { recursive: true });

            const finalMods: any[] = [];
            const processedFileNames = new Set<string>();

            // 2. Scan disk for current state
            const enabledFiles = fs.readdirSync(profileModsPath).filter(f => f.endsWith('.jar') || f.endsWith('.zip'));
            const disabledFiles = fs.readdirSync(profileDisabledModsPath).filter(f => f.endsWith('.jar') || f.endsWith('.zip'));

            const allFiles = [
                ...enabledFiles.map(f => ({ fileName: f, enabled: true, path: path.join(profileModsPath, f) })),
                ...disabledFiles.map(f => ({ fileName: f, enabled: false, path: path.join(profileDisabledModsPath, f) }))
            ];

            // 3. Process existing config mods
            for (const modConfig of configMods) {
                const fileOnDisk = allFiles.find(f => f.fileName === modConfig.fileName);
                
                if (fileOnDisk) {
                    // Found on disk - update status and path, keep metadata
                    finalMods.push({
                        ...modConfig,
                        enabled: fileOnDisk.enabled,
                        filePath: fileOnDisk.path,
                        missing: false
                    });
                    processedFileNames.add(modConfig.fileName);
                } else {
                    // Not found on disk -> Missing
                    finalMods.push({
                        ...modConfig,
                        filePath: null,
                        missing: true
                    });
                    // We treat missing mods as processed so we don't duplicate them
                    processedFileNames.add(modConfig.fileName);
                }
            }

            // 4. Add new files found on disk that weren't in config
            for (const file of allFiles) {
                if (!processedFileNames.has(file.fileName)) {
                    finalMods.push({
                        id: this.generateModId(file.fileName),
                        fileName: file.fileName,
                        name: this.extractModName(file.fileName),
                        version: this.extractVersion(file.fileName),
                        enabled: file.enabled,
                        filePath: file.path,
                        description: 'Locally installed mod',
                        author: 'Unknown',
                        dateInstalled: new Date().toISOString(),
                        missing: false,
                        manual: true // Flag to indicate manual installation
                    });
                }
            }

            return finalMods;
        } catch (error) {
            console.error('Failed to load mods:', error);
            return [];
        }
    }

    static async toggleMod(profileId: string, fileName: string, enable: boolean) {
        try {
            const profileModsPath = this.getProfileModsPath(profileId);
            const profileDisabledModsPath = path.join(path.dirname(profileModsPath), 'DisabledMods');

            const sourcePath = enable ? path.join(profileDisabledModsPath, fileName) : path.join(profileModsPath, fileName);
            const destPath = enable ? path.join(profileModsPath, fileName) : path.join(profileDisabledModsPath, fileName);

            // 1. Move file
            if (fs.existsSync(sourcePath)) {
                if (!fs.existsSync(path.dirname(destPath))) fs.mkdirSync(path.dirname(destPath), { recursive: true });
                fs.renameSync(sourcePath, destPath);
            } else if (fs.existsSync(destPath)) {
                // Already in target location
            } else {
                return false; // File not found anywhere
            }

            // 2. Update Config
            const profile = ProfileService.getProfiles()[profileId];
            if (profile) {
                const mods = await this.loadInstalledMods(profileId); // Reload to get fresh state including the move
                // Find the mod and force update its enabled state in case loadInstalledMods missed it (unlikely if moved)
                const modIndex = mods.findIndex((m: any) => m.fileName === fileName);
                if (modIndex !== -1) {
                    mods[modIndex].enabled = enable;
                    await ProfileService.updateProfile(profileId, { mods });
                }
            }
            
            // 3. Sync Symlink (Important for game to see changes)
            await ModManager.syncModsForProfile(profileId);

            return true;
        } catch (error) {
            console.error('Toggle mod failed:', error);
            return false;
        }
    }

    static async downloadMod(profileId: string, url: string, fileName: string, modInfo?: any) {
        try {
            const profileModsPath = this.getProfileModsPath(profileId);
            const destPath = path.join(profileModsPath, fileName);

            await downloadFile(url, destPath);

            // Update profile
            const profile = ProfileService.getProfiles()[profileId];
            if (profile) {
                // We manually construct the new mod entry to ensure metadata is captured
                // BEFORE calling loadInstalledMods which might just see a file
                const newMod = {
                    id: modInfo?.id || this.generateModId(fileName),
                    fileName: fileName,
                    name: modInfo?.name || this.extractModName(fileName),
                    version: modInfo?.version || this.extractVersion(fileName),
                    description: modInfo?.description || 'Downloaded Mod',
                    author: modInfo?.author || 'Unknown',
                    curseForgeId: modInfo?.curseForgeId,
                    curseForgeFileId: modInfo?.curseForgeFileId,
                    dateInstalled: new Date().toISOString(),
                    enabled: true,
                    missing: false
                };

                // Get current mods
                const currentMods = profile.mods || [];
                // Remove any existing entry for this filename
                const otherMods = currentMods.filter((m: any) => m.fileName !== fileName);
                
                // Save immediately
                await ProfileService.updateProfile(profileId, { mods: [...otherMods, newMod] });
            }

            // Sync Symlink
            await ModManager.syncModsForProfile(profileId);

            return { success: true, path: destPath };
        } catch (e: any) {
            console.error('Download mod failed:', e);
            return { success: false, error: e.message };
        }
    }

    static async uninstallMod(profileId: string, fileName: string) {
        const profileModsPath = this.getProfileModsPath(profileId);
        const profileDisabledModsPath = path.join(path.dirname(profileModsPath), 'DisabledMods');

        const enabledPath = path.join(profileModsPath, fileName);
        const disabledPath = path.join(profileDisabledModsPath, fileName);

        let deleted = false;
        if (fs.existsSync(enabledPath)) {
            fs.unlinkSync(enabledPath);
            deleted = true;
        } else if (fs.existsSync(disabledPath)) {
            fs.unlinkSync(disabledPath);
            deleted = true;
        }

        if (deleted) {
            // Remove from config
            const profile = ProfileService.getProfiles()[profileId];
            if (profile && profile.mods) {
                const updatedMods = profile.mods.filter((m: any) => m.fileName !== fileName);
                await ProfileService.updateProfile(profileId, { mods: updatedMods });
            }
            
            await ModManager.syncModsForProfile(profileId);
        }

        return deleted;
    }

    // Sync file system state to profile config
    static async syncProfileMods(profileId: string) {
        const mods = await this.loadInstalledMods(profileId);
        await ProfileService.updateProfile(profileId, { mods });

        // Also update the physical symlink to ensure game sees the changes
        await ModManager.syncModsForProfile(profileId);
    }

    static async syncSymlink(profileId: string) {
        return await ModManager.syncModsForProfile(profileId);
    }

    static openModsFolder(profileId: string) {
        const modsDir = this.getProfileModsPath(profileId);
        if (process.platform === 'win32') {
            spawn('explorer', [modsDir]);
        } else if (process.platform === 'darwin') {
            spawn('open', [modsDir]);
        } else {
            spawn('xdg-open', [modsDir]);
        }
        return true;
    }
}
