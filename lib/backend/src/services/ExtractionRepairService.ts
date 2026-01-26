import fs from 'fs';
import path from 'path';
import { ExtractionService } from './ExtractionService';
import { InstallationDetectionService } from './InstallationDetectionService';

/**
 * ExtractionRepairService - Repara instalações corrompidas ou incompletas
 * Baseado no sistema de repair do Hytale F2P
 * 
 * Estratégias:
 * 1. Backup UserData
 * 2. Remove game corrupto/incompleto
 * 3. Re-extrai PWR
 * 4. Restaura UserData
 */
export class ExtractionRepairService {
  /**
   * Repara game installation corrompida
   * @param gameDir - Directory do game corrompido
   * @param pwrFile - Caminho do arquivo PWR para re-extração
   * @param butlerPath - Caminho do butler
   * @param onProgress - Callback de progresso
   * @returns true se reparo bem-sucedido
   */
  static async repairGameInstallation(
    gameDir: string,
    pwrFile: string,
    butlerPath: string,
    onProgress?: (message: string, percent?: number) => void
  ): Promise<boolean> {
    console.log(`[ExtractionRepair] Starting repair of game at: ${gameDir}`);
    onProgress?.('Analyzing game installation...', 5);

    // 1. Detectar problema
    const corruptedStatus = await InstallationDetectionService.detectCorruptedInstallation(gameDir);
    if (!corruptedStatus.isCorrupted) {
      console.log(`[ExtractionRepair] Game is not corrupted, repair not needed`);
      onProgress?.('Game is not corrupted', 100);
      return true;
    }

    console.log(`[ExtractionRepair] Detected corruption: ${corruptedStatus.details.join('; ')}`);
    console.log(`[ExtractionRepair] Repair strategy: ${corruptedStatus.repairStrategy}`);

    let userDataBackup: string | null = null;

    try {
      // 2. Backup UserData antes de deletar tudo
      onProgress?.('Backing up user data...', 10);
      const userDataPath = path.join(gameDir, 'Client', 'UserData');
      if (fs.existsSync(userDataPath)) {
        userDataBackup = path.join(path.dirname(gameDir), `UserData_repair_backup_${Date.now()}`);
        console.log(`[ExtractionRepair] Backing up UserData from ${userDataPath} to ${userDataBackup}`);

        await this.copyRecursive(userDataPath, userDataBackup);
        console.log(`[ExtractionRepair] UserData backed up successfully`);
      }

      // 3. Remover game corrompido
      onProgress?.('Removing corrupted game files...', 20);
      console.log(`[ExtractionRepair] Removing corrupted game directory: ${gameDir}`);
      if (fs.existsSync(gameDir)) {
        await fs.promises.rm(gameDir, { recursive: true, force: true });
      }
      console.log(`[ExtractionRepair] Corrupted game directory removed`);

      // 4. Limpar cache para força re-download se necessário
      const cacheDir = path.join(path.dirname(gameDir), 'cache');
      if (fs.existsSync(cacheDir)) {
        onProgress?.('Clearing cache...', 25);
        console.log(`[ExtractionRepair] Clearing cache: ${cacheDir}`);
        await fs.promises.rm(cacheDir, { recursive: true, force: true });
      }

      // 5. Re-extrair PWR
      onProgress?.('Re-extracting game files...', 30);
      console.log(`[ExtractionRepair] Re-extracting PWR file: ${pwrFile}`);
      
      const extractionSuccess = await ExtractionService.extractPWR(
        pwrFile,
        gameDir,
        butlerPath,
        (message, percent) => {
          // Map 30-70% to extraction progress
          const mappedPercent = Math.round(30 + (percent || 0) * 0.4);
          onProgress?.(message, mappedPercent);
        }
      );

      if (!extractionSuccess) {
        throw new Error('Re-extraction failed');
      }

      // 6. Validar nova extração
      onProgress?.('Validating repaired installation...', 75);
      const validation = await ExtractionService.validateExtractedGame(gameDir);
      if (!validation.valid) {
        throw new Error(`Validation failed after repair: ${validation.issues.join(', ')}`);
      }
      console.log(`[ExtractionRepair] Repair validation passed`);

      // 7. Restaurar UserData
      if (userDataBackup && fs.existsSync(userDataBackup)) {
        onProgress?.('Restoring user data...', 85);
        const newUserDataPath = path.join(gameDir, 'Client', 'UserData');
        console.log(`[ExtractionRepair] Restoring UserData to ${newUserDataPath}`);

        if (!fs.existsSync(newUserDataPath)) {
          await fs.promises.mkdir(newUserDataPath, { recursive: true });
        }

        await this.copyRecursive(userDataBackup, newUserDataPath);
        console.log(`[ExtractionRepair] UserData restored successfully`);
      }

      // 8. Cleanup backup
      if (userDataBackup && fs.existsSync(userDataBackup)) {
        onProgress?.('Cleaning up...', 95);
        console.log(`[ExtractionRepair] Removing temporary backup: ${userDataBackup}`);
        await fs.promises.rm(userDataBackup, { recursive: true, force: true });
      }

      console.log(`[ExtractionRepair] Game repair completed successfully!`);
      onProgress?.('Repair completed successfully!', 100);
      return true;
    } catch (error: any) {
      console.error(`[ExtractionRepair] Repair failed: ${error.message}`);

      // Tentar cleanup mesmo com erro
      if (userDataBackup && fs.existsSync(userDataBackup)) {
        try {
          console.log(`[ExtractionRepair] Cleaning up backup after error...`);
          await fs.promises.rm(userDataBackup, { recursive: true, force: true });
        } catch (cleanupErr) {
          console.warn(`[ExtractionRepair] Could not cleanup backup: ${cleanupErr}`);
        }
      }

      throw new Error(`Game repair failed: ${error.message}`);
    }
  }

