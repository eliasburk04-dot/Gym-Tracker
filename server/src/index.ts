import Fastify from 'fastify';
import { corsPlugin } from './plugins/cors';
import { authPlugin } from './plugins/auth';
import { authRoutes } from './routes/auth';
import { workoutDaysRoutes } from './routes/workout-days';
import { exercisesRoutes } from './routes/exercises';
import { weekdayPlansRoutes } from './routes/weekday-plans';
import { setsRoutes } from './routes/sets';
import { syncRoutes } from './routes/sync';
import { initFirebase, isFirebaseAvailable } from './lib/firebase-admin';
import { loadConfig } from './lib/config';
import { prisma } from './lib/prisma';

async function main() {
  const config = loadConfig();

  // Initialize Firebase Admin
  initFirebase();
  if (config.requireFirebaseAuth && !isFirebaseAvailable()) {
    throw new Error(
      'REQUIRE_FIREBASE_AUTH=true but Firebase Admin is not available. Refusing to start.'
    );
  }

  const isDev = !config.isProduction;

  const fastify = Fastify({
    bodyLimit: 1024 * 1024,
    logger: isDev
      ? {
          level: 'info',
          transport: {
            target: 'pino-pretty',
            options: { colorize: true },
          },
        }
      : { level: 'info' },
  });

  fastify.setErrorHandler((error, request, reply) => {
    request.log.error({ err: error }, 'Unhandled error');
    reply.status(500).send({ error: 'Internal server error' });
  });

  fastify.addHook('onSend', async (_request, reply) => {
    reply.header('X-Content-Type-Options', 'nosniff');
    reply.header('X-Frame-Options', 'DENY');
    reply.header('Referrer-Policy', 'no-referrer');
    reply.header('Cache-Control', 'no-store');
  });

  fastify.addHook('onClose', async () => {
    await prisma.$disconnect();
  });

  // Register plugins
  await fastify.register(corsPlugin);
  await fastify.register(authPlugin);

  // Register routes
  await fastify.register(authRoutes);
  await fastify.register(workoutDaysRoutes);
  await fastify.register(exercisesRoutes);
  await fastify.register(weekdayPlansRoutes);
  await fastify.register(setsRoutes);
  await fastify.register(syncRoutes);

  // Health check (no auth required)
  fastify.get('/health', async () => ({
    status: 'ok',
    timestamp: new Date().toISOString(),
    version: '0.1.0',
  }));

  // Start server
  try {
    await fastify.listen({ port: config.port, host: config.host });
    console.log(`🏋️ TapLift server running on ${config.host}:${config.port}`);
  } catch (err) {
    fastify.log.error(err);
    process.exit(1);
  }
}

main().catch((err) => {
  console.error('Fatal startup error:', err);
  process.exit(1);
});
