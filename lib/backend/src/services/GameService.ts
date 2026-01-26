import fs from 'fs';
import path from 'path';
import { spawn, exec, ChildProcess } from 'node:child_process';
import { ButlerService } from './ButlerService';
import { JavaService } from './JavaService';
import { clientPatcher } from './PatcherService';
import { UIService } from './UIService';
import { VersionService } from './VersionService';
import { ModManager } from './ModManager';
import { DownloadService } from './DownloadService';
import { ExtractionService } from './ExtractionService';
import { InstallationDetectionService } from './InstallationDetectionService';
import { findClientPath, getResolvedAppDir } from '../utils/paths';
import { setupWaylandEnvironment, setupGpuEnvironment } from '../utils/platform';

interface LaunchOptions {
    playerName: string;
    uuid: string;
    identityToken: string;
    sessionToken: string;
    javaPath?: string;
    gameDir?: string;
    width?: number;
    height?: number;
    fullscreen?: boolean;
    server?: string; // Auto-connect to server
    profileId?: string;
    gpuPreference?: string;
}

export class GameService {
    static installProgress = {
        percent: 0,
        message: '',
        status: 'idle' as 'idle' | 'installing' | 'completed' | 'error'
    };

    private static gameStartTime: number | null = null;

    static getGameStartTime() {
        return this.gameStartTime;
    }

    private static setProgressState(
        percent: number,
        message: string,
        status: 'idle' | 'installing' | 'completed' | 'error'
    ) {
        this.installProgress = {
            ...this.installProgress,
            percent,
            message,
            status
        };
    }

    private static updateProgress(percent: number, message: string) {
        this.setProgressState(percent, message, 'installing');
    }

    private static resolvePaths() {
        const appDir = getResolvedAppDir();
        const cacheDir = path.join(appDir, 'cache');
        const toolsDir = path.join(appDir, 'butler');
        const gameDir = path.join(appDir, 'install', 'release', 'package', 'game', 'latest');
        const jreDir = path.join(appDir, 'install', 'release', 'package', 'jre', 'latest');
        return { appDir, cacheDir, toolsDir, gameDir, jreDir };
    }

    private static resolveUserDataDir(gameDir: string) {
        const candidates = [
            path.join(gameDir, 'Client', 'UserData'),
            path.join(gameDir, 'userData'),
            path.join(gameDir, 'UserData')
        ];
        for (const candidate of candidates) {
            if (fs.existsSync(candidate)) {
                return candidate;
            }
        }
        return candidates[0];
    }

    private static async ensureDir(dirPath: string) {
        await fs.promises.mkdir(dirPath, { recursive: true });
    }

    private static async copyDirectory(source: string, destination: string) {
        await fs.promises.mkdir(destination, { recursive: true });
        const entries = await fs.promises.readdir(source, { withFileTypes: true });
        for (const entry of entries) {
            const srcPath = path.join(source, entry.name);
            const destPath = path.join(destination, entry.name);
            if (entry.isDirectory()) {
                await this.copyDirectory(srcPath, destPath);
            } else {
                await fs.promises.copyFile(srcPath, destPath);
            }
        }
    }


