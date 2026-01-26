import fs from 'fs';
import path from 'path';
import AdmZip from 'adm-zip';
import { findClientPath } from '../utils/paths';
import { ConfigService } from './ConfigService';

const ORIGINAL_DOMAIN = 'hytale.com';
const DEFAULT_NEW_DOMAIN = 'sanasol.ws';

function getTargetDomain() {
  return ConfigService.getAuthDomain();
}

export class PatcherService {
  private patchedFlag = '.patched_custom';

  getNewDomain() {
    const domain = getTargetDomain();
    if (domain.length !== ORIGINAL_DOMAIN.length) {
      console.warn(`Warning: Domain "${domain}" length (${domain.length}) doesn't match original "${ORIGINAL_DOMAIN}" (${ORIGINAL_DOMAIN.length})`);
      console.warn(`Using default domain: ${DEFAULT_NEW_DOMAIN}`);
      return DEFAULT_NEW_DOMAIN;
    }
    return domain;
  }

  stringToUtf16LE(str: string) {
    const buf = Buffer.alloc(str.length * 2);
    for (let i = 0; i < str.length; i++) {
      buf.writeUInt16LE(str.charCodeAt(i), i * 2);
    }
    return buf;
  }

  stringToUtf8(str: string) {
    return Buffer.from(str, 'utf8');
  }

  findAllOccurrences(buffer: Buffer, pattern: Buffer) {
    const positions: number[] = [];
    let pos = 0;
    while (pos < buffer.length) {
      const index = buffer.indexOf(pattern, pos);
      if (index === -1) break;
      positions.push(index);
      pos = index + 1;
    }
    return positions;
  }

  findAndReplaceDomainUtf8(data: Buffer, oldDomain: string, newDomain: string) {
    let count = 0;
    const result = Buffer.from(data);

    const oldUtf8 = this.stringToUtf8(oldDomain);
    const newUtf8 = this.stringToUtf8(newDomain);

    const positions = this.findAllOccurrences(result, oldUtf8);

    for (const pos of positions) {
      newUtf8.copy(result, pos);
      count++;
    }

    return { buffer: result, count };
  }

  findAndReplaceDomainSmart(data: Buffer, oldDomain: string, newDomain: string) {
    let count = 0;
    const result = Buffer.from(data);

    const oldUtf16NoLast = this.stringToUtf16LE(oldDomain.slice(0, -1));
    const newUtf16NoLast = this.stringToUtf16LE(newDomain.slice(0, -1));
    
    const oldLastCharByte = oldDomain.charCodeAt(oldDomain.length - 1);
    const newLastCharByte = newDomain.charCodeAt(newDomain.length - 1);

    const positions = this.findAllOccurrences(result, oldUtf16NoLast);

    for (const pos of positions) {
      const lastCharPos = pos + oldUtf16NoLast.length;
      if (lastCharPos + 1 > result.length) continue;

      const lastCharFirstByte = result[lastCharPos];

      if (lastCharFirstByte === oldLastCharByte) {
        newUtf16NoLast.copy(result, pos);
        result[lastCharPos] = newLastCharByte;
        count++;
      }
    }

    return { buffer: result, count };
  }

  patchDiscordUrl(data: Buffer) {
    let count = 0;
    const result = Buffer.from(data);
    
    // Patch discord URL if necessary - skipping for now as per Hytale-F2P logic often patches specific bytes
    // For brevity, assuming domain patching is the main goal
    
    return { buffer: result, count };
  }

  findServerPath(gameDir: string) {
    const candidates = [
      path.join(gameDir, 'Server', 'HytaleServer.jar'),
      path.join(gameDir, 'Server', 'server.jar')
    ];

    for (const candidate of candidates) {
      if (fs.existsSync(candidate)) {
        return candidate;
      }
    }
    return null;
  }

  async patchServer(serverPath: string, newDomain: string) {
    try {
      const zip = new AdmZip(serverPath);
      const entries = zip.getEntries();
      let totalCount = 0;
      const oldUtf8 = this.stringToUtf8(ORIGINAL_DOMAIN);
      const newUtf8 = this.stringToUtf8(newDomain);

      for (const entry of entries) {
        const name = entry.entryName;
        if (name.endsWith('.class') || name.endsWith('.properties') || name.endsWith('.json') || name.endsWith('.xml') || name.endsWith('.yml')) {
          const data = entry.getData();
          if (data.includes(oldUtf8)) {
            const { buffer: patchedData, count } = this.findAndReplaceDomainUtf8(data, ORIGINAL_DOMAIN, newDomain);
            if (count > 0) {
              zip.updateFile(entry.entryName, patchedData);
              totalCount += count;
            }
          }
        }
      }

      if (totalCount > 0) {
        zip.writeZip(serverPath);
        return true;
      }
    } catch (err) {
      console.error(`Error patching server ${path.basename(serverPath)}:`, err);
    }
    return false;
  }

