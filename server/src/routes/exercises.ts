import { FastifyInstance, FastifyRequest, FastifyReply } from 'fastify';
import { prisma } from '../lib/prisma';

export async function exercisesRoutes(fastify: FastifyInstance): Promise<void> {
  // GET /exercises?workoutDayId=xxx
  fastify.get(
    '/exercises',
    async (
      request: FastifyRequest<{ Querystring: { workoutDayId?: string } }>,
      reply: FastifyReply
    ) => {
      const { workoutDayId } = request.query;

      const where: any = {};
      if (workoutDayId) {
        // Verify the workout day belongs to this user
        const day = await prisma.workoutDay.findFirst({
          where: { id: workoutDayId, userId: request.userId },
        });
        if (!day) return reply.status(404).send({ error: 'Workout day not found' });
        where.workoutDayId = workoutDayId;
      } else {
        // All exercises for this user's workout days
        const dayIds = (
          await prisma.workoutDay.findMany({
            where: { userId: request.userId },
            select: { id: true },
          })
        ).map((d) => d.id);
        where.workoutDayId = { in: dayIds };
      }

      const exercises = await prisma.exercise.findMany({
        where,
        orderBy: { sortIndex: 'asc' },
      });
      return exercises;
    }
  );

  // POST /exercises
  fastify.post(
    '/exercises',
    async (
      request: FastifyRequest<{
        Body: {
          id?: string;
          workoutDayId: string;
          name: string;
          sortIndex?: number;
        };
      }>,
      reply: FastifyReply
    ) => {
      const { id, workoutDayId, name, sortIndex } = request.body;

      // Verify ownership
      const day = await prisma.workoutDay.findFirst({
        where: { id: workoutDayId, userId: request.userId },
      });
      if (!day) return reply.status(404).send({ error: 'Workout day not found' });

      const exercise = await prisma.exercise.create({
        data: {
          id: id || undefined,
          workoutDayId,
          name,
          sortIndex: sortIndex ?? 0,
        },
      });
      return reply.status(201).send(exercise);
    }
  );

  // PUT /exercises/:id
  fastify.put(
    '/exercises/:id',
    async (
      request: FastifyRequest<{
        Params: { id: string };
        Body: {
          name?: string;
          sortIndex?: number;
          lastSelectedReps?: number;
          lastSelectedWeight?: number;
        };
      }>,
      reply: FastifyReply
    ) => {
      const { id } = request.params;
      const { name, sortIndex, lastSelectedReps, lastSelectedWeight } =
        request.body;

      // Verify ownership via workout day
      const exercise = await prisma.exercise.findUnique({
        where: { id },
        include: { workoutDay: true },
      });
      if (!exercise || exercise.workoutDay.userId !== request.userId) {
        return reply.status(404).send({ error: 'Not found' });
      }

      const updated = await prisma.exercise.update({
        where: { id },
        data: {
          ...(name !== undefined && { name }),
          ...(sortIndex !== undefined && { sortIndex }),
          ...(lastSelectedReps !== undefined && { lastSelectedReps }),
          ...(lastSelectedWeight !== undefined && { lastSelectedWeight }),
        },
      });
      return updated;
    }
  );

  // DELETE /exercises/:id
  fastify.delete(
    '/exercises/:id',
    async (
      request: FastifyRequest<{ Params: { id: string } }>,
      reply: FastifyReply
    ) => {
      const { id } = request.params;
      const exercise = await prisma.exercise.findUnique({
        where: { id },
        include: { workoutDay: true },
      });
      if (!exercise || exercise.workoutDay.userId !== request.userId) {
        return reply.status(404).send({ error: 'Not found' });
      }

      await prisma.exercise.delete({ where: { id } });
      return { success: true };
    }
  );
}
