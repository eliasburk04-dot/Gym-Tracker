import { FastifyInstance, FastifyRequest, FastifyReply } from 'fastify';
import { prisma } from '../lib/prisma';

export async function workoutDaysRoutes(fastify: FastifyInstance): Promise<void> {
  // GET /workout-days
  fastify.get(
    '/workout-days',
    async (request: FastifyRequest, reply: FastifyReply) => {
      const days = await prisma.workoutDay.findMany({
        where: { userId: request.userId },
        orderBy: { sortIndex: 'asc' },
        include: { exercises: { orderBy: { sortIndex: 'asc' } } },
      });
      return days;
    }
  );

  // POST /workout-days
  fastify.post(
    '/workout-days',
    async (
      request: FastifyRequest<{
        Body: { id?: string; name: string; sortIndex?: number };
      }>,
      reply: FastifyReply
    ) => {
      const { id, name, sortIndex } = request.body;
      const day = await prisma.workoutDay.create({
        data: {
          id: id || undefined,
          userId: request.userId,
          name,
          sortIndex: sortIndex ?? 0,
        },
      });
      return reply.status(201).send(day);
    }
  );

  // PUT /workout-days/:id
  fastify.put(
    '/workout-days/:id',
    async (
      request: FastifyRequest<{
        Params: { id: string };
        Body: { name?: string; sortIndex?: number };
      }>,
      reply: FastifyReply
    ) => {
      const { id } = request.params;
      const { name, sortIndex } = request.body;

      // Verify ownership
      const existing = await prisma.workoutDay.findFirst({
        where: { id, userId: request.userId },
      });
      if (!existing) {
        return reply.status(404).send({ error: 'Not found' });
      }

      const updated = await prisma.workoutDay.update({
        where: { id },
        data: {
          ...(name !== undefined && { name }),
          ...(sortIndex !== undefined && { sortIndex }),
        },
      });
      return updated;
    }
  );

  // DELETE /workout-days/:id
  fastify.delete(
    '/workout-days/:id',
    async (
      request: FastifyRequest<{ Params: { id: string } }>,
      reply: FastifyReply
    ) => {
      const { id } = request.params;
      const existing = await prisma.workoutDay.findFirst({
        where: { id, userId: request.userId },
      });
      if (!existing) {
        return reply.status(404).send({ error: 'Not found' });
      }

      await prisma.workoutDay.delete({ where: { id } });
      return { success: true };
    }
  );
}
