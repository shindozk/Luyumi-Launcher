import fs from 'fs';
import path from 'path';

/**
 * InstallationDetectionService - Detecta se game está realmente instalado
 * Implementação baseada no Hytale F2P
 * 
 * Verifica:
 * 1. Client executável existe
 * 2. Tamanho é válido (não corrompido)
 * 3. UserData directory pode ser criado
 * 4. Arquivo system permissions estão OK
 */
export class InstallationDetectionService {
  /**
   * Status detalhado da instalação do jogo
   */
  static async getDetailedGameStatus(gameDir: string): Promise<{
    installed: boolean;
    fullyExtracted: boolean;
    corrupted: boolean;
    clientPath: string | null;
    clientSize: number | null;
    installedVersion: string | null;
    issues: string[];
    details: {
      gameDir: string;
      hasClientDir: boolean;
      hasUserDataDir: boolean;
      hasClientExecutable: boolean;
      hasMetadataFile: boolean;
      diskSpace: number | null;
      timestamp: string;
    };
  }> {
    console.log(`[InstallationDetection] Checking game status at: ${gameDir}`);

    const result = {
      installed: false,
      fullyExtracted: false,
      corrupted: false,
      clientPath: null as string | null,
      clientSize: null as number | null,
      installedVersion: null as string | null,
      issues: [] as string[],
      details: {
        gameDir,
        hasClientDir: false,
        hasUserDataDir: false,
        hasClientExecutable: false,
        hasMetadataFile: false,
        diskSpace: null as number | null,
        timestamp: new Date().toISOString()
      }
    };

    // 1. Game directory existe?
    if (!fs.existsSync(gameDir)) {
      console.log(`[InstallationDetection] Game directory does not exist: ${gameDir}`);
      result.issues.push(`Game directory not found: ${gameDir}`);
      return result;
    }

    console.log(`[InstallationDetection] Game directory exists: ${gameDir}`);

    // 1.5 Check for metadata file
    try {
      const metadataPath = path.join(gameDir, 'luyumi_metadata.json');
      if (fs.existsSync(metadataPath)) {
        const metadataContent = await fs.promises.readFile(metadataPath, 'utf8');
        const metadata = JSON.parse(metadataContent);
        if (metadata && metadata.version) {
          result.installedVersion = metadata.version;
          result.details.hasMetadataFile = true;
          console.log(`[InstallationDetection] Found installed version: ${metadata.version}`);
        }
      }
    } catch (err) {
      console.warn(`[InstallationDetection] Failed to read metadata: ${err}`);
    }

    // 2. Client directory existe?
    const clientDir = path.join(gameDir, 'Client');
    result.details.hasClientDir = fs.existsSync(clientDir);
    if (!result.details.hasClientDir) {
      console.log(`[InstallationDetection] Client directory missing: ${clientDir}`);
      result.issues.push(`Client directory not found: ${clientDir}`);
    } else {
      console.log(`[InstallationDetection] Client directory found: ${clientDir}`);
    }

    // 3. UserData directory (pode não existir ainda)
    const userDataPath = path.join(clientDir, 'UserData');
    result.details.hasUserDataDir = fs.existsSync(userDataPath);
    console.log(`[InstallationDetection] UserData directory: ${result.details.hasUserDataDir ? 'exists' : 'not created yet'}`);

    // 4. Procurar client executável
    const clientPath = await this.findClientPath(gameDir);
    if (clientPath) {
      result.clientPath = clientPath;
      result.details.hasClientExecutable = true;

      try {
        const stats = await fs.promises.stat(clientPath);
        result.clientSize = stats.size;

        const sizeInMB = Math.round(stats.size / 1024 / 1024);
        console.log(`[InstallationDetection] Client found: ${clientPath} (${sizeInMB}MB)`);

        // 5. Validar tamanho do cliente (não muito pequeno = não corrompido)
        const MIN_CLIENT_SIZE = 20 * 1024 * 1024; // 20MB
        if (stats.size < MIN_CLIENT_SIZE) {
          result.corrupted = true;
          result.issues.push(
            `Client executable suspiciously small: ${sizeInMB}MB ` +
            `(expected at least ${Math.round(MIN_CLIENT_SIZE / 1024 / 1024)}MB). ` +
            'Game may be corrupted or incomplete.'
          );
          console.log(`[InstallationDetection] WARNING: Client size is suspicious!`);
        } else {
          result.fullyExtracted = true;
          result.installed = true;
          console.log(`[InstallationDetection] Client size is valid: ${sizeInMB}MB`);
        }

        // 6. Verificar permissões (pode executar?)
        try {
          await fs.promises.access(clientPath, fs.constants.X_OK);
          console.log(`[InstallationDetection] Client is executable`);
        } catch (err) {
          if (process.platform !== 'win32') {
            result.issues.push(`Client is not executable. May need: chmod +x ${clientPath}`);
            console.log(`[InstallationDetection] WARNING: Client not executable`);
          }
        }
      } catch (err) {
        result.issues.push(`Cannot stat client executable: ${err}`);
        console.log(`[InstallationDetection] ERROR: Cannot stat client: ${err}`);
      }
    } else {
      console.log(`[InstallationDetection] Client executable not found`);
      result.issues.push('Client executable not found in any expected location');
    }

    // 7. Espaço em disco disponível
    try {
      const stats = await fs.promises.statfs(gameDir);
      result.details.diskSpace = stats.bavail * stats.bsize; // bytes available
      const spaceInGB = Math.round((result.details.diskSpace / 1024 / 1024 / 1024) * 10) / 10;
      console.log(`[InstallationDetection] Available disk space: ${spaceInGB}GB`);
    } catch (err) {
      console.warn(`[InstallationDetection] Could not check disk space: ${err}`);
    }

    // 8. Resumo
    console.log(`[InstallationDetection] Status: ${
      result.fullyExtracted ? '✓ FULLY EXTRACTED' :
      result.installed ? '⚠ PARTIALLY INSTALLED' :
      result.corrupted ? '✗ CORRUPTED' :
      '✗ NOT INSTALLED'
    }`);

    if (result.issues.length > 0) {
      console.log(`[InstallationDetection] Issues found: ${result.issues.join('; ')}`);
    }

    return result;
  }

