import { FastifyInstance, FastifyRequest, FastifyReply } from 'fastify';
import { PrismaClient } from '@prisma/client';

export async function weekdayPlansRoutes(
  fastify: FastifyInstance
): Promise<void> {
  const prisma = new PrismaClient();

  // GET /weekday-plans
  fastify.get(
    '/weekday-plans',
    async (request: FastifyRequest, reply: FastifyReply) => {
      const plans = await prisma.weekdayPlan.findMany({
        where: { userId: request.userId },
        orderBy: { weekday: 'asc' },
        include: { workoutDay: true },
      });
      return plans;
    }
  );

  // PUT /weekday-plans — bulk update all 7 weekdays
  fastify.put(
    '/weekday-plans',
    async (
      request: FastifyRequest<{
        Body: Array<{
          weekday: number;
          workoutDayId: string | null;
        }>;
      }>,
      reply: FastifyReply
    ) => {
      const plans = request.body;

      // Validate weekdays
      for (const plan of plans) {
        if (plan.weekday < 1 || plan.weekday > 7) {
          return reply
            .status(400)
            .send({ error: `Invalid weekday: ${plan.weekday}` });
        }
      }

      // Upsert each plan
      const results = await Promise.all(
        plans.map((plan) =>
          prisma.weekdayPlan.upsert({
            where: {
              userId_weekday: {
                userId: request.userId,
                weekday: plan.weekday,
              },
            },
            update: {
              workoutDayId: plan.workoutDayId,
            },
            create: {
              userId: request.userId,
              weekday: plan.weekday,
              workoutDayId: plan.workoutDayId,
            },
          })
        )
      );

      return results;
    }
  );

  fastify.addHook('onClose', async () => {
    await prisma.$disconnect();
  });
}
