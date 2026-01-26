import fs from 'fs';
import path from 'path';
import AdmZip from 'adm-zip';
import { TOOLS_DIR } from '../utils/paths';
import { getOS, getArch } from '../utils/platform';
import { downloadFile } from '../utils/file';

export class ButlerService {
    static async installButler(toolsDir = TOOLS_DIR) {
        if (!fs.existsSync(toolsDir)) {
            fs.mkdirSync(toolsDir, { recursive: true });
        }

        const butlerName = process.platform === 'win32' ? 'butler.exe' : 'butler';
        const butlerPath = path.join(toolsDir, butlerName);
        const zipPath = path.join(toolsDir, 'butler.zip');

        if (fs.existsSync(butlerPath)) {
            return butlerPath;
        }

        let urls: string[] = [];
        const osName = getOS();
        const arch = getArch();

        if (osName === 'windows') {
            urls = ['https://broth.itch.zone/butler/windows-amd64/LATEST/archive/default'];
        } else if (osName === 'darwin') {
            if (arch === 'arm64') {
                urls = [
                    'https://broth.itch.zone/butler/darwin-arm64/LATEST/archive/default',
                    'https://broth.itch.zone/butler/darwin-amd64/LATEST/archive/default'
                ];
            } else {
                urls = ['https://broth.itch.zone/butler/darwin-amd64/LATEST/archive/default'];
            }
        } else if (osName === 'linux') {
            urls = ['https://broth.itch.zone/butler/linux-amd64/LATEST/archive/default'];
        } else {
            throw new Error('Operating system not supported');
        }

        console.log('Fetching Butler tool...');
        let lastError: unknown = null;
        for (const url of urls) {
            try {
                await downloadFile(url, zipPath);
                lastError = null;
                break;
            } catch (e) {
                lastError = e;
            }
        }

        if (lastError || !fs.existsSync(zipPath)) {
            throw new Error('Failed to download Butler');
        }

        const header = fs.readFileSync(zipPath, { encoding: null });
        if (header.length < 4 || header[0] !== 0x50 || header[1] !== 0x4b) {
            try {
                fs.unlinkSync(zipPath);
            } catch (e) {}
            throw new Error(`Butler archive inválido: ${zipPath}`);
        }

        console.log('Unpacking Butler...');
        const zip = new AdmZip(zipPath);
        zip.extractAllTo(toolsDir, true);
        
        if (process.platform !== 'win32') {
            fs.chmodSync(butlerPath, 0o755);
        }
        
        try {
            fs.unlinkSync(zipPath);
        } catch (e) {}

        return butlerPath;
    }
}
