import { Elysia } from 'elysia';
import { NewsService } from '../services/NewsService';

export const newsRoutes = new Elysia({ prefix: '/api/news' })
  .get('/', async () => {
    return await NewsService.getHytaleNews();
  });
