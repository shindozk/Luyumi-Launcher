import fs from 'fs';
import path from 'path';
import { execFile } from 'child_process';
import { promisify } from 'util';

const execFileAsync = promisify(execFile);

/**
 * ExtractionService - Gerencia extração segura de arquivos PWR
 * Implementação baseada no Hytale F2P com:
 * - Staging directory para extrair sem corromper arquivos existentes
 * - Validação pré-extração (PWR exists, é readable, tamanho OK)
 * - Cleanup automático de directories temporários
 * - Detecção robusta de sucesso (client executable exists)
 */
export class ExtractionService {
  /**
   * Valida se arquivo PWR é válido antes de processar
   * @param pwrPath - Caminho do arquivo PWR
   * @returns true se válido, throws se inválido
   */
  static async validatePWRFile(pwrPath: string): Promise<boolean> {
    console.log(`[ExtractionService] Validating PWR file: ${pwrPath}`);

    // 1. Arquivo existe?
    if (!fs.existsSync(pwrPath)) {
      throw new Error(`PWR file not found: ${pwrPath}`);
    }

    // 2. É um arquivo (não diretório)?
    const stats = await fs.promises.stat(pwrPath);
    if (!stats.isFile()) {
      throw new Error(`PWR path is not a file: ${pwrPath}`);
    }

    // 3. Tamanho mínimo (PWR files devem ter pelo menos alguns MB)
    const minSize = 10 * 1024 * 1024; // 10MB minimum
    if (stats.size < minSize) {
      throw new Error(
        `PWR file suspiciously small: ${Math.round(stats.size / 1024 / 1024)}MB ` +
        `(expected at least ${Math.round(minSize / 1024 / 1024)}MB). ` +
        `File may be corrupted or incomplete.`
      );
    }

    // 4. É readable?
    try {
      await fs.promises.access(pwrPath, fs.constants.R_OK);
    } catch (err) {
      throw new Error(`PWR file is not readable: ${pwrPath}`);
    }

    console.log(`[ExtractionService] PWR validation passed. Size: ${Math.round(stats.size / 1024 / 1024)}MB`);
    return true;
  }

