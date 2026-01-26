import { Elysia } from 'elysia';
import { LoggerService } from './services/LoggerService';
import { authRoutes } from './routes/auth';
import { versionRoutes } from './routes/version';
import { newsRoutes } from './routes/news';
import { javaRoutes } from './routes/java';
import { modRoutes } from './routes/mods';
import { gameRoutes } from './routes/game';
import { logsRoutes } from './routes/logs';

// Initialize logger to capture all console output
LoggerService.initialize();

const app = new Elysia()
  .use(authRoutes)
  .use(versionRoutes)
  .use(newsRoutes)
  .use(javaRoutes)
  .use(modRoutes)
  .use(gameRoutes)
  .use(logsRoutes)
  .get('/', () => {
    return {
      message: "Luyumi Backend is running",
      status: "online"
    };
  })
  .listen(8080);

console.log(
  `🦊 Luyumi Backend is running at ${app.server?.hostname}:${app.server?.port}`
);