    private static async downloadPatch(
        version: string,
        cacheDir: string,
        channel = 'release',
        progressRange?: { start: number; end: number }
    ) {
        await this.ensureDir(cacheDir);
        const url = VersionService.getPatchUrl(version, channel);
        console.log(`[GameService] Downloading patch from: ${url}`);
        const rangeStart = progressRange?.start ?? 0;
        const rangeEnd = progressRange?.end ?? 100;
        const rangeSpan = Math.max(0, rangeEnd - rangeStart);
        this.updateProgress(rangeStart, 'Downloading patch...');
        
        const fileName = path.basename(url);
        const dest = path.join(cacheDir, fileName);
        if (!fs.existsSync(dest)) {
            console.log(`[GameService] Cache miss, downloading to ${dest}`);
            // Use DownloadService with retry and resume support
            const result = await DownloadService.downloadFile(url, dest, {
                maxRetries: 3,
                timeout: 60000,
                resumable: true,
                onProgress: (downloaded, total, percent) => {
                    const rangedPercent = rangeStart + (percent / 100) * rangeSpan;
                    this.updateProgress(
                        Math.round(rangedPercent),
                        `Downloading patch: ${Math.round(downloaded / 1024 / 1024)}MB / ${Math.round(total / 1024 / 1024)}MB`
                    );
                }
            });
            console.log(`[GameService] Download complete. Size: ${result.size} bytes, Hash: ${result.hash}`);
        } else {
            console.log(`[GameService] Using cached patch: ${dest}`);
            this.updateProgress(rangeEnd, 'Using cached patch');
        }

        // Clean up old patches
        await this.cleanupOldPatches(path.basename(dest), cacheDir);
        
        // Clean up any partial downloads
        await DownloadService.cleanupTempFiles(cacheDir);

        return dest;
    }

    private static async cleanupOldPatches(keepVersion: string, cacheDir: string) {
        try {
            console.log(`[GameService] Cleaning up old patches in ${cacheDir}, keeping ${keepVersion}...`);
            const files = await fs.promises.readdir(cacheDir);
            for (const file of files) {
                if (file.endsWith('.pwr') && !file.includes(keepVersion)) {
                    console.log(`[GameService] Deleting old patch: ${file}`);
                    await fs.promises.unlink(path.join(cacheDir, file));
                }
            }
        } catch (err) {
            console.error('[GameService] Error cleaning up cache:', err);
        }
    }

    static async applyPatch(
        pwrFile: string,
        targetDir: string,
        toolsDir: string,
        progressRange?: { start: number; end: number }
    ) {
        console.log(`[GameService] Applying patch ${pwrFile} to ${targetDir}`);
        const rangeStart = progressRange?.start ?? 0;
        const rangeEnd = progressRange?.end ?? 100;
        this.updateProgress(rangeStart, 'Preparing to apply patch...');
        
        try {
            // Use novo ExtractionService para validação e extração
            await this.ensureDir(targetDir);
            await this.ensureDir(toolsDir);
            
            const butlerPath = await ButlerService.installButler(toolsDir);
            console.log(`[GameService] Butler installed at ${butlerPath}`);

            // ExtractionService valida PWR, executa butler, limpa staging
            const extractionSuccess = await ExtractionService.extractPWR(
                pwrFile,
                targetDir,
                butlerPath,
                (message, percent) => {
                    const rangeSpan = rangeEnd - rangeStart;
                    const rangedPercent = Math.round(rangeStart + (percent || 0) * (rangeSpan / 100));
                    this.updateProgress(rangedPercent, message);
                }
            );

            if (!extractionSuccess) {
                throw new Error('Extraction reported failure');
            }

            // Validar que extração foi bem-sucedida
            const validation = await ExtractionService.validateExtractedGame(targetDir);
            if (!validation.valid) {
                throw new Error(`Validation failed after extraction: ${validation.issues.join(', ')}`);
            }

            console.log(`[GameService] Patch applied and validated successfully.`);
            this.updateProgress(rangeEnd, 'Patch applied successfully');
        } catch (err: any) {
            console.error(`[GameService] Patch application failed: ${err.message}`);
            this.installProgress.status = 'error';
            throw err;
        }
    }

    static async isGameRunning(): Promise<boolean> {
        const processNames = ['HytaleClient.exe', 'HytaleClient'];
        
        return new Promise((resolve) => {
            if (process.platform === 'win32') {
                exec('tasklist /FO CSV /NH', (err, stdout) => {
                    if (err) {
                        this.gameStartTime = null;
                        resolve(false);
                        return;
                    }
                    const running = processNames.some(name => stdout.toLowerCase().includes(`"${name.toLowerCase()}"`));
                    if (!running) this.gameStartTime = null;
                    resolve(running);
                });
            } else {
                exec('ps -A -o comm=', (err, stdout) => {
                    if (err) {
                        this.gameStartTime = null;
                        resolve(false);
                        return;
                    }
                    const running = processNames.some(name => stdout.includes(name));
                    if (!running) this.gameStartTime = null;
                    resolve(running);
                });
            }
        });
    }