  async patchFile(filePath: string, newDomain: string) {
    try {
      const data = await fs.promises.readFile(filePath);
      
      const resUtf8 = this.findAndReplaceDomainUtf8(data, ORIGINAL_DOMAIN, newDomain);
      let patchedData = resUtf8.buffer;
      let totalCount = resUtf8.count;

      const resSmart = this.findAndReplaceDomainSmart(patchedData, ORIGINAL_DOMAIN, newDomain);
      patchedData = resSmart.buffer;
      totalCount += resSmart.count;

      if (totalCount > 0) {
        await fs.promises.writeFile(filePath, patchedData);
        console.log(`Patched ${path.basename(filePath)}: ${totalCount} occurrences replaced.`);
        return true;
      }
    } catch (err) {
      console.error(`Error patching ${filePath}:`, err);
    }
    return false;
  }

  isPatchedAlready(filePath: string, newDomain: string) {
    const patchFlagFile = filePath + this.patchedFlag;
    if (fs.existsSync(patchFlagFile)) {
      try {
        const content = fs.readFileSync(patchFlagFile, 'utf8');
        const flagData = JSON.parse(content);
        if (flagData.targetDomain === newDomain) {
            // Optional: Check if file mtime is older than patch time? 
            // But usually if file updates, it overwrites everything including attributes.
            // Better to assume if flag exists and matches domain, it's good.
            // Unless the user manually replaced the exe but kept the flag.
            // Let's check if the binary is newer than the flag.
            const binStats = fs.statSync(filePath);
            const flagStats = fs.statSync(patchFlagFile);
            if (binStats.mtimeMs > flagStats.mtimeMs) {
                console.log(`Binary ${path.basename(filePath)} is newer than patch flag. Repatching...`);
                return false;
            }
            return true;
        }
      } catch (e) {
        // Invalid flag file, repatch
      }
    }
    return false;
  }

  markAsPatched(filePath: string, newDomain: string) {
    const patchFlagFile = filePath + this.patchedFlag;
    const flagData = {
      patchedAt: new Date().toISOString(),
      originalDomain: ORIGINAL_DOMAIN,
      targetDomain: newDomain,
      patcherVersion: '1.0.0'
    };
    fs.writeFileSync(patchFlagFile, JSON.stringify(flagData, null, 2));
  }

  async ensureClientPatched(gameDir: string) {
    const newDomain = this.getNewDomain();
    console.log(`[PatcherService] Ensuring client is patched for domain: ${newDomain}`);

    const clientCandidates = [
      findClientPath(gameDir),
      path.join(gameDir, 'Client', 'Hytale.exe'),
      path.join(gameDir, 'Client', 'HytaleClient.exe')
    ].filter(Boolean) as string[];

    // Deduplicate candidates
    const uniqueCandidates = [...new Set(clientCandidates)];

    for (const clientPath of uniqueCandidates) {
      if (fs.existsSync(clientPath)) {
        if (!this.isPatchedAlready(clientPath, newDomain)) {
             console.log(`[PatcherService] Patching ${path.basename(clientPath)}...`);
             const success = await this.patchFile(clientPath, newDomain);
             if (success) {
                 this.markAsPatched(clientPath, newDomain);
             }
        } else {
            console.log(`[PatcherService] ${path.basename(clientPath)} already patched.`);
        }
      }
    }

    const serverPath = this.findServerPath(gameDir);
    if (serverPath && fs.existsSync(serverPath)) {
        if (!this.isPatchedAlready(serverPath, newDomain)) {
            console.log(`[PatcherService] Patching server ${path.basename(serverPath)}...`);
            const success = await this.patchServer(serverPath, newDomain);
             if (success) {
                 this.markAsPatched(serverPath, newDomain);
             }
        } else {
             console.log(`[PatcherService] ${path.basename(serverPath)} already patched.`);
        }
    }
  }
}


export const clientPatcher = new PatcherService();