  /**
   * Extrai PWR usando Butler em directory temporário (staging)
   * Implementação segura que não corrompe game directory existente se falhar
   * 
   * @param pwrFile - Caminho do arquivo PWR validado
   * @param targetDir - Directory onde game será colocado após extração bem-sucedida
   * @param butlerPath - Caminho do executável butler
   * @param onProgress - Callback para progresso: (message, percent) => void
   * @returns true se extração bem-sucedida
   */
  static async extractPWR(
    pwrFile: string,
    targetDir: string,
    butlerPath: string,
    onProgress?: (message: string, percent?: number) => void
  ): Promise<boolean> {
    console.log(`[ExtractionService] Starting extraction of ${pwrFile} to ${targetDir}`);

    // Validar PWR antes de fazer qualquer coisa
    await this.validatePWRFile(pwrFile);

    // Validar butler existe
    if (!fs.existsSync(butlerPath)) {
      throw new Error(`Butler not found at: ${butlerPath}`);
    }

    const stagingDir = path.join(targetDir, 'staging-temp');
    let stagingCleanedUp = false;

    try {
      // 1. Preparar staging directory (limpar se existir)
      onProgress?.('Preparing staging directory...', 10);
      console.log(`[ExtractionService] Preparing staging dir: ${stagingDir}`);

      if (fs.existsSync(stagingDir)) {
        console.log(`[ExtractionService] Removing existing staging directory...`);
        await fs.promises.rm(stagingDir, { recursive: true, force: true });
      }
      await fs.promises.mkdir(stagingDir, { recursive: true });
      console.log(`[ExtractionService] Staging directory ready`);

      // 2. Verificar se game já está instalado no target
      // Se sim, skip (não precisa re-extrair)
      const existingClient = await this.findClientPath(targetDir);
      if (existingClient && fs.existsSync(existingClient)) {
        console.log(`[ExtractionService] Game already installed at ${targetDir}, skipping extraction`);
        onProgress?.('Game already installed, skipping extraction', 100);

        // Cleanup staging anyway
        if (fs.existsSync(stagingDir)) {
          await fs.promises.rm(stagingDir, { recursive: true, force: true });
          stagingCleanedUp = true;
        }

        return true;
      }

      // 3. Criar target directory se não existir
      if (!fs.existsSync(targetDir)) {
        console.log(`[ExtractionService] Creating target directory: ${targetDir}`);
        await fs.promises.mkdir(targetDir, { recursive: true });
      }

      // 4. Executar butler apply
      onProgress?.('Extracting game files...', 30);
      console.log(`[ExtractionService] Running butler with:`);
      console.log(`  - Butler: ${butlerPath}`);
      console.log(`  - PWR: ${pwrFile}`);
      console.log(`  - Staging: ${stagingDir}`);
      console.log(`  - Target: ${targetDir}`);

      const { stdout, stderr } = await execFileAsync(butlerPath, [
        'apply',
        '--staging-dir',
        stagingDir,
        pwrFile,
        targetDir
      ], {
        maxBuffer: 10 * 1024 * 1024, // 10MB buffer
        timeout: 10 * 60 * 1000 // 10 minutos timeout
      });

      console.log(`[ExtractionService] Butler stdout: ${stdout}`);
      if (stderr) {
        console.log(`[ExtractionService] Butler stderr: ${stderr}`);
      }

      // 5. Validar que extração foi bem-sucedida
      onProgress?.('Validating extraction...', 80);
      const extractedClient = await this.findClientPath(targetDir);
      if (!extractedClient) {
        throw new Error(
          'Extraction completed but client executable not found in target directory. ' +
          'This may indicate a corrupt PWR file or incomplete extraction.'
        );
      }

      const clientStats = await fs.promises.stat(extractedClient);
      if (clientStats.size < 20 * 1024 * 1024) { // 20MB minimum for game executable
        throw new Error(
          `Client executable suspiciously small: ${Math.round(clientStats.size / 1024 / 1024)}MB. ` +
          'Extraction may have failed or PWR file may be corrupt.'
        );
      }

      console.log(
        `[ExtractionService] Extraction validated successfully. ` +
        `Client found: ${extractedClient} (${Math.round(clientStats.size / 1024 / 1024)}MB)`
      );

      onProgress?.('Extraction completed successfully', 95);
      return true;
    } catch (error: any) {
      console.error(`[ExtractionService] Extraction failed: ${error.message}`);

      // Não deixar game directory quebrado
      if (fs.existsSync(targetDir) && !stagingCleanedUp) {
        try {
          const dir = await fs.promises.readdir(targetDir);
          // Se só tem staging, está seguro remover
          if (dir.length === 1 && dir[0] === 'staging-temp') {
            console.log(`[ExtractionService] Removing incomplete extraction from target...`);
            await fs.promises.rm(targetDir, { recursive: true, force: true });
          }
        } catch (cleanupErr) {
          console.warn(`[ExtractionService] Error during cleanup: ${cleanupErr}`);
        }
      }

      throw new Error(`Extraction failed: ${error.message}`);
    } finally {
      // SEMPRE cleanup staging directory mesmo se falhou
      if (fs.existsSync(stagingDir)) {
        try {
          console.log(`[ExtractionService] Cleaning up staging directory: ${stagingDir}`);
          await fs.promises.rm(stagingDir, { recursive: true, force: true });
        } catch (cleanupErr) {
          console.warn(`[ExtractionService] Warning: Could not cleanup staging directory: ${cleanupErr}`);
        }
      }
    }
  }

  /**
   * Procura por client executável em possíveis localizações
   * Retorna null se não encontrado
   */
  private static async findClientPath(gameDir: string): Promise<string | null> {
    const candidates = this.getClientCandidates(gameDir);

    for (const candidate of candidates) {
      if (fs.existsSync(candidate)) {
        try {
          const stats = await fs.promises.stat(candidate);
          if (stats.isFile()) {
            console.log(`[ExtractionService] Found client at: ${candidate}`);
            return candidate;
          }
        } catch (err) {
          console.warn(`[ExtractionService] Client candidate exists but not readable: ${candidate}`);
        }
      }
    }

    console.log(`[ExtractionService] Client not found in any candidate location`);
    return null;
  }

