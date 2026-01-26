import { Elysia } from 'elysia';
import { LoggerService } from '../services/LoggerService';

export const logsRoutes = new Elysia({ prefix: '/logs' })
  .get('/', () => {
    const logs = LoggerService.getLogs();
    return {
      success: true,
      logs,
      count: logs.length
    };
  })
  .get('/recent', ({ query }: { query: { limit?: string } }) => {
    const limit = query.limit ? parseInt(query.limit) : 50;
    const logs = LoggerService.getLogs(limit);
    return {
      success: true,
      logs,
      count: logs.length
    };
  })
  .get('/since', ({ query }) => {
    const timestamp = query.timestamp as string | undefined;
    if (!timestamp) {
      return {
        success: false,
        error: 'timestamp query parameter required'
      };
    }

    const logs = LoggerService.getLogsSince(timestamp);
    return {
      success: true,
      logs,
      count: logs.length
    };
  })
  .get('/level/:level', ({ params }: { params: { level: string } }) => {
    const validLevels = ['info', 'warn', 'error', 'debug'];
    if (!validLevels.includes(params.level)) {
      return {
        success: false,
        error: `Invalid level. Must be one of: ${validLevels.join(', ')}`
      };
    }

    const logs = LoggerService.getLogsByLevel(params.level as 'info' | 'warn' | 'error' | 'debug');
    return {
      success: true,
      logs,
      count: logs.length
    };
  })
  .delete('/', () => {
    LoggerService.clearLogs();
    return {
      success: true,
      message: 'All logs cleared'
    };
  });
