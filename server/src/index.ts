import Fastify from 'fastify';
import { corsPlugin } from './plugins/cors';
import { authPlugin } from './plugins/auth';
import { authRoutes } from './routes/auth';
import { workoutDaysRoutes } from './routes/workout-days';
import { exercisesRoutes } from './routes/exercises';
import { weekdayPlansRoutes } from './routes/weekday-plans';
import { setsRoutes } from './routes/sets';
import { syncRoutes } from './routes/sync';
import { initFirebase } from './lib/firebase-admin';

const PORT = parseInt(process.env.PORT || '3000');
const HOST = process.env.HOST || '0.0.0.0';

async function main() {
  // Initialize Firebase Admin
  initFirebase();

  const isDev = process.env.NODE_ENV !== 'production';

  const fastify = Fastify({
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
    await fastify.listen({ port: PORT, host: HOST });
    console.log(`🏋️ TapLift server running on ${HOST}:${PORT}`);
  } catch (err) {
    fastify.log.error(err);
    process.exit(1);
  }
}

main();