  /**
   * Retorna possíveis localizações do client executável por OS
   * Baseado no Hytale F2P - procura por HytaleClient ou similar em diferentes localizações
   */
  private static getClientCandidates(gameDir: string): string[] {
    const candidates: string[] = [];
    const platform = process.platform;

    // Windows - Procura por HytaleClient.exe
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
   * Verifica integridade de game directory após extração
   * @param gameDir - Directory do game extraído
   * @returns { valid: boolean, issues: string[] }
   */
  static async validateExtractedGame(gameDir: string): Promise<{ valid: boolean; issues: string[] }> {
    console.log(`[ExtractionService] Validating extracted game at: ${gameDir}`);
    const issues: string[] = [];

    // 1. Directory existe?
    if (!fs.existsSync(gameDir)) {
      return {
        valid: false,
        issues: [`Game directory does not exist: ${gameDir}`]
      };
    }

    // 2. Client executável existe e é válido?
    const clientPath = await this.findClientPath(gameDir);
    if (!clientPath) {
      issues.push('Client executable not found in game directory');
    } else {
      try {
        const stats = await fs.promises.stat(clientPath);
        if (stats.size < 20 * 1024 * 1024) {
          issues.push(
            `Client executable suspiciously small: ${Math.round(stats.size / 1024 / 1024)}MB ` +
            '(expected at least 20MB). Game may be corrupted.'
          );
        }
      } catch (err) {
        issues.push(`Cannot stat client executable: ${err}`);
      }
    }

    // 3. Client directory existe?
    const clientDir = path.join(gameDir, 'Client');
    if (!fs.existsSync(clientDir)) {
      issues.push(`Client directory missing: ${clientDir}`);
    }

    // 4. UserData pode ser criado?
    const userDataPath = path.join(clientDir, 'UserData');
    if (!fs.existsSync(userDataPath)) {
      try {
        await fs.promises.mkdir(userDataPath, { recursive: true });
        await fs.promises.rm(userDataPath, { recursive: true, force: true });
        console.log(`[ExtractionService] UserData directory will be created on first run`);
      } catch (err) {
        issues.push(`Cannot create UserData directory: ${err}`);
      }
    }

    const valid = issues.length === 0;
    console.log(`[ExtractionService] Validation result: ${valid ? 'VALID' : 'INVALID - ' + issues.join(', ')}`);

    return {
      valid,
      issues
    };
  }

  /**
   * Detecta se game está realmente instalado (não só se directory existe)
   * @param gameDir - Directory potencial do game
   * @returns true se client executável existe e parece válido
   */
  static async isGameFullyExtracted(gameDir: string): Promise<boolean> {
    if (!fs.existsSync(gameDir)) {
      return false;
    }

    try {
      const clientPath = await this.findClientPath(gameDir);
      if (!clientPath) {
        return false;
      }

      const stats = await fs.promises.stat(clientPath);
      const isValidSize = stats.size >= 50 * 1024 * 1024; // 50MB minimum

      console.log(
        `[ExtractionService] Game fully extracted check: ${isValidSize ? 'YES' : 'NO'} ` +
        `(client size: ${Math.round(stats.size / 1024 / 1024)}MB)`
      );

      return isValidSize;
    } catch (err) {
      console.log(`[ExtractionService] Game fully extracted check: NO (error: ${err})`);
      return false;
    }
  }

  /**
   * Remove directory extraído completamente (para repair/reinstall)
   */
  static async removeExtractedGame(gameDir: string): Promise<void> {
    if (fs.existsSync(gameDir)) {
      console.log(`[ExtractionService] Removing extracted game from: ${gameDir}`);
      await fs.promises.rm(gameDir, { recursive: true, force: true });
      console.log(`[ExtractionService] Game directory removed`);
    }
  }
}
