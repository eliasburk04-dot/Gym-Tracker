import { FastifyInstance, FastifyRequest, FastifyReply } from 'fastify';
import { PrismaClient } from '@prisma/client';

export async function setsRoutes(fastify: FastifyInstance): Promise<void> {
  const prisma = new PrismaClient();

  // POST /sets — log a new set
  fastify.post(
    '/sets',
    async (
      request: FastifyRequest<{
        Body: {
          id?: string;
          exerciseId: string;
          reps: number;
          weight: number;
          source?: string;
          timestamp?: string;
        };
      }>,
      reply: FastifyReply
    ) => {
      const { id, exerciseId, reps, weight, source, timestamp } = request.body;

      // Verify exercise belongs to user
      const exercise = await prisma.exercise.findUnique({
        where: { id: exerciseId },
        include: { workoutDay: true },
      });
      if (!exercise || exercise.workoutDay.userId !== request.userId) {
        return reply.status(404).send({ error: 'Exercise not found' });
      }

      const set = await prisma.workoutSet.create({
        data: {
          id: id || undefined,
          exerciseId,
          userId: request.userId,
          reps,
          weight,
          source: source || 'app',
          timestamp: timestamp ? new Date(timestamp) : new Date(),
        },
      });

      // Update exercise last selected
      await prisma.exercise.update({
        where: { id: exerciseId },
        data: {
          lastSelectedReps: reps,
          lastSelectedWeight: weight,
        },
      });

      return reply.status(201).send(set);
    }
  );

  // GET /sets/today — get all sets logged today
  fastify.get(
    '/sets/today',
    async (request: FastifyRequest, reply: FastifyReply) => {
      const todayStart = new Date();
      todayStart.setHours(0, 0, 0, 0);

      const sets = await prisma.workoutSet.findMany({
        where: {
          userId: request.userId,
          timestamp: { gte: todayStart },
        },
        orderBy: { timestamp: 'asc' },
        include: { exercise: true },
      });
      return sets;
    }
  );

  // GET /sets?exerciseId=xxx — get sets for a specific exercise
  fastify.get(
    '/sets',
    async (
      request: FastifyRequest<{
        Querystring: { exerciseId?: string; limit?: string };
      }>,
      reply: FastifyReply
    ) => {
      const { exerciseId, limit } = request.query;

      const where: any = { userId: request.userId };
      if (exerciseId) where.exerciseId = exerciseId;

      const sets = await prisma.workoutSet.findMany({
        where,
        orderBy: { timestamp: 'desc' },
        take: limit ? parseInt(limit) : 50,
      });
      return sets;
    }
  );

  fastify.addHook('onClose', async () => {
    await prisma.$disconnect();
  });
}
