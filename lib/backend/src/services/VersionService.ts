import { getOS, getArch } from '../utils/platform';

export class VersionService {
    private static readonly PATCH_ROOT_URL = 'https://game-patches.hytale.com/patches';

    // Endpoint used by Hytale F2P to get the latest client version
    private static readonly VERSION_ENDPOINT = 'https://files.hytalef2p.com/api/version_client';

    static async getLatestVersion() {
        try {
            console.log('[VersionService] Fetching latest client version from API...');
            const response = await fetch(this.VERSION_ENDPOINT);
            if (!response.ok) {
                console.warn(`[VersionService] Failed to fetch version: ${response.statusText}`);
                return "4.pwr";
            }
            const data = await response.json() as any;

            if (data && data.client_version) {
                console.log(`[VersionService] Remote version: ${data.client_version}`);
                return data.client_version;
            }
            return "4.pwr";
        } catch (error) {
            console.error(`[VersionService] Error fetching version:`, error);
            return "4.pwr";
        }
    }

    static getPatchUrl(version: string, channel: string = 'release') {
        const osName = getOS(); // 'windows', 'darwin', 'linux'
        const arch = getArch(); // 'amd64', 'arm64'
        const fileName = version.endsWith('.pwr') ? version : `${version}.pwr`;

        return `${this.PATCH_ROOT_URL}/${osName}/${arch}/${channel}/0/${fileName}`;
    }

    static isUpdateAvailable(currentVersion: string | null, latestVersion: string): boolean {
        if (!currentVersion) return true;
        return currentVersion !== latestVersion;
    }
}
