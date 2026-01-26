import fs from 'fs';
import path from 'path';
import crypto from 'node:crypto';
import { execFile } from 'node:child_process';
import { promisify } from 'util';
import AdmZip from 'adm-zip';
import tar from 'tar';
import { expandHome } from '../utils/paths';
import { getOS, getArch } from '../utils/platform';
import { downloadFile } from '../utils/file';

const execFileAsync = promisify(execFile);
const JAVA_EXECUTABLE = 'java' + (process.platform === 'win32' ? '.exe' : '');

export class JavaService {
    static async findJavaOnPath(commandName = 'java') {
        const lookupCmd = process.platform === 'win32' ? 'where' : 'which';
        try {
            const { stdout } = await execFileAsync(lookupCmd, [commandName]);
            const line = stdout.split(/\r?\n/).map(lineItem => lineItem.trim()).find(Boolean);
            return line || null;
        } catch (err) {
            return null;
        }
    }

    static async getMacJavaHome() {
        if (process.platform !== 'darwin') {
            return null;
        }
        try {
            const { stdout } = await execFileAsync('/usr/libexec/java_home');
            const home = stdout.trim();
            if (!home) {
                return null;
            }
            return path.join(home, 'bin', JAVA_EXECUTABLE);
        } catch (err) {
            return null;
        }
    }

    static async resolveJavaPath(inputPath: string | null | undefined) {
        const trimmed = (inputPath || '').trim();
        if (!trimmed) {
            return null;
        }

        const expanded = expandHome(trimmed);
        if (expanded && fs.existsSync(expanded)) {
            const stat = fs.statSync(expanded);
            if (stat.isDirectory()) {
                const candidate = path.join(expanded, 'bin', JAVA_EXECUTABLE);
                return fs.existsSync(candidate) ? candidate : null;
            }
            return expanded;
        }

        if (expanded && !path.isAbsolute(expanded)) {
            return await this.findJavaOnPath(trimmed);
        }

        return null;
    }

    static async detectSystemJava() {
        const envHome = process.env.JAVA_HOME;
        if (envHome) {
            const envJava = path.join(envHome, 'bin', JAVA_EXECUTABLE);
            if (fs.existsSync(envJava)) {
                return envJava;
            }
        }

        const macJava = await this.getMacJavaHome();
        if (macJava && fs.existsSync(macJava)) {
            return macJava;
        }

        const pathJava = await this.findJavaOnPath('java');
        if (pathJava && fs.existsSync(pathJava)) {
            return pathJava;
        }

        return null;
    }

    static getBundledJavaPath(jreDir: string) {
        const candidates = [
            path.join(jreDir, 'bin', JAVA_EXECUTABLE)
        ];

        if (process.platform === 'darwin') {
            candidates.push(path.join(jreDir, 'Contents', 'Home', 'bin', JAVA_EXECUTABLE));
        }

        for (const candidate of candidates) {
            if (fs.existsSync(candidate)) {
                return candidate;
            }
        }

        return null;
    }

