import { Elysia, t } from 'elysia';
import { ModService } from '../services/ModService';
import { CurseForgeService } from '../services/CurseForgeService';
import { Mod } from '../types/Mod';

const cfService = new CurseForgeService();

export const modRoutes = new Elysia({ prefix: '/api/mods' })
  .get('/:profileId', async ({ params: { profileId } }) => {
    return await ModService.loadInstalledMods(profileId);
  })
  .post('/toggle', async ({ body }) => {
    const { profileId, fileName, enable } = body as { profileId: string, fileName: string, enable: boolean };
    const success = await ModService.toggleMod(profileId, fileName, enable);
    return { success };
  }, {
    body: t.Object({
      profileId: t.String(),
      fileName: t.String(),
      enable: t.Boolean()
    })
  })
  .post('/download', async ({ body }) => {
    const { profileId, url, fileName } = body as { profileId: string, url: string, fileName: string };
    const result = await ModService.downloadMod(profileId, url, fileName);
    return result;
  }, {
    body: t.Object({
      profileId: t.String(),
      url: t.String(),
      fileName: t.String()
    })
  })
  .post('/uninstall', async ({ body }) => {
    const { profileId, fileName } = body as { profileId: string, fileName: string };
    const success = await ModService.uninstallMod(profileId, fileName);
    return { success };
  }, {
    body: t.Object({
      profileId: t.String(),
      fileName: t.String()
    })
  })
  .post('/sync', async ({ body }) => {
    const { profileId } = body as { profileId: string };
    const result = await ModService.syncSymlink(profileId);
    return result;
  }, {
    body: t.Object({
      profileId: t.String()
    })
  })
  .post('/openFolder', async ({ body }) => {
    const { profileId } = body as { profileId: string };
    ModService.openModsFolder(profileId);
    return { success: true };
  }, {
    body: t.Object({
      profileId: t.String()
    })
  })
  .post('/search', async ({ body }) => {
    const { query, index, pageSize, sortField, sortOrder } = body as { 
      query?: string, 
      index?: number, 
      pageSize?: number,
      sortField?: number,
      sortOrder?: string
    };
    return await cfService.searchMods(query, index, pageSize, sortField, sortOrder);
  }, {
    body: t.Object({
      query: t.Optional(t.String()),
      index: t.Optional(t.Number()),
      pageSize: t.Optional(t.Number()),
      sortField: t.Optional(t.Number()),
      sortOrder: t.Optional(t.String())
    })
  })
  .post('/install-cf', async ({ body }) => {
    const { downloadUrl, fileName, profileId } = body as { downloadUrl: string, fileName: string, profileId: string };
    const modsPath = ModService.getProfileModsPath(profileId);
    return await cfService.installMod(downloadUrl, fileName, modsPath);
  }, {
    body: t.Object({
      downloadUrl: t.String(),
      fileName: t.String(),
      profileId: t.String()
    })
  });