  /**
   * Copia directory recursivamente (helper)
   */
  private static async copyRecursive(src: string, dest: string): Promise<void> {
    const stat = await fs.promises.stat(src);
    if (stat.isDirectory()) {
      if (!fs.existsSync(dest)) {
        await fs.promises.mkdir(dest, { recursive: true });
      }
      const entries = await fs.promises.readdir(src, { withFileTypes: true });
      for (const entry of entries) {
        const srcPath = path.join(src, entry.name);
        const destPath = path.join(dest, entry.name);
        if (entry.isDirectory()) {
          await this.copyRecursive(srcPath, destPath);
        } else {
          await fs.promises.copyFile(srcPath, destPath);
        }
      }
    } else {
      await fs.promises.copyFile(src, dest);
    }
  }

  /**
   * Verifica se repair é seguro de fazer
   * (tem UserData backup, espaço em disco, etc)
   */
  static async isRepairSafe(gameDir: string): Promise<{ safe: boolean; warnings: string[] }> {
    console.log(`[ExtractionRepair] Checking if repair is safe for: ${gameDir}`);
    const warnings: string[] = [];

    // 1. Tem UserData para preserve?
    const userDataPath = path.join(gameDir, 'Client', 'UserData');
    if (!fs.existsSync(userDataPath)) {
      console.log(`[ExtractionRepair] No UserData found, repair is safe (no data to lose)`);
    } else {
      try {
        const stats = await fs.promises.stat(userDataPath);
        console.log(`[ExtractionRepair] UserData found: ${Math.round(stats.size / 1024 / 1024)}MB`);
      } catch (err) {
        warnings.push(`Cannot stat UserData: ${err}`);
      }
    }

    // 2. Tem espaço em disco?
    try {
      const stats = await fs.promises.statfs(gameDir);
      const freeSpace = stats.bavail * stats.bsize; // bytes
      const freeGb = freeSpace / 1024 / 1024 / 1024;
      
      const NEEDED_SPACE_GB = 15; // 15GB para extrair
      if (freeGb < NEEDED_SPACE_GB) {
        warnings.push(
          `Low disk space: ${Math.round(freeGb * 10) / 10}GB free ` +
          `(need at least ${NEEDED_SPACE_GB}GB for repair)`
        );
      } else {
        console.log(`[ExtractionRepair] Disk space OK: ${Math.round(freeGb * 10) / 10}GB free`);
      }
    } catch (err) {
      console.warn(`[ExtractionRepair] Could not check disk space: ${err}`);
    }

    // 3. Tem permissões de escrita?
    try {
      const testFile = path.join(gameDir, '.repair-test');
      await fs.promises.writeFile(testFile, 'test');
      await fs.promises.unlink(testFile);
      console.log(`[ExtractionRepair] Write permissions OK`);
    } catch (err) {
      warnings.push(`Cannot write to game directory: ${err}`);
    }

    const safe = warnings.length === 0;
    console.log(`[ExtractionRepair] Repair safety check: ${safe ? 'SAFE' : 'UNSAFE - ' + warnings.join('; ')}`);

    return { safe, warnings };
  }

  /**
   * Detecta tipo de corrupção e recomenda ação
   */
  static async detectAndRecommend(gameDir: string): Promise<{
    corrupted: boolean;
    type: 'not-corrupted' | 'missing-client' | 'corrupted-client' | 'incomplete-extraction' | 'unknown';
    recommendation: string;
    canAutoRepair: boolean;
  }> {
    console.log(`[ExtractionRepair] Detecting corruption type for: ${gameDir}`);

    const result: {
      corrupted: boolean;
      type: 'not-corrupted' | 'missing-client' | 'corrupted-client' | 'incomplete-extraction' | 'unknown';
      recommendation: string;
      canAutoRepair: boolean;
    } = {
      corrupted: false,
      type: 'not-corrupted',
      recommendation: 'Game appears to be installed correctly',
      canAutoRepair: false
    };

    // Verificar status detalhado
    const status = await InstallationDetectionService.getDetailedGameStatus(gameDir);

    if (!status.corrupted && status.fullyExtracted) {
      return result;
    }

    result.corrupted = true;

    // Diagnosticar tipo específico
    if (!status.details.hasClientExecutable) {
      result.type = 'missing-client';
      result.recommendation = 'Client executable not found. Game extraction may be incomplete. Recommend full repair (reinstall).';
      result.canAutoRepair = true;
    } else if (status.clientSize && status.clientSize < 50 * 1024 * 1024) {
      result.type = 'corrupted-client';
      result.recommendation = `Client executable is suspiciously small (${Math.round(status.clientSize / 1024 / 1024)}MB). Game files may be corrupted. Recommend full repair (reinstall).`;
      result.canAutoRepair = true;
    } else if (!status.details.hasClientDir) {
      result.type = 'incomplete-extraction';
      result.recommendation = 'Client directory structure incomplete. Recommend full repair (reinstall).';
      result.canAutoRepair = true;
    } else {
      result.type = 'unknown';
      result.recommendation = `Issues detected: ${status.issues.join('; ')}. Recommend full repair (reinstall).`;
      result.canAutoRepair = true;
    }

    console.log(`[ExtractionRepair] Detection result: ${result.type}`);
    console.log(`[ExtractionRepair] Recommendation: ${result.recommendation}`);
    console.log(`[ExtractionRepair] Can auto-repair: ${result.canAutoRepair}`);

    return result;
  }
}