  /**
   * Verifica simples se está instalado (boolean)
   * Mais rápido que getDetailedGameStatus para polling
   */
  static async isGameInstalled(gameDir: string): Promise<boolean> {
    try {
      const clientPath = await this.findClientPath(gameDir);
      if (!clientPath) {
        return false;
      }

      const stats = await fs.promises.stat(clientPath);
      const MIN_SIZE = 20 * 1024 * 1024; // 20MB
      const isValid = stats.size >= MIN_SIZE;

      return isValid;
    } catch (err) {
      return false;
    }
  }

  /**
   * Procura client executável em todas as localizações possíveis
   */
  private static async findClientPath(gameDir: string): Promise<string | null> {
    const candidates = this.getClientCandidates(gameDir);

    for (const candidate of candidates) {
      try {
        if (fs.existsSync(candidate)) {
          const stats = await fs.promises.stat(candidate);
          if (stats.isFile()) {
            return candidate;
          }
        }
      } catch (err) {
        // Continue to next candidate
        console.log(`[InstallationDetection] Candidate not accessible: ${candidate}`);
      }
    }

    return null;
  }

  /**
   * Retorna possíveis localizações do executável por OS
   * Baseado no Hytale F2P - procura por HytaleClient em primeiro lugar
   */
  private static getClientCandidates(gameDir: string): string[] {
    const candidates: string[] = [];
    const platform = process.platform;

    // Windows - Procura por HytaleClient.exe em primeiro lugar
    if (platform === 'win32') {
      candidates.push(path.join(gameDir, 'Client', 'HytaleClient.exe'));
    }
    // macOS
    else if (platform === 'darwin') {
      candidates.push(path.join(gameDir, 'Client', 'Hytale.app', 'Contents', 'MacOS', 'HytaleClient'));
      candidates.push(path.join(gameDir, 'Client', 'HytaleClient'));
      candidates.push(path.join(gameDir, 'Hytale.app', 'Contents', 'MacOS', 'HytaleClient'));
    }
    // Linux
    else {
      candidates.push(path.join(gameDir, 'Client', 'HytaleClient'));
      candidates.push(path.join(gameDir, 'HytaleClient'));
    }

    return candidates;
  }

