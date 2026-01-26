import fs from 'fs';
import path from 'path';
import { APP_DIR } from '../utils/paths';

export class ConfigService {
    private static configFile = path.join(APP_DIR, 'config.json');

    static loadConfig(): any {
        try {
            if (fs.existsSync(this.configFile)) {
                return JSON.parse(fs.readFileSync(this.configFile, 'utf8'));
            }
        } catch (err) {
            console.error('Error loading config:', err);
        }
        return {};
    }

    static saveConfig(update: any) {
        try {
            const configDir = path.dirname(this.configFile);
            if (!fs.existsSync(configDir)) {
                fs.mkdirSync(configDir, { recursive: true });
            }
            const config = this.loadConfig();
            const next = { ...config, ...update };
            fs.writeFileSync(this.configFile, JSON.stringify(next, null, 2), 'utf8');
        } catch (err) {
            console.error('Error saving config:', err);
        }
    }

    static getAuthDomain(): string {
        const config = this.loadConfig();
        return config.authDomain || process.env.HYTALE_AUTH_DOMAIN || 'sanasol.ws';
    }
}
