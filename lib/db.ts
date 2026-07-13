import { Pool } from "pg";

/**
 * Database access.
 *
 * DATABASE_URL must connect as the `lifebook_app` role, which holds
 * INSERT/SELECT only on the entrusted schema (db/migrations/0002_privileges.sql).
 * The privileged deletion path uses a separate connection and role and does
 * not exist in application code by design.
 */

let pool: Pool | null = null;

export function db(): Pool {
  if (!pool) {
    const url = process.env.DATABASE_URL;
    if (!url) {
      throw new Error("DATABASE_URL is not set");
    }
    pool = new Pool({ connectionString: url, max: 10 });
  }
  return pool;
}

export async function withTransaction<T>(
  fn: (client: import("pg").PoolClient) => Promise<T>,
): Promise<T> {
  const client = await db().connect();
  try {
    await client.query("begin");
    const result = await fn(client);
    await client.query("commit");
    return result;
  } catch (error) {
    await client.query("rollback");
    throw error;
  } finally {
    client.release();
  }
}