    static async getGameStatus() {
        const { gameDir } = this.resolvePaths();
        try {
            console.log(`[GameService] Getting game status from: ${gameDir}`);
            const latestVersion = await VersionService.getLatestVersion();
            
            // Use novo detection service para status detalhado
            const detailedStatus = await InstallationDetectionService.getDetailedGameStatus(gameDir);
            
            const installedVersion = detailedStatus.installedVersion;
            const updateAvailable = VersionService.isUpdateAvailable(installedVersion, latestVersion);

            return {
                installed: detailedStatus.installed,
                fullyExtracted: detailedStatus.fullyExtracted,
                corrupted: detailedStatus.corrupted,
                clientPath: detailedStatus.clientPath,
                clientSize: detailedStatus.clientSize,
                reasons: detailedStatus.issues,
                gameDir,
                latestVersion,
                installedVersion,
                updateAvailable,
                details: detailedStatus.details
            };
        } catch (err: any) {
            console.error(`[GameService] Error getting game status: ${err.message}`);
            return {
                installed: false,
                fullyExtracted: false,
                corrupted: false,
                reasons: [err.message],
                latestVersion: '0.1.0-release',
                installedVersion: null,
                updateAvailable: false
            };
        }
    }

    static async uninstallGame() {
        const { gameDir } = this.resolvePaths();
        console.log(`[GameService] Uninstalling game from: ${gameDir}`);
        if (fs.existsSync(gameDir)) {
            await fs.promises.rm(gameDir, { recursive: true, force: true });
            console.log(`[GameService] Game uninstalled successfully`);
            return true;
        }
        console.log(`[GameService] Game directory not found, nothing to uninstall`);
        return false;
    }

    private static async saveVersionMetadata(gameDir: string, version: string) {
        try {
            const metadataPath = path.join(gameDir, 'luyumi_metadata.json');
            const metadata = {
                version,
                installedAt: new Date().toISOString(),
                launcherVersion: '1.0.0' // Placeholder
            };
            await fs.promises.writeFile(metadataPath, JSON.stringify(metadata, null, 2), 'utf8');
            console.log(`[GameService] Saved version metadata: ${version}`);
        } catch (err) {
            console.error(`[GameService] Failed to save version metadata: ${err}`);
        }
    }

    static async installGame(version?: string) {
        const { gameDir, cacheDir, toolsDir, jreDir } = this.resolvePaths();
        console.log(`[GameService] installGame called. Target: ${gameDir}`);
        this.setProgressState(0, 'Starting installation...', 'installing');

        // Use novo detection service para verificar se já está instalado
        const isAlreadyInstalled = await InstallationDetectionService.isGameInstalled(gameDir);
        if (isAlreadyInstalled) {
            console.log(`[GameService] Game already installed at ${gameDir}`);
            this.setProgressState(100, 'Game already installed', 'completed');
            return { success: true, alreadyInstalled: true, gameDir };
        }

        try {
            const targetVersion = version || (await VersionService.getLatestVersion());
            console.log(`[GameService] Installing version: ${targetVersion}`);

            this.updateProgress(10, 'Downloading game files...');
            const pwrFile = await this.downloadPatch(
                targetVersion,
                cacheDir,
                'release',
                { start: 10, end: 50 }
            );

            this.updateProgress(50, 'Extracting game files...');
            await this.applyPatch(pwrFile, gameDir, toolsDir, { start: 50, end: 90 });
            
            // Delete .pwr file after extraction
            try {
                console.log(`[GameService] Deleting PWR file after extraction: ${pwrFile}`);
            // Save version metadata
            await this.saveVersionMetadata(gameDir, targetVersion);

                await fs.promises.unlink(pwrFile);
            } catch (cleanupErr) {
                console.warn(`[GameService] Failed to delete PWR file: ${cleanupErr}`);
            }

            // Ensure Java is ready
            this.updateProgress(95, 'Checking Java runtime...');
            await JavaService.downloadJRE(cacheDir, jreDir, (state) => {
                this.updateProgress(95, `Checking Java: ${state.message}`);
            });

            // Install default UI
            await UIService.downloadAndReplaceHomePageUI(gameDir);
            await UIService.downloadAndReplaceLogo(gameDir);

            this.setProgressState(100, 'Installation completed', 'completed');
            return { success: true, gameDir };
        } catch (err: any) {
            const message = err?.message || 'Installation failed';
            console.error(`[GameService] Install error: ${message}`, err);
            this.setProgressState(0, message, 'error');
            throw err;
        }
    }

