import fs from 'fs';
import path from 'path';
import { createWriteStream } from 'fs';
import crypto from 'crypto';

export interface DownloadOptions {
  maxRetries?: number;
  timeout?: number;
  chunkSize?: number;
  resumable?: boolean;
  onProgress?: (downloaded: number, total: number, percent: number) => void;
  onChunk?: (chunk: Buffer) => void;
}

export interface DownloadResult {
  success: boolean;
  path: string;
  size: number;
  hash?: string;
  resumed?: boolean;
}

export class DownloadService {
  private static readonly DEFAULT_TIMEOUT = 30000;
  private static readonly DEFAULT_CHUNK_SIZE = 1024 * 1024; // 1MB
  private static readonly DEFAULT_MAX_RETRIES = 3;

  /**
   * Download a file with automatic retry and resume support
   */
  static async downloadFile(
    url: string,
    destPath: string,
    options: DownloadOptions = {}
  ): Promise<DownloadResult> {
    const {
      maxRetries = this.DEFAULT_MAX_RETRIES,
      timeout = this.DEFAULT_TIMEOUT,
      resumable = true,
      onProgress,
      onChunk
    } = options;

    // Ensure destination directory exists
    const destDir = path.dirname(destPath);
    if (!fs.existsSync(destDir)) {
      await fs.promises.mkdir(destDir, { recursive: true });
    }

    let lastError: Error | null = null;
    let attempt = 0;

    while (attempt <= maxRetries) {
      try {
        attempt++;
        console.log(`[DownloadService] Attempt ${attempt}/${maxRetries + 1} - Downloading: ${url}`);

        const result = await this._downloadFileInternal(
          url,
          destPath,
          timeout,
          resumable,
          onProgress,
          onChunk
        );

        console.log(`[DownloadService] Download successful: ${destPath}`);
        return result;
      } catch (err) {
        lastError = err as Error;
        console.warn(`[DownloadService] Attempt ${attempt} failed: ${lastError.message}`);

        if (attempt <= maxRetries) {
          const delay = Math.min(1000 * Math.pow(2, attempt - 1), 10000); // Exponential backoff
          console.log(`[DownloadService] Retrying in ${delay}ms...`);
          await new Promise(resolve => setTimeout(resolve, delay));
        }
      }
    }

    throw lastError || new Error('Download failed after maximum retries');
  }

  /**
   * Internal download logic with resume support
   */
  private static async _downloadFileInternal(
    url: string,
    destPath: string,
    timeout: number,
    resumable: boolean,
    onProgress?: (downloaded: number, total: number, percent: number) => void,
    onChunk?: (chunk: Buffer) => void
  ): Promise<DownloadResult> {
    const tempPath = `${destPath}.tmp`;
    let downloadedSize = 0;
    let totalSize = 0;
    let resumed = false;

    // Check if partial download exists
    if (resumable && fs.existsSync(tempPath)) {
      const stats = await fs.promises.stat(tempPath);
      downloadedSize = stats.size;
      resumed = true;
      console.log(`[DownloadService] Resuming from ${downloadedSize} bytes`);
    }

    // Create abort controller for timeout
    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), timeout);

    try {
      // Fetch with Range header if resuming
      const headers: Record<string, string> = {};
      if (resumed && downloadedSize > 0) {
        headers['Range'] = `bytes=${downloadedSize}-`;
      }

      const response = await fetch(url, {
        headers,
        signal: controller.signal as any
      });

      clearTimeout(timeoutId);

      if (!response.ok) {
        throw new Error(`HTTP ${response.status}: ${response.statusText}`);
      }

      // Get total size from response
      const contentLength = response.headers.get('content-length');
      const contentRange = response.headers.get('content-range');

      if (contentRange) {
        // Parse "bytes start-end/total"
        const match = contentRange.match(/bytes \d+-\d+\/(\d+)/);
        totalSize = match ? parseInt(match[1], 10) : 0;
      } else if (contentLength) {
        totalSize = parseInt(contentLength, 10);
        if (resumed && downloadedSize > 0) {
          totalSize += downloadedSize;
        }
      }

      if (!totalSize) {
        console.warn('[DownloadService] Could not determine file size from response headers');
      }

      // Open file for writing (append if resuming)
      const writeStream = createWriteStream(tempPath, {
        flags: resumed ? 'a' : 'w'
      });

      const body = response.body;
      if (!body) {
        throw new Error('No response body');
      }

      let currentDownloaded = downloadedSize;

      // Create readable stream from fetch body
      const reader = body.getReader();
      const decoder = new TextDecoder();

      try {
        while (true) {
          const { done, value } = await reader.read();

          if (done) break;

          const chunk = Buffer.from(value);
          currentDownloaded += chunk.length;

          writeStream.write(chunk);
          if (onChunk) {
            onChunk(chunk);
          }

          if (totalSize > 0 && onProgress) {
            const percent = Math.round((currentDownloaded / totalSize) * 100);
            onProgress(currentDownloaded, totalSize, percent);
          }
        }
      } finally {
        reader.releaseLock();
      }

      return new Promise((resolve, reject) => {
        writeStream.on('finish', async () => {
          try {
            // Rename temp file to final destination
            if (fs.existsSync(destPath)) {
              await fs.promises.unlink(destPath);
            }
            await fs.promises.rename(tempPath, destPath);

            // Verify file
            const stats = await fs.promises.stat(destPath);
            const hash = await this._hashFile(destPath);

            resolve({
              success: true,
              path: destPath,
              size: stats.size,
              hash,
              resumed
            });
          } catch (err) {
            reject(err);
          }
        });

        writeStream.on('error', (err) => {
          reject(err);
        });

        writeStream.end();
      });
    } catch (err: any) {
      clearTimeout(timeoutId);

      // Clean up temp file on error (unless it's a resumable error)
      if (fs.existsSync(tempPath) && !resumable) {
        try {
          await fs.promises.unlink(tempPath);
        } catch (e) {
          console.warn('[DownloadService] Failed to clean up temp file:', e);
        }
      }

      throw err;
    }
  }

  /**
   * Calculate SHA256 hash of file
   */
  private static async _hashFile(filePath: string, algorithm = 'sha256'): Promise<string> {
    return new Promise((resolve, reject) => {
      const hash = crypto.createHash(algorithm);
      const stream = fs.createReadStream(filePath);

      stream.on('data', (chunk) => hash.update(chunk));
      stream.on('end', () => resolve(hash.digest('hex')));
      stream.on('error', reject);
    });
  }

  /**
   * Verify file integrity using hash
   */
  static async verifyFile(
    filePath: string,
    expectedHash: string,
    algorithm = 'sha256'
  ): Promise<boolean> {
    try {
      const hash = await this._hashFile(filePath, algorithm);
      const match = hash.toLowerCase() === expectedHash.toLowerCase();

      if (!match) {
        console.warn(
          `[DownloadService] Hash mismatch for ${filePath}: expected ${expectedHash}, got ${hash}`
        );
      }

      return match;
    } catch (err) {
      console.error('[DownloadService] Error verifying file:', err);
      return false;
    }
  }

  /**
   * Clean up partial downloads
   */
  static async cleanupTempFiles(directory: string): Promise<number> {
    let cleaned = 0;

    try {
      const files = await fs.promises.readdir(directory);

      for (const file of files) {
        if (file.endsWith('.tmp')) {
          const filePath = path.join(directory, file);
          try {
            await fs.promises.unlink(filePath);
            cleaned++;
            console.log(`[DownloadService] Cleaned up: ${file}`);
          } catch (err) {
            console.warn(`[DownloadService] Failed to cleanup ${file}:`, err);
          }
        }
      }
    } catch (err) {
      console.warn('[DownloadService] Error reading directory for cleanup:', err);
    }

    return cleaned;
  }

  /**
   * Parallel downloads with queue management
   */
  static async downloadMultiple(
    downloads: Array<{ url: string; dest: string; options?: DownloadOptions }>,
    concurrency = 3
  ): Promise<DownloadResult[]> {
    const results: DownloadResult[] = [];
    const queue = [...downloads];
    const active: Promise<DownloadResult>[] = [];

    while (queue.length > 0 || active.length > 0) {
      while (active.length < concurrency && queue.length > 0) {
        const { url, dest, options } = queue.shift()!;
        const promise = this.downloadFile(url, dest, options)
          .then((result) => {
            results.push(result);
            return result;
          })
          .catch((err) => {
            console.error(`[DownloadService] Download failed: ${url}`, err);
            throw err;
          });

        active.push(promise);
      }

      if (active.length > 0) {
        await Promise.race(active);
        const index = active.findIndex((p) => p.then(
          () => true,
          () => true
        ).then(() => true).catch(() => false));
        if (index >= 0) {
          active.splice(index, 1);
        }
      }
    }

    return results;
  }
}
