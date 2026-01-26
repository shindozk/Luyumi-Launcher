import { v4 as uuidv4 } from 'uuid';
import { ConfigService } from './ConfigService';

export class ProfileService {
    static init() {
        const config = ConfigService.loadConfig();
        if (!config.profiles || Object.keys(config.profiles).length === 0) {
            this.migrateLegacyConfig(config);
        }
    }

    static migrateLegacyConfig(config: any) {
        const defaultProfileId = 'default';
        const now = new Date().toISOString();
        const defaultProfile = {
            id: defaultProfileId,
            name: 'Default',
            created: now,
            lastUsed: now,
            mods: config.installedMods || [],
            javaPath: config.javaPath || '',
            gameOptions: {
                minMemory: '1G',
                maxMemory: '4G',
                args: []
            }
        };

        ConfigService.saveConfig({
            profiles: { [defaultProfileId]: defaultProfile },
            activeProfileId: defaultProfileId
        });
    }

    static createProfile(name: string) {
        const id = uuidv4();
        const newProfile = {
            id,
            name,
            created: new Date().toISOString(),
            lastUsed: null,
            mods: [],
            javaPath: '',
            gameOptions: {
                minMemory: '1G',
                maxMemory: '4G',
                args: []
            }
        };
        
        const config = ConfigService.loadConfig();
        const profiles = config.profiles || {};
        profiles[id] = newProfile;
        
        ConfigService.saveConfig({ profiles });
        return newProfile;
    }

    static updateProfile(profileId: string, updates: any) {
        const config = ConfigService.loadConfig();
        const profiles = config.profiles || {};
        
        if (profiles[profileId]) {
            profiles[profileId] = { ...profiles[profileId], ...updates };
            ConfigService.saveConfig({ profiles });
            return profiles[profileId];
        }
        return null;
    }

    static getProfiles() {
        const config = ConfigService.loadConfig();
        return config.profiles || {};
    }

    static getActiveProfile() {
        const config = ConfigService.loadConfig();
        const activeId = config.activeProfileId || 'default';
        return config.profiles?.[activeId] || null;
    }
}