    static async updateGame(version?: string) {
        const { gameDir, cacheDir, toolsDir } = this.resolvePaths();
        console.log(`[GameService] updateGame called. Target: ${gameDir}`);
        this.setProgressState(0, 'Starting update...', 'installing');

        if (!fs.existsSync(gameDir)) {
            throw new Error('Game not installed. Cannot update.');
        }

        let tempDir: string | null = null;
        let backupPath: string | null = null;

        try {
            const targetVersion = version || (await VersionService.getLatestVersion());
            console.log(`[GameService] Updating to version: ${targetVersion}`);

            // Create temp directory for update
            tempDir = path.join(path.dirname(gameDir), `update_temp_${Date.now()}`);
            await this.ensureDir(tempDir);

            // Backup user data
            const userDataPath = this.resolveUserDataDir(gameDir);
            if (fs.existsSync(userDataPath)) {
                this.updateProgress(5, 'Backing up user data...');
                backupPath = path.join(path.dirname(gameDir), `UserData_backup_${Date.now()}`);
                await this.copyDirectory(userDataPath, backupPath);
            }

            // Download and extract to temp dir
            this.updateProgress(10, 'Downloading update...');
            const pwrFile = await this.downloadPatch(
                targetVersion,
                cacheDir,
                'release',
                { start: 10, end: 50 }
            );

            this.updateProgress(50, 'Extracting update...');
            await this.applyPatch(pwrFile, tempDir, toolsDir, { start: 50, end: 75 });
            
            // Delete .pwr file after extraction
            try {
                console.log(`[GameService] Deleting PWR file after extraction: ${pwrFile}`);
                await fs.promises.unlink(pwrFile);
            } catch (cleanupErr) {
                console.warn(`[GameService] Failed to delete PWR file: ${cleanupErr}`);
            }

            // Validate temp directory has valid client
            this.updateProgress(78, 'Validating update...');
            const newClientPath = findClientPath(tempDir);
            if (!newClientPath) {
                throw new Error('Updated game files are invalid or incomplete');
            }

            // Replace game files
            this.updateProgress(80, 'Replacing game files...');
            const oldGameDir = path.join(path.dirname(gameDir), `game_backup_${Date.now()}`);
            await fs.promises.rename(gameDir, oldGameDir);
            console.log(`[GameService] Old game backed up to: ${oldGameDir}`);

            await fs.promises.rename(tempDir, gameDir);
            console.log(`[GameService] New game files moved to: ${gameDir}`);
            tempDir = null; // Mark as handled

            // Restore user data
            if (backupPath && fs.existsSync(backupPath)) {
                this.updateProgress(86, 'Restoring user data...');
                const newUserData = this.resolveUserDataDir(gameDir);
                await this.copyDirectory(backupPath, newUserData);
                console.log(`[GameService] User data restored successfully`);
            }

            // Clean up old backup
            if (fs.existsSync(oldGameDir)) {
                try {
                    this.updateProgress(90, 'Cleaning up old files...');
                    await fs.promises.rm(oldGameDir, { recursive: true, force: true });
                    console.log(`[GameService] Old game backup cleaned up`);
                } catch (err) {
                    console.warn(`[GameService] Failed to cleanup old game backup: ${err}`);
                }
            }

            this.updateProgress(95, 'Updating UI...');
            await UIService.downloadAndReplaceHomePageUI(gameDir);
            await UIService.downloadAndReplaceLogo(gameDir);

            // Save version metadata
            await this.saveVersionMetadata(gameDir, targetVersion);

            this.setProgressState(100, 'Update completed', 'completed');
            return { success: true, version: targetVersion, gameDir };
        } catch (err: any) {
            const message = err?.message || 'Update failed';
            console.error(`[GameService] Update error: ${message}`, err);
            this.setProgressState(0, message, 'error');

            // Attempt rollback
            if (tempDir && fs.existsSync(tempDir)) {
                try {
                    console.log(`[GameService] Cleaning up temporary update directory: ${tempDir}`);
                    await fs.promises.rm(tempDir, { recursive: true, force: true });
                } catch (cleanupErr) {
                    console.warn(`[GameService] Failed to cleanup temp directory: ${cleanupErr}`);
                }
            }

            throw err;
        } finally {
            // Clean up backup if update succeeded
            if (backupPath && fs.existsSync(backupPath)) {
                try {
                    await fs.promises.rm(backupPath, { recursive: true, force: true });
                    console.log(`[GameService] Backup cleaned up: ${backupPath}`);
                } catch (err) {
                    console.warn(`[GameService] Failed to cleanup backup: ${err}`);
                }
            }
        }
    }

