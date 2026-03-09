type NodeEnv = 'development' | 'test' | 'production';

export interface ServerConfig {
  nodeEnv: NodeEnv;
  isProduction: boolean;
  host: string;
  port: number;
  requireFirebaseAuth: boolean;
  corsOriginRaw: string;
}

function parseBooleanEnv(value: string | undefined, fallback: boolean): boolean {
  if (value == null || value.trim().length === 0) return fallback;
  switch (value.trim().toLowerCase()) {
    case '1':
    case 'true':
    case 'yes':
    case 'on':
      return true;
    case '0':
    case 'false':
    case 'no':
    case 'off':
      return false;
    default:
      return fallback;
  }
}

export function loadConfig(): ServerConfig {
  const nodeEnv = (process.env.NODE_ENV || 'development') as NodeEnv;
  const isProduction = nodeEnv === 'production';

  const portRaw = process.env.PORT || process.env.API_PORT || '3001';
  const port = Number.parseInt(portRaw, 10);
  if (!Number.isFinite(port) || port <= 0 || port > 65535) {
    throw new Error(`Invalid PORT/API_PORT value: ${portRaw}`);
  }

  const host = process.env.HOST || '0.0.0.0';
  if (
    !process.env.DATABASE_URL ||
    process.env.DATABASE_URL.trim().length === 0
  ) {
    throw new Error('DATABASE_URL is required');
  }

  return {
    nodeEnv,
    isProduction,
    host,
    port,
    requireFirebaseAuth: parseBooleanEnv(
      process.env.REQUIRE_FIREBASE_AUTH,
      isProduction
    ),
    corsOriginRaw: process.env.CORS_ORIGIN ?? '',
  };
}
