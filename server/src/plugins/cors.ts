import { FastifyInstance } from 'fastify';
import cors from '@fastify/cors';

export async function corsPlugin(fastify: FastifyInstance): Promise<void> {
  const raw = (process.env.CORS_ORIGIN || '').trim();
  const origin =
    raw.length === 0
      ? false
      : raw === '*'
      ? true
      : raw.split(',').map((value) => value.trim()).filter(Boolean);

  await fastify.register(cors, {
    origin,
    methods: ['GET', 'POST', 'PUT', 'DELETE', 'PATCH'],
    allowedHeaders: ['Content-Type', 'Authorization'],
  });
}
