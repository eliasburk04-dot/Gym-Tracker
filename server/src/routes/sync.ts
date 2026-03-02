import { FastifyInstance, FastifyRequest, FastifyReply } from 'fastify';
import { PrismaClient } from '@prisma/client';

interface SyncBody {
  sets?: Array<{
    id: string;
    exerciseId: string;
    setNumber?: number;
    reps: number;
    weight: number;
    rir?: number | null;
    source: string;
    timestamp: string;
  }>;
  workoutDays?: Array<{
    id: string;
    name: string;
    sortIndex: number;
    updatedAt: string;
  }>;
  exercises?: Array<{
    id: string;
    workoutDayId: string;
    name: string;
    sortIndex: number;
    lastSelectedReps: number;
    lastSelectedWeight: number;
    targetSets?: number;
    targetWeight?: number;
    repTargetMin?: number;
    repTargetMax?: number;
    updatedAt: string;
  }>;
  weekdayPlans?: Array<{
    weekday: number;
    workoutDayId: string | null;
    updatedAt: string;
  }>;
}

export async function syncRoutes(fastify: FastifyInstance): Promise<void> {
  const prisma = new PrismaClient();

  // POST /sync — batch sync from client
  fastify.post(
    '/sync',
    async (
      request: FastifyRequest<{ Body: SyncBody }>,
      reply: FastifyReply
    ) => {
      const { sets, workoutDays, exercises, weekdayPlans } = request.body;
      const userId = request.userId;
      const results: Record<string, number> = {};

      // Sets are append-only — upsert by ID
      if (sets?.length) {
        let count = 0;
        for (const set of sets) {
          try {
            await prisma.workoutSet.upsert({
              where: { id: set.id },
              update: {}, // Don't update existing sets (append-only)
              create: {
                id: set.id,
                exerciseId: set.exerciseId,
                userId,
                setNumber: set.setNumber ?? 1,
                reps: set.reps,
                weight: set.weight,
                rir: set.rir ?? null,
                source: set.source || 'app',
                timestamp: new Date(set.timestamp),
              },
            });
            count++;
          } catch {
            // Skip conflicts (e.g., referencing deleted exercises)
          }
        }
        results.sets = count;
      }

      // Workout days — last-write-wins by updatedAt
      if (workoutDays?.length) {
        let count = 0;
        for (const day of workoutDays) {
          const existing = await prisma.workoutDay.findUnique({
            where: { id: day.id },
          });
          const clientUpdated = new Date(day.updatedAt);

          if (!existing) {
            await prisma.workoutDay.create({
              data: {
                id: day.id,
                userId,
                name: day.name,
                sortIndex: day.sortIndex,
              },
            });
            count++;
          } else if (clientUpdated > existing.updatedAt) {
            await prisma.workoutDay.update({
              where: { id: day.id },
              data: {
                name: day.name,
                sortIndex: day.sortIndex,
              },
            });
            count++;
          }
        }
        results.workoutDays = count;
      }

      // Exercises — last-write-wins
      if (exercises?.length) {
        let count = 0;
        for (const ex of exercises) {
          const existing = await prisma.exercise.findUnique({
            where: { id: ex.id },
          });
          const clientUpdated = new Date(ex.updatedAt);

          if (!existing) {
            try {
              await prisma.exercise.create({
                data: {
                  id: ex.id,
                  workoutDayId: ex.workoutDayId,
                  name: ex.name,
                  sortIndex: ex.sortIndex,
                  lastSelectedReps: ex.lastSelectedReps,
                  lastSelectedWeight: ex.lastSelectedWeight,
                  targetSets: ex.targetSets ?? 3,
                  targetWeight: ex.targetWeight ?? 0,
                  repTargetMin: ex.repTargetMin ?? 8,
                  repTargetMax: ex.repTargetMax ?? 12,
                },
              });
              count++;
            } catch {
              // Skip if workout day doesn't exist
            }
          } else if (clientUpdated > existing.updatedAt) {
            await prisma.exercise.update({
              where: { id: ex.id },
              data: {
                name: ex.name,
                sortIndex: ex.sortIndex,
                lastSelectedReps: ex.lastSelectedReps,
                lastSelectedWeight: ex.lastSelectedWeight,
                targetSets: ex.targetSets ?? existing.targetSets,
                targetWeight: ex.targetWeight ?? existing.targetWeight,
                repTargetMin: ex.repTargetMin ?? existing.repTargetMin,
                repTargetMax: ex.repTargetMax ?? existing.repTargetMax,
              },
            });
            count++;
          }
        }
        results.exercises = count;
      }

      // Weekday plans — last-write-wins
      if (weekdayPlans?.length) {
        let count = 0;
        for (const plan of weekdayPlans) {
          await prisma.weekdayPlan.upsert({
            where: {
              userId_weekday: { userId, weekday: plan.weekday },
            },
            update: { workoutDayId: plan.workoutDayId },
            create: {
              userId,
              weekday: plan.weekday,
              workoutDayId: plan.workoutDayId,
            },
          });
          count++;
        }
        results.weekdayPlans = count;
      }

      return { success: true, synced: results };
    }
  );

  fastify.addHook('onClose', async () => {
    await prisma.$disconnect();
  });
}
