import { FastifyInstance, FastifyRequest, FastifyReply } from 'fastify';
import { verifyFirebaseToken } from '../lib/firebase-admin';
import { prisma } from '../lib/prisma';

declare module 'fastify' {
  interface FastifyRequest {
    userId: string;
    userEmail?: string;
  }
}

export async function authPlugin(fastify: FastifyInstance): Promise<void> {
  fastify.decorateRequest('userId', '');
  fastify.decorateRequest('userEmail', undefined);

  fastify.addHook(
    'preHandler',
    async (request: FastifyRequest, reply: FastifyReply) => {
      if (request.method === 'OPTIONS') return;

      const path = request.url.split('?')[0];
      if (path === '/health') return;

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
        request.log.warn({ err: error }, 'Token verification failed');
        return reply.status(401).send({ error: 'Invalid token' });
      }
    }
  );
}
