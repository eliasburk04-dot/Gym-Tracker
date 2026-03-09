-- Add idempotency metadata columns for workout set sync
ALTER TABLE "WorkoutSet" ADD COLUMN "externalEventId" TEXT;
ALTER TABLE "WorkoutSet" ADD COLUMN "originSessionId" TEXT;

-- Ensure event ids are unique when present
CREATE UNIQUE INDEX "WorkoutSet_externalEventId_key" ON "WorkoutSet"("externalEventId");
