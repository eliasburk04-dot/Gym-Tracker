import { FastifyInstance, FastifyRequest, FastifyReply } from 'fastify';
import { PrismaClient } from '@prisma/client';
import { verifyFirebaseToken } from '../lib/firebase-admin';

declare module 'fastify' {
  interface FastifyRequest {
    userId: string;
    userEmail?: string;
  }
}

export async function authPlugin(fastify: FastifyInstance): Promise<void> {
  const prisma = new PrismaClient();

  fastify.decorateRequest('userId', '');
  fastify.decorateRequest('userEmail', undefined);

  fastify.addHook(
    'preHandler',
    async (request: FastifyRequest, reply: FastifyReply) => {
      // Skip auth for health check
      if (request.url === '/health') return;

      const authHeader = request.headers.authorization;
      if (!authHeader?.startsWith('Bearer ')) {
        return reply.status(401).send({ error: 'Missing authorization token' });
      }

      const token = authHeader.substring(7);

      try {
        const decoded = await verifyFirebaseToken(token);
        request.userId = decoded.uid;
        request.userEmail = decoded.email;

        // Upsert user in DB
        await prisma.user.upsert({
          where: { id: decoded.uid },
          update: {
            email: decoded.email,
            updatedAt: new Date(),
          },
          create: {
            id: decoded.uid,
            email: decoded.email,
            authProvider: decoded.firebase?.sign_in_provider || 'unknown',
          },
        });
      } catch (error) {
        return reply.status(401).send({ error: 'Invalid token' });
      }
    }
  );

  fastify.addHook('onClose', async () => {
    await prisma.$disconnect();
  });
}
