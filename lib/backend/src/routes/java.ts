import { Elysia } from 'elysia';
import { JavaService } from '../services/JavaService';

export const javaRoutes = new Elysia({ prefix: '/api/java' })
  .get('/detect', async () => {
    const system = await JavaService.detectSystemJava();
    const bundled = JavaService.getBundledJavaPath();
    
    return {
      system,
      bundled,
      preferred: bundled || system
    };
  })
  .post('/resolve', async ({ body }) => {
    const { path } = body as { path: string };
    const resolved = await JavaService.resolveJavaPath(path);
    return { resolved };
  });
