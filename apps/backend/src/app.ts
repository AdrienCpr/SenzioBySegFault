import Fastify, { type FastifyInstance } from 'fastify';

/**
 * Construit l'application Fastify (sans la démarrer) pour pouvoir la tester.
 * Les modules métier (src/modules/*) seront enregistrés ici au fil des tickets.
 */
export function buildApp(): FastifyInstance {
  const app = Fastify({ logger: process.env.NODE_ENV !== 'test' });

  app.get('/health', async () => ({ status: 'ok' }));

  return app;
}
