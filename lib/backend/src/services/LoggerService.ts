/**
 * LoggerService - Captura e gerencia logs do backend
 * Permite que o frontend acesse os logs em tempo real
 */

export interface LogEntry {
  timestamp: string;
  level: 'info' | 'warn' | 'error' | 'debug';
  message: string;
  source?: string;
}

export class LoggerService {
  private static logs: LogEntry[] = [];
  private static maxLogs = 1000; // Manter apenas os últimos 1000 logs
  private static originalConsoleLog = console.log;
  private static originalConsoleWarn = console.warn;
  private static originalConsoleError = console.error;

  /**
   * Initialize logger - hijack console methods
   */
  static initialize() {
    console.log = (...args: any[]) => {
      LoggerService.log('info', args.join(' '));
      LoggerService.originalConsoleLog.apply(console, args);
    };

    console.warn = (...args: any[]) => {
      LoggerService.log('warn', args.join(' '));
      LoggerService.originalConsoleWarn.apply(console, args);
    };

    console.error = (...args: any[]) => {
      LoggerService.log('error', args.join(' '));
      LoggerService.originalConsoleError.apply(console, args);
    };
  }

  /**
   * Log a message
   */
  static log(level: 'info' | 'warn' | 'error' | 'debug', message: string, source?: string) {
    const entry: LogEntry = {
      timestamp: new Date().toISOString(),
      level,
      message,
      source
    };

    this.logs.push(entry);

    // Keep only the last N logs to avoid memory issues
    if (this.logs.length > this.maxLogs) {
      this.logs = this.logs.slice(-this.maxLogs);
    }
  }

  /**
   * Get all logs
   */
  static getLogs(limit?: number): LogEntry[] {
    if (limit && limit > 0) {
      return this.logs.slice(-limit);
    }
    return [...this.logs];
  }

  /**
   * Get logs since a specific timestamp
   */
  static getLogsSince(timestamp: string): LogEntry[] {
    return this.logs.filter(log => log.timestamp > timestamp);
  }

  /**
   * Clear all logs
   */
  static clearLogs() {
    this.logs = [];
  }

  /**
   * Get logs by level
   */
  static getLogsByLevel(level: 'info' | 'warn' | 'error' | 'debug'): LogEntry[] {
    return this.logs.filter(log => log.level === level);
  }
}