    static async repairGame(version?: string) {
        const { gameDir } = this.resolvePaths();
        this.setProgressState(0, 'Starting repair...', 'installing');
        if (!fs.existsSync(gameDir)) {
            this.setProgressState(0, 'Game not installed', 'error');
            throw new Error('Game not installed');
        }
        try {
            const userDataPath = this.resolveUserDataDir(gameDir);
            let backupPath: string | null = null;
            if (fs.existsSync(userDataPath)) {
                this.updateProgress(10, 'Backing up user data...');
                backupPath = path.join(path.dirname(gameDir), `UserData_repair_${Date.now()}`);
                await this.copyDirectory(userDataPath, backupPath);
            }
            this.updateProgress(20, 'Reinstalling game files...');
            await fs.promises.rm(gameDir, { recursive: true, force: true });
            const result = await this.installGame(version);
            if (backupPath) {
                this.updateProgress(90, 'Restoring user data...');
                const newUserData = this.resolveUserDataDir(gameDir);
                await this.copyDirectory(backupPath, newUserData);
                await fs.promises.rm(backupPath, { recursive: true, force: true });
            }
            this.setProgressState(100, 'Repair completed', 'completed');
            return result;
        } catch (err: any) {
            const message = err?.message || 'Repair failed';
            this.setProgressState(0, message, 'error');
            throw err;
        }
    }

    static async getLatestLogContent() {
        const { appDir } = this.resolvePaths();
        const logDir = path.join(appDir, 'logs');
        
        if (!fs.existsSync(logDir)) {
            return '';
        }

        try {
            const files = await fs.promises.readdir(logDir);
            const logFiles = files
                .filter(f => f.startsWith('game-session-') && f.endsWith('.log'))
                .map(f => ({
                    name: f,
                    time: fs.statSync(path.join(logDir, f)).mtime.getTime()
                }))
                .sort((a, b) => b.time - a.time);

            if (logFiles.length === 0) {
                return '';
            }

            const latestLog = path.join(logDir, logFiles[0].name);
            return await fs.promises.readFile(latestLog, 'utf8');
        } catch (err) {
            console.error('[GameService] Error reading logs:', err);
            return '';
        }
    }

