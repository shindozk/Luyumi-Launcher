import fs from 'fs';
import path from 'path';
import { downloadFile, findHomePageUIPath, findLogoPath } from '../utils/file';

export class UIService {
    static async downloadAndReplaceHomePageUI(gameDir: string) {
        try {
            const homeUIUrl = 'https://files.hytalef2p.com/api/HomeUI';
            const tempHomePath = path.join(path.dirname(gameDir), 'HomePage_temp.ui');

            await downloadFile(homeUIUrl, tempHomePath);

            const existingHomePath = findHomePageUIPath(gameDir);

            if (existingHomePath && fs.existsSync(existingHomePath)) {
                const backupPath = existingHomePath + '.backup';
                if (!fs.existsSync(backupPath)) {
                    fs.copyFileSync(existingHomePath, backupPath);
                }
                fs.copyFileSync(tempHomePath, existingHomePath);
            }

            if (fs.existsSync(tempHomePath)) fs.unlinkSync(tempHomePath);
            return { success: true };
        } catch (error: any) {
            console.error('Error replacing HomePage.ui:', error);
            return { success: false, error: error.message };
        }
    }

    static async downloadAndReplaceLogo(gameDir: string) {
        try {
            const logoUrl = 'https://hytale.com/static/images/logo.png';
            const tempLogoPath = path.join(path.dirname(gameDir), 'Logo@2x_temp.png');

            await downloadFile(logoUrl, tempLogoPath);

            const existingLogoPath = findLogoPath(gameDir);

            if (existingLogoPath && fs.existsSync(existingLogoPath)) {
                const backupPath = existingLogoPath + '.backup';
                if (!fs.existsSync(backupPath)) {
                    fs.copyFileSync(existingLogoPath, backupPath);
                }
                // We are overwriting a likely PNG file with a WebP file content
                // If the game is strict about format matching extension, this might be an issue
                // But we follow user instruction to use this image.
                fs.copyFileSync(tempLogoPath, existingLogoPath);
            }

            if (fs.existsSync(tempLogoPath)) fs.unlinkSync(tempLogoPath);
            return { success: true };
        } catch (error: any) {
            console.error('Error replacing Logo:', error);
            return { success: false, error: error.message };
        }
    }
}
