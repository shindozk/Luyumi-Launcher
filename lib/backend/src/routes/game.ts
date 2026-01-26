import { Elysia, t } from 'elysia';
import { GameService } from '../services/GameService';

export const gameRoutes = new Elysia({ prefix: '/api/game' })
  .get('/logs', async () => {
    try {
      const logs = await GameService.getLatestLogContent();
      return logs;
    } catch (err: any) {
      console.error('[Game API] Error getting logs:', err);
      return '';
    }
  })
  .get('/status/running', async () => {
    try {
      const isRunning = await GameService.isGameRunning();
      const startTime = GameService.getGameStartTime();
      return { isRunning, startTime };
    } catch (err: any) {
      console.error('[Game API] Error checking running status:', err);
      return { isRunning: false };
    }
  })
  .get('/status', async () => {
    try {
      const status = await GameService.getGameStatus();
      return status;
    } catch (err: any) {
      console.error('[Game API] Error getting status:', err);
      return { 
        installed: false, 
        corrupted: false, 
        reasons: [err.message || 'Unknown error'],
        latestVersion: '0.1.0-release'
      };
    }
  })
  .get('/install/progress', () => {
    try {
      return GameService.installProgress;
    } catch (err: any) {
      return { 
        percent: 0, 
        message: err.message || 'Error retrieving progress', 
        status: 'error' 
      };
    }
  })
  .post('/install', async ({ body }) => {
    console.log('[API] /api/game/install called');
    try {
      const { version } = body as { version?: string };
      console.log(`[API] Installing version: ${version || 'latest'}`);
      const result = await GameService.installGame(version);
      console.log('[API] Install result:', result);
      return result;
    } catch (err: any) {
      console.error('[API] Install failed:', err);
      return { 
        success: false, 
        error: err.message || 'Installation failed' 
      };
    }
  }, {
    body: t.Object({
      version: t.Optional(t.String())
    })
  })
  .post('/update', async ({ body }) => {
    console.log('[API] /api/game/update called');
    try {
      const { version } = body as { version?: string };
      console.log(`[API] Updating to version: ${version || 'latest'}`);
      const result = await GameService.updateGame(version);
      return result;
    } catch (err: any) {
      console.error('[API] Update failed:', err);
      return { 
        success: false, 
        error: err.message || 'Update failed' 
      };
    }
  }, {
    body: t.Object({
      version: t.Optional(t.String())
    })
  })
  .post('/repair', async ({ body }) => {
    console.log('[API] /api/game/repair called');
    try {
      const { version } = body as { version?: string };
      console.log(`[API] Repairing game version: ${version || 'latest'}`);
      const result = await GameService.repairGame(version);
      return result;
    } catch (err: any) {
      console.error('[API] Repair failed:', err);
      return { 
        success: false, 
        error: err.message || 'Repair failed' 
      };
    }
  }, {
    body: t.Object({
      version: t.Optional(t.String())
    })
  })
  .post('/uninstall', async () => {
    console.log('[API] /api/game/uninstall called');
    try {
      const success = await GameService.uninstallGame();
      return { success };
    } catch (err: any) {
      console.error('[API] Uninstall failed:', err);
      return { 
        success: false, 
        error: err.message || 'Uninstall failed' 
      };
    }
  })
  .post('/launch', async ({ body }) => {
    try {
      const options = body as any;
      console.log(`[Game] Launch request for ${options.playerName}`);

      // Validate required fields
      if (!options.playerName || !options.uuid) {
        return {
          success: false,
          error: 'Missing required fields: playerName, uuid'
        };
      }

      if (!options.identityToken || !options.sessionToken) {
        return {
          success: false,
          error: 'Missing authentication tokens'
        };
      }

      const child = await GameService.launchGameWithFallback(options);

      return {
        success: true,
        pid: child.pid,
        message: 'Game launched successfully'
      };
    } catch (err: any) {
      console.error('[Game] Launch failed:', err);
      return {
        success: false,
        error: err.message || 'Failed to launch game'
      };
    }
  }, {
    body: t.Object({
      playerName: t.String(),
      uuid: t.String(),
      identityToken: t.String(),
      sessionToken: t.String(),
      javaPath: t.Optional(t.String()),
      gameDir: t.Optional(t.String()),
      width: t.Optional(t.Number()),
      height: t.Optional(t.Number()),
      fullscreen: t.Optional(t.Boolean()),
      server: t.Optional(t.String()),
      profileId: t.Optional(t.String()),
      gpuPreference: t.Optional(t.String())
    })
  });

