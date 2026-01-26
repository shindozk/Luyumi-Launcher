import { Elysia } from 'elysia';
import { VersionService } from '../services/VersionService';

export const versionRoutes = new Elysia({ prefix: '/api/version' })
  .get('/client', async () => {
    const version = await VersionService.getLatestVersion();
    const url = VersionService.getPatchUrl(version);

    return {
      client_version: version,
      download_url: url
    };
  })
  // Legacy support or specific patch url
  .get('/patch-url', async ({ query }) => {
    const version = query.version || await VersionService.getLatestVersion();
    const channel = query.channel || 'release';
    return {
      url: VersionService.getPatchUrl(version, channel)
    };
  });