  /**
   * Detecta instalação anterior em custom path
   * Usado para "recuperar" instalações em outro disco/pasta
   */
  static async findPreviousInstallation(searchRoot: string): Promise<{
    found: boolean;
    gameDir: string | null;
    clientPath: string | null;
    hasUserData: boolean;
  }> {
    console.log(`[InstallationDetection] Searching for previous installation in: ${searchRoot}`);

    const result = {
      found: false,
      gameDir: null as string | null,
      clientPath: null as string | null,
      hasUserData: false
    };

    if (!fs.existsSync(searchRoot)) {
      return result;
    }

    try {
      const entries = await fs.promises.readdir(searchRoot, { withFileTypes: true });

      // Procura por estrutura 'release/package/game/latest'
      for (const entry of entries) {
        if (!entry.isDirectory()) continue;

        const releasePath = path.join(searchRoot, entry.name, 'release');
        const gamePath = path.join(releasePath, 'package', 'game', 'latest');

        if (fs.existsSync(gamePath)) {
          const clientPath = await this.findClientPath(gamePath);
          if (clientPath) {
            result.found = true;
            result.gameDir = gamePath;
            result.clientPath = clientPath;
            result.hasUserData = fs.existsSync(path.join(gamePath, 'Client', 'UserData'));

            console.log(
              `[InstallationDetection] Found previous installation at: ${gamePath} ` +
              `(has UserData: ${result.hasUserData})`
            );

            return result;
          }
        }
      }
    } catch (err) {
      console.warn(`[InstallationDetection] Error searching for installation: ${err}`);
    }

    console.log(`[InstallationDetection] No previous installation found`);
    return result;
  }

  /**
   * Detecta instalação corrompida que pode ser reparada
   */
  static async detectCorruptedInstallation(gameDir: string): Promise<{
    isCorrupted: boolean;
    canRepair: boolean;
    repairStrategy: 'reinstall' | 'restore-userdata' | 'full-recovery' | null;
    details: string[];
  }> {
    console.log(`[InstallationDetection] Checking for corruption at: ${gameDir}`);

    const result = {
      isCorrupted: false,
      canRepair: false,
      repairStrategy: null as 'reinstall' | 'restore-userdata' | 'full-recovery' | null,
      details: [] as string[]
    };

    const status = await this.getDetailedGameStatus(gameDir);

    if (!status.corrupted && status.fullyExtracted) {
      console.log(`[InstallationDetection] Installation appears intact`);
      return result;
    }

    result.isCorrupted = true;
    result.details = status.issues;

    // Tentar determinar estratégia de reparo
    const userDataPath = path.join(gameDir, 'Client', 'UserData');
    const hasUserData = fs.existsSync(userDataPath);

    if (status.clientSize && status.clientSize > 0 && status.clientSize < 20 * 1024 * 1024) {
      // Client é muito pequeno = precisa reinstalar
      result.repairStrategy = 'reinstall';
      result.canRepair = true;
      result.details.push('Client is corrupted. Strategy: Full reinstall');

      if (hasUserData) {
        result.details.push('UserData found and will be preserved during reinstall');
      }
    } else {
      // Game directory está vazio/corrompido
      result.repairStrategy = hasUserData ? 'restore-userdata' : 'full-recovery';
      result.canRepair = true;
      result.details.push(`Strategy: ${result.repairStrategy}`);
    }

    console.log(
      `[InstallationDetection] Corruption detected. ` +
      `Can repair: ${result.canRepair}. ` +
      `Strategy: ${result.repairStrategy}`
    );

    return result;
  }
}
