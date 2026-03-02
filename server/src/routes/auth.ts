import { FastifyInstance, FastifyRequest, FastifyReply } from 'fastify';
import { PrismaClient } from '@prisma/client';

export async function authRoutes(fastify: FastifyInstance): Promise<void> {
  const prisma = new PrismaClient();

  // POST /auth/verify-token — verifies token, returns user profile
  fastify.post(
    '/auth/verify-token',
    async (request: FastifyRequest, reply: FastifyReply) => {
      // Auth already handled by preHandler hook; user is created/updated
      const user = await prisma.user.findUnique({
        where: { id: request.userId },
      });

      if (!user) {
        return reply.status(404).send({ error: 'User not found' });
      }

      return {
        id: user.id,
        email: user.email,
        displayName: user.displayName,
        authProvider: user.authProvider,
        weightUnit: user.weightUnit,
        weightIncrement: user.weightIncrement,
        createdAt: user.createdAt,
      };
    }
  );

  fastify.addHook('onClose', async () => {
    await prisma.$disconnect();
  });
}
