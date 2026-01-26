import { join } from 'path';
import { existsSync, mkdirSync } from 'fs';
import { getGameModsPath } from '../utils/paths';

// API Key should be provided via environment variable
const API_KEY = process.env.CURSEFORGE_API_KEY || "";
const BASE_URL = 'https://api.curseforge.com/v1';
const GAME_ID = 70216; // Hytale Game ID

export class CurseForgeService {
  private getHeaders() {
    if (!API_KEY) {
      throw new Error('API Key not configured. Please set CURSEFORGE_API_KEY in .env');
    }
    return {
      'x-api-key': API_KEY,
      'Accept': 'application/json'
    };
  }

  async searchMods(query: string = '', index: number = 0, pageSize: number = 20, sortField: number = 6, sortOrder: string = 'desc') {
    if (!API_KEY) {
      throw new Error('API Key not configured. Please set CURSEFORGE_API_KEY in .env file in backend directory');
    }

    const params = new URLSearchParams({
      gameId: GAME_ID.toString(),
      pageSize: pageSize.toString(),
      index: index.toString(),
      sortField: sortField.toString(),
      sortOrder: sortOrder
    });

    if (query) {
      params.append('searchFilter', query);
    }

    try {
      const response = await fetch(`${BASE_URL}/mods/search?${params.toString()}`, {
        headers: this.getHeaders()
      });

      if (!response.ok) {
        const text = await response.text();
        throw new Error(`CurseForge API Error: ${response.status} - ${text}`);
      }

      return await response.json();
    } catch (error) {
      console.error('Search mods error:', error);
      throw error;
    }
  }

  async installMod(downloadUrl: string, fileName: string, destinationDir: string) {
    try {
      if (!existsSync(destinationDir)) {
        mkdirSync(destinationDir, { recursive: true });
      }

      const filePath = join(destinationDir, fileName);
      console.log(`Downloading mod to: ${filePath}`);

      const response = await fetch(downloadUrl);
      if (!response.ok) {
        throw new Error(`Download failed: ${response.status}`);
      }

      const buffer = await response.arrayBuffer();
      await Bun.write(filePath, buffer);

      return { success: true, path: filePath };
    } catch (error) {
      console.error('Install mod error:', error);
      throw error;
    }
  }
}
