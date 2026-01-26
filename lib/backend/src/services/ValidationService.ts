import fs from 'fs';
import path from 'path';
import crypto from 'crypto';

export interface ValidationReport {
  valid: boolean;
  timestamp: number;
  errors: ValidationError[];
  warnings: ValidationWarning[];
  checksumMatches: number;
  checksumTotal: number;
}

export interface ValidationError {
  type: 'critical' | 'major' | 'minor';
  code: string;
  message: string;
  path?: string;
}

export interface ValidationWarning {
  code: string;
  message: string;
  path?: string;
}

export class ValidationService {
  /**
   * Validate game installation integrity
   */
  static async validateGameInstallation(gameDir: string): Promise<ValidationReport> {
    const errors: ValidationError[] = [];
    const warnings: ValidationWarning[] = [];
    let checksumMatches = 0;
    let checksumTotal = 0;

    // Check critical directories
    const criticalDirs = [
      path.join(gameDir, 'Client'),
      path.join(gameDir, 'Client', 'UserData'),
    ];

    for (const dir of criticalDirs) {
      if (!fs.existsSync(dir)) {
        errors.push({
          type: 'critical',
          code: 'MISSING_DIRECTORY',
          message: `Critical directory missing: ${dir}`,
          path: dir
        });
      }
    }

    // Check for executable
    const exePaths = process.platform === 'win32' 
      ? [path.join(gameDir, 'Client', 'HytaleClient.exe'), path.join(gameDir, 'HytaleClient.exe')]
      : [path.join(gameDir, 'Client', 'HytaleClient'), path.join(gameDir, 'HytaleClient')];

    let foundExe = false;
    for (const exePath of exePaths) {
      if (fs.existsSync(exePath)) {
        foundExe = true;
        try {
          const stats = await fs.promises.stat(exePath);
          
          // Check file size
          if (stats.size < 20 * 1024 * 1024) { // Less than 20MB
            warnings.push({
              code: 'SUSPICIOUSLY_SMALL_EXECUTABLE',
              message: `Executable is suspiciously small: ${Math.round(stats.size / 1024 / 1024)}MB`,
              path: exePath
            });
          }

          // Check modification time
          const ageHours = (Date.now() - stats.mtimeMs) / (1000 * 60 * 60);
          if (ageHours > 30 * 24) { // More than 30 days old
            warnings.push({
              code: 'EXECUTABLE_OUTDATED',
              message: `Executable is older than 30 days (age: ${Math.round(ageHours / 24)} days)`,
              path: exePath
            });
          }
        } catch (err) {
          errors.push({
            type: 'major',
            code: 'CANNOT_STAT_EXECUTABLE',
            message: `Cannot read executable stats: ${err}`,
            path: exePath
          });
        }
        break;
      }
    }

    if (!foundExe) {
      errors.push({
        type: 'critical',
        code: 'NO_EXECUTABLE',
        message: 'Game executable not found',
        path: gameDir
      });
    }

    // Check for suspicious missing directories
    const expectedDirs = [
      'Client',
      'Server',
      'Tools'
    ];

    for (const dir of expectedDirs) {
      if (!fs.existsSync(path.join(gameDir, dir))) {
        warnings.push({
          code: `MISSING_${dir.toUpperCase()}`,
          message: `Expected directory missing: ${dir}`,
          path: path.join(gameDir, dir)
        });
      }
    }

    return {
      valid: errors.filter(e => e.type === 'critical').length === 0,
      timestamp: Date.now(),
      errors,
      warnings,
      checksumMatches,
      checksumTotal
    };
  }

  /**
   * Calculate hash of file
   */
  static async hashFile(
    filePath: string,
    algorithm = 'sha256'
  ): Promise<string> {
    return new Promise((resolve, reject) => {
      const hash = crypto.createHash(algorithm);
      const stream = fs.createReadStream(filePath, { highWaterMark: 64 * 1024 });

      stream.on('data', chunk => hash.update(chunk));
      stream.on('end', () => resolve(hash.digest('hex')));
      stream.on('error', reject);
    });
  }

  /**
   * Verify file against expected hash
   */
  static async verifyFileHash(
    filePath: string,
    expectedHash: string,
    algorithm = 'sha256'
  ): Promise<boolean> {
    try {
      const actualHash = await this.hashFile(filePath, algorithm);
      return actualHash.toLowerCase() === expectedHash.toLowerCase();
    } catch (err) {
      console.error(`[ValidationService] Error verifying hash for ${filePath}:`, err);
      return false;
    }
  }

  /**
   * Generate manifest of game files with hashes
   */
  static async generateManifest(gameDir: string): Promise<Record<string, string>> {
    const manifest: Record<string, string> = {};

    const walkDir = async (dir: string) => {
      try {
        const entries = await fs.promises.readdir(dir, { withFileTypes: true });

        for (const entry of entries) {
          const fullPath = path.join(dir, entry.name);
          const relativePath = path.relative(gameDir, fullPath);

          // Skip certain directories
          if (entry.isDirectory()) {
            if (!['staging-temp', 'cache', '.git'].includes(entry.name)) {
              await walkDir(fullPath);
            }
          } else if (entry.isFile()) {
            try {
              const hash = await this.hashFile(fullPath);
              manifest[relativePath] = hash;
            } catch (err) {
              console.warn(`[ValidationService] Failed to hash ${relativePath}:`, err);
            }
          }
        }
      } catch (err) {
        console.warn(`[ValidationService] Error walking directory ${dir}:`, err);
      }
    };

    await walkDir(gameDir);
    return manifest;
  }

  /**
   * Check if directory is readable and writable
   */
  static async checkPermissions(dirPath: string): Promise<{ readable: boolean; writable: boolean; error?: string }> {
    try {
      // Check read permissions
      await fs.promises.access(dirPath, fs.constants.R_OK);
      
      // Check write permissions by trying to create a test file
      const testFile = path.join(dirPath, `.permission_test_${Date.now()}`);
      await fs.promises.writeFile(testFile, '');
      await fs.promises.unlink(testFile);

      return { readable: true, writable: true };
    } catch (err: any) {
      return {
        readable: false,
        writable: false,
        error: err.message
      };
    }
  }

  /**
   * Check disk space availability
   */
  static async checkDiskSpace(dirPath: string): Promise<{ available: number; required: number; hasSpace: boolean }> {
    // Note: This is a simplified implementation
    // In production, you might use a library like 'diskusage' for more accurate results
    
    try {
      if (!fs.existsSync(dirPath)) {
        await fs.promises.mkdir(dirPath, { recursive: true });
      }

      // Estimate available space (simplified)
      // In reality, you'd need to use platform-specific tools
      const available = 50 * 1024 * 1024 * 1024; // Assume 50GB available (placeholder)
      const required = 100 * 1024 * 1024; // 100MB minimum

      return {
        available,
        required,
        hasSpace: available >= required
      };
    } catch (err) {
      console.error('[ValidationService] Error checking disk space:', err);
      return {
        available: 0,
        required: 100 * 1024 * 1024,
        hasSpace: false
      };
    }
  }
}