    static async launchGameWithFallback(options: LaunchOptions): Promise<ChildProcess> {
        if (!options.fullscreen) {
            return this.launchGame(options);
        }

        console.log('[GameService] Attempting robust fullscreen launch...');

        const gameDir = options.gameDir || this.resolvePaths().gameDir;
        await this.applyFullscreenPreference(gameDir, true);
        const child = await this.launchGame(options);

        return new Promise<ChildProcess>((resolve, reject) => {
            let resolved = false;
            const startTime = Date.now();

            const timeout = setTimeout(() => {
                if (resolved) return;
                resolved = true;
                child.off('exit', exitHandler);
                resolve(child);
            }, 5000);

            const exitHandler = async () => {
                if (resolved) return;
                resolved = true;
                clearTimeout(timeout);

                const elapsed = Date.now() - startTime;
                if (elapsed < 5000) {
                    try {
                        await this.applyFullscreenPreference(gameDir, false);
                        const fallbackOptions = { ...options, fullscreen: false };
                        const fallbackChild = await this.launchGame(fallbackOptions);
                        resolve(fallbackChild);
                    } catch (err) {
                        reject(err);
                    }
                    return;
                }

                resolve(child);
            };

            child.on('exit', exitHandler);
        });
    }

    private static async applyFullscreenPreference(gameDir: string, fullscreen: boolean) {
        const userDataDir = path.join(gameDir, 'Client', 'UserData');
        await this.ensureDir(userDataDir);
        const settingsPath = path.join(userDataDir, 'Settings.json');
        let settings: Record<string, any> = {};

        if (fs.existsSync(settingsPath)) {
            try {
                settings = JSON.parse(await fs.promises.readFile(settingsPath, 'utf8'));
            } catch (err) {
                settings = {};
            }
        }

        settings['FormatVersion'] = settings['FormatVersion'] ?? 5;
        settings['Fullscreen'] = fullscreen;
        settings['Maximized'] = fullscreen;
        settings['WindowWidth'] = settings['WindowWidth'] ?? 1280;
        settings['WindowHeight'] = settings['WindowHeight'] ?? 720;

        await fs.promises.writeFile(settingsPath, JSON.stringify(settings, null, 2), 'utf8');
    }

