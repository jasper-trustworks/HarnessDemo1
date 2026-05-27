import { and, eq } from "drizzle-orm";
import { db } from "./client";
import { workspaces } from "./schema";

export async function getWorkspaceForUser(userId: string) {
  const results = await db
    .select()
    .from(workspaces)
    .where(eq(workspaces.userId, userId))
    .limit(1);

  return results[0];
}

export async function getWorkspaceById(workspaceId: string, userId: string) {
  const results = await db
    .select()
    .from(workspaces)
    .where(and(eq(workspaces.id, workspaceId), eq(workspaces.userId, userId)))
    .limit(1);

  return results[0];
}
