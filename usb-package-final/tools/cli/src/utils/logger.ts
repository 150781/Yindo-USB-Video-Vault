import chalk from 'chalk';

export type LogLevel = 'debug' | 'info' | 'warn' | 'error';

class Logger {
  private level: LogLevel = 'info';
  private levels: Record<LogLevel, number> = {
    debug: 0,
    info: 1,
    warn: 2,
    error: 3
  };

  setLevel(level: LogLevel) {
    this.level = level;
  }

  private shouldLog(level: LogLevel): boolean {
    return this.levels[level] >= this.levels[this.level];
  }

  debug(...args: any[]) {
    if (this.shouldLog('debug')) {
      console.log(chalk.gray('🔍 [DEBUG]'), ...args);
    }
  }

  info(...args: any[]) {
    if (this.shouldLog('info')) {
      console.log(chalk.blue('ℹ️  [INFO]'), ...args);
    }
  }

  warn(...args: any[]) {
    if (this.shouldLog('warn')) {
      console.warn(chalk.yellow('⚠️  [WARN]'), ...args);
    }
  }

  error(...args: any[]) {
    if (this.shouldLog('error')) {
      console.error(chalk.red('❌ [ERROR]'), ...args);
    }
  }

  success(...args: any[]) {
    if (this.shouldLog('info')) {
      console.log(chalk.green('✅ [SUCCESS]'), ...args);
    }
  }

  task(name: string) {
    if (this.shouldLog('info')) {
      console.log(chalk.cyan('🔄'), name);
    }
  }

  step(step: string, total?: number, current?: number) {
    if (this.shouldLog('info')) {
      const progress = total && current ? `[${current}/${total}] ` : '';
      console.log(chalk.gray('  →'), progress + step);
    }
  }
}

export const logger = new Logger();