    static async downloadJRE(
        cacheDir: string,
        jreDir: string,
        onProgress?: (state: { message: string; percent?: number }) => void
    ) {
        if (!fs.existsSync(cacheDir)) {
            fs.mkdirSync(cacheDir, { recursive: true });
        }

        const bundledJava = this.getBundledJavaPath(jreDir);
        if (bundledJava) {
            return;
        }

        onProgress?.({ message: 'Fetching Java runtime information...' });
        const response = await fetch('https://launcher.hytale.com/version/release/jre.json', {
            headers: {
                'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
                'Accept': 'application/json',
                'Accept-Language': 'en-US,en;q=0.9'
            }
        });

        if (!response.ok) {
            throw new Error(`Failed to fetch JRE metadata: ${response.statusText}`);
        }

        const jreData = await response.json() as any;
        const osName = getOS();
        const arch = getArch();
        const osData = jreData?.download_url?.[osName];
        if (!osData) {
            throw new Error(`Java runtime unavailable for platform: ${osName}`);
        }
        const platform = osData?.[arch];
        if (!platform) {
            throw new Error(`Java runtime unavailable for architecture ${arch} on ${osName}`);
        }

        const fileName = path.basename(platform.url);
        const cacheFile = path.join(cacheDir, fileName);

        if (!fs.existsSync(cacheFile)) {
            onProgress?.({ message: 'Downloading Java runtime...', percent: 0 });
            await downloadFile(platform.url, cacheFile, (downloaded, total) => {
                if (total > 0) {
                    const percent = Math.round((downloaded / total) * 100);
                    onProgress?.({ message: 'Downloading Java runtime...', percent });
                } else {
                    onProgress?.({ message: 'Downloading Java runtime...' });
                }
            });
        }

        onProgress?.({ message: 'Validating Java runtime...' });
        const fileBuffer = await fs.promises.readFile(cacheFile);
        const hashSum = crypto.createHash('sha256');
        hashSum.update(fileBuffer);
        const hex = hashSum.digest('hex');
        if (hex !== platform.sha256) {
            fs.unlinkSync(cacheFile);
            throw new Error(`File validation failed: expected ${platform.sha256} but got ${hex}`);
        }

        onProgress?.({ message: 'Unpacking Java runtime...' });
        await this.extractJRE(cacheFile, jreDir);

        if (process.platform !== 'win32') {
            const javaCandidates = [
                path.join(jreDir, 'bin', JAVA_EXECUTABLE),
                path.join(jreDir, 'Contents', 'Home', 'bin', JAVA_EXECUTABLE)
            ];
            for (const javaPath of javaCandidates) {
                if (fs.existsSync(javaPath)) {
                    fs.chmodSync(javaPath, 0o755);
                }
            }
        }

        this.flattenJREDir(jreDir);

        try {
            fs.unlinkSync(cacheFile);
        } catch (err) {
        }
    }

    private static async extractJRE(archivePath: string, destDir: string) {
        if (fs.existsSync(destDir)) {
            await fs.promises.rm(destDir, { recursive: true, force: true });
        }
        await fs.promises.mkdir(destDir, { recursive: true });

        if (archivePath.endsWith('.zip')) {
            return this.extractZip(archivePath, destDir);
        }
        if (archivePath.endsWith('.tar.gz')) {
            return this.extractTarGz(archivePath, destDir);
        }
        throw new Error(`Archive type not supported: ${archivePath}`);
    }

    private static extractZip(zipPath: string, dest: string) {
        const header = fs.readFileSync(zipPath, { encoding: null });
        if (header.length < 4 || header[0] !== 0x50 || header[1] !== 0x4b) {
            throw new Error(`Arquivo ZIP inválido: ${zipPath}`);
        }
        const zip = new AdmZip(zipPath);
        const entries = zip.getEntries();

        for (const entry of entries) {
            const entryPath = path.join(dest, entry.entryName);
            const resolvedPath = path.resolve(entryPath);
            const resolvedDest = path.resolve(dest);
            if (!resolvedPath.startsWith(resolvedDest)) {
                throw new Error(`Invalid file path detected: ${entryPath}`);
            }

            if (entry.isDirectory) {
                fs.mkdirSync(entryPath, { recursive: true });
            } else {
                fs.mkdirSync(path.dirname(entryPath), { recursive: true });
                fs.writeFileSync(entryPath, entry.getData());
                if (process.platform !== 'win32') {
                    fs.chmodSync(entryPath, entry.header.attr >>> 16);
                }
            }
        }
    }

    private static async extractTarGz(tarGzPath: string, dest: string) {
        return tar.extract({
            file: tarGzPath,
            cwd: dest,
            strip: 0
        });
    }

    private static flattenJREDir(jreLatest: string) {
        try {
            const entries = fs.readdirSync(jreLatest, { withFileTypes: true });
            if (entries.length !== 1 || !entries[0].isDirectory()) {
                return;
            }

            const nested = path.join(jreLatest, entries[0].name);
            const files = fs.readdirSync(nested, { withFileTypes: true });

            for (const file of files) {
                const oldPath = path.join(nested, file.name);
                const newPath = path.join(jreLatest, file.name);
                fs.renameSync(oldPath, newPath);
            }

            fs.rmSync(nested, { recursive: true, force: true });
        } catch (err) {
        }
    }
}