    static async launchGame(options: LaunchOptions) {
        console.log('[GameService] Launching game with options:', JSON.stringify({ ...options, identityToken: '***', sessionToken: '***' }));
        
        const gameDir = options.gameDir || this.resolvePaths().gameDir;
        const clientPath = findClientPath(gameDir);

        if (!clientPath) {
            throw new Error(`Game executable not found at ${gameDir}`);
        }

        // 1. Resolve Java
        let javaBin = options.javaPath;
        if (!javaBin) {
            const { jreDir } = this.resolvePaths();
            const bundled = JavaService.getBundledJavaPath(jreDir);
            if (bundled) {
                javaBin = bundled;
            } else {
                javaBin = await JavaService.detectSystemJava() || undefined;
            }
        }

        if (javaBin && !fs.existsSync(javaBin)) {
             console.warn(`[GameService] Provided Java path does not exist: ${javaBin}`);
             javaBin = undefined;
        }

        if (!javaBin) {
            console.warn('[GameService] Java runtime not found, launching without --java-exec. This may cause issues if the game requires Java.');
        } else {
            console.log(`[GameService] Using Java: ${javaBin}`);
        }

        // 2. Patch Client
        try {
            console.log('[GameService] Ensuring client is patched...');
            await clientPatcher.ensureClientPatched(gameDir);
        } catch (e) {
            console.error('[GameService] Failed to patch client:', e);
            // We continue as it might be already patched or the error might be non-fatal
        }

        // 3. Sync Mods (if profile selected)
        if (options.profileId) {
            try {
                console.log(`[GameService] Syncing mods for profile: ${options.profileId}`);
                await ModManager.syncModsForProfile(options.profileId);
            } catch (e) {
                console.error('[GameService] Failed to sync mods:', e);
            }
        }

        // 4. Construct Args
        const userDataDir = path.join(gameDir, 'Client', 'UserData');
        await this.ensureDir(userDataDir);

        // Define log directory
        const logDir = path.join(this.resolvePaths().appDir, 'logs');
        await this.ensureDir(logDir);
        const logFile = path.join(logDir, `game-session-${Date.now()}.log`);
        const logStream = fs.createWriteStream(logFile, { flags: 'a' });
        
        console.log(`[GameService] Game logs will be written to: ${logFile}`);
        logStream.write(`[LAUNCH] Timestamp: ${new Date().toISOString()}\n`);
        logStream.write(`[LAUNCH] Options: ${JSON.stringify({ ...options, identityToken: '***', sessionToken: '***' })}\n`);

        const args: string[] = [];

        // Hytale F2P Argument Order:
        // 1. --app-dir
        // 2. --java-exec (if available)
        // 3. --auth-mode
        // 4. ... others

        args.push('--app-dir', gameDir);
        
        if (javaBin) {
            args.push('--java-exec', javaBin);
        }

        args.push('--auth-mode', 'authenticated');
        args.push('--uuid', options.uuid);
        args.push('--name', options.playerName);
        args.push('--identity-token', options.identityToken);
        args.push('--session-token', options.sessionToken);
        args.push('--user-dir', userDataDir);

        if (options.width && options.height) {
            args.push('--width', options.width.toString());
            args.push('--height', options.height.toString());
        }


        if (options.server) {
            args.push('--server', options.server);
        }

        // 5. Environment
        const env = { ...process.env };
        Object.assign(env, setupWaylandEnvironment());
        Object.assign(env, setupGpuEnvironment(options.gpuPreference)); // Auto-detect GPU settings like Hytale F2P
        
        // Ensure JAVA_HOME is set if we are using a specific Java
        if (javaBin) {
            const javaHome = path.dirname(path.dirname(javaBin));
            env['JAVA_HOME'] = javaHome;
            // Also update PATH to include this Java's bin
            const pathSeparator = process.platform === 'win32' ? ';' : ':';
            env['PATH'] = `${path.dirname(javaBin)}${pathSeparator}${env['PATH'] || ''}`;
        }

        console.log(`[GameService] Executing: ${clientPath}`);
        logStream.write(`[LAUNCH] Command: ${clientPath} ${args.join(' ')}\n`);

        const spawnOptions: any = {
            stdio: ['ignore', 'pipe', 'pipe'], // Capture stdout/stderr
            detached: true,
            env: env,
            cwd: path.dirname(clientPath) // Run from the client's directory
        };

        if (process.platform === 'win32') {
            spawnOptions.shell = false;
            spawnOptions.windowsHide = true;
        }

        try {
            const child = spawn(clientPath, args, spawnOptions);

            if (!child.pid) {
                throw new Error('Failed to spawn game process (no PID returned)');
            }

            this.gameStartTime = Date.now();
            console.log(`[GameService] Game process started with PID: ${child.pid}`);
            logStream.write(`[LAUNCH] PID: ${child.pid}\n`);

            child.stdout?.on('data', (data) => {
                const str = data.toString();
                // Log to backend stdout so frontend can pick it up via BackendManager
                process.stdout.write(`[GAME STDOUT] ${str}`); 
                logStream.write(`[STDOUT] ${str}`);
            });

            child.stderr?.on('data', (data) => {
                const str = data.toString();
                console.error(`[Game Error] ${str.trim()}`);
                logStream.write(`[STDERR] ${str}`);
            });

            child.on('close', (code) => {
                console.log(`[GameService] Game process exited with code ${code}`);
                logStream.write(`[EXIT] Code: ${code}\n`);
                logStream.end();
            });

            child.on('error', (err) => {
                console.error(`[GameService] Process error: ${err.message}`);
                logStream.write(`[ERROR] ${err.message}\n`);
                logStream.end();
            });

            child.unref();

            return child;
        } catch (err: any) {
            console.error(`[GameService] Exception during spawn: ${err.message}`);
            logStream.write(`[CRITICAL] Exception during spawn: ${err.message}\n`);
            logStream.end();
            throw err;
        }
    }
}