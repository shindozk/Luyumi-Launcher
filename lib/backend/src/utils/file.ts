import fs from 'fs';
import https from 'https';
import http from 'http';
import path from 'path';

function downloadFile(url: string, dest: string, progressCallback?: (downloaded: number, total: number) => void): Promise<void> {
  const MAX_REDIRECTS = 5;
  const MAX_RETRIES = 3;
  const TIMEOUT_MS = 60000;
  const STALLED_MS = 30000;

  const retryableErrors = new Set(['ECONNRESET', 'ENOTFOUND', 'ECONNREFUSED', 'ETIMEDOUT', 'ESOCKETTIMEDOUT', 'EPROTO']);

  function cleanupPartial() {
    if (fs.existsSync(dest)) {
      try {
        fs.unlinkSync(dest);
      } catch (_) {}
    }
  }

  function doDownload(currentUrl: string, redirectsLeft: number, attempt: number): Promise<void> {
    return new Promise((resolve, reject) => {
      try {
        const dir = path.dirname(dest);
        if (!fs.existsSync(dir)) {
          fs.mkdirSync(dir, { recursive: true });
        }
      } catch (_) {}

      if (fs.existsSync(dest)) {
        cleanupPartial();
      }

      const file = fs.createWriteStream(dest);
      const protocol = currentUrl.startsWith('https') ? https : http;
      let stalledTimeout: NodeJS.Timeout | null = null;
      let downloadStalled = false;

      const request = protocol.request(currentUrl, {
        method: 'GET',
        family: 4,
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          'Accept': '*/*',
          'Accept-Language': 'en-US,en;q=0.9',
          'Referer': 'https://launcher.hytale.com/',
          'Connection': 'keep-alive'
        }
      }, (response) => {
        if (response.statusCode && [301, 302, 303, 307, 308].includes(response.statusCode)) {
          const loc = response.headers.location;
          file.close();
          cleanupPartial();
          if (loc && redirectsLeft > 0) {
            resolve(doDownload(new URL(loc, currentUrl).toString(), redirectsLeft - 1, attempt));
            return;
          }
          reject(new Error(`Too many redirects or missing Location header for ${currentUrl}`));
          return;
        }

        if (response.statusCode !== 200) {
          file.close();
          cleanupPartial();
          reject(new Error(`Failed to download (${response.statusCode}): ${currentUrl}`));
          return;
        }

        const total = parseInt(response.headers['content-length'] || '0', 10);
        let downloaded = 0;
        let lastEmit = Date.now();

        const resetStalledTimer = () => {
          if (stalledTimeout) {
            clearTimeout(stalledTimeout);
          }
          stalledTimeout = setTimeout(() => {
            downloadStalled = true;
            response.destroy(new Error('Download stalled'));
            file.destroy(new Error('Download stalled'));
          }, STALLED_MS);
        };

        resetStalledTimer();

        response.on('data', (chunk) => {
          downloaded += chunk.length;
          resetStalledTimer();
          if (progressCallback) {
            const now = Date.now();
            if (now - lastEmit > 200) {
              lastEmit = now;
              progressCallback(downloaded, total);
            }
          }
        });

        response.on('error', (err) => {
          if (stalledTimeout) {
            clearTimeout(stalledTimeout);
          }
          file.destroy(err);
        });

        response.pipe(file);
        file.on('finish', () => {
          if (stalledTimeout) {
            clearTimeout(stalledTimeout);
          }
          if (downloadStalled) {
            cleanupPartial();
            reject(new Error('Download stalled'));
            return;
          }
          file.close();
          resolve();
        });

        file.on('error', (err) => {
          if (stalledTimeout) {
            clearTimeout(stalledTimeout);
          }
          cleanupPartial();
          reject(err);
        });
      });

      request.setTimeout(TIMEOUT_MS, () => {
        request.destroy(new Error(`Download timed out after ${TIMEOUT_MS}ms`));
      });

      request.on('error', (err: NodeJS.ErrnoException) => {
        if (stalledTimeout) {
          clearTimeout(stalledTimeout);
        }
        cleanupPartial();

        const isRetryable = retryableErrors.has(err.code || '') || err.message.includes('timeout') || err.message.includes('stalled');
        if (attempt + 1 < MAX_RETRIES && isRetryable) {
          const delay = 2000 * (attempt + 1);
          setTimeout(() => {
            doDownload(currentUrl, redirectsLeft, attempt + 1).then(resolve).catch(reject);
          }, delay);
          return;
        }
        reject(err);
      });

      request.end();
    });
  }

  return doDownload(url, MAX_REDIRECTS, 0);
}

function findHomePageUIPath(gameDir: string) {
  // Common locations
  const candidates = [
    path.join(gameDir, 'Client', 'Content', 'UI', 'HomePage.ui'),
    path.join(gameDir, 'Content', 'UI', 'HomePage.ui'), // Possible variations
  ];
  for (const p of candidates) {
    if (fs.existsSync(p)) return p;
  }
  return null;
}

function findLogoPath(gameDir: string) {
  const candidates = [
    path.join(gameDir, 'Client', 'Content', 'UI', 'Assets', 'Logo@2x.png'),
    path.join(gameDir, 'Content', 'UI', 'Assets', 'Logo@2x.png'),
  ];
  for (const p of candidates) {
    if (fs.existsSync(p)) return p;
  }
  return null;
}

export { downloadFile, findHomePageUIPath, findLogoPath };
