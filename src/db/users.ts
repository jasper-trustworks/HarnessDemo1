import { db } from "./client";
import { users, workspaces } from "./schema";

export interface CreateUserWithWorkspaceInput {
  email: string;
  name: string;
}

export interface CreateUserWithWorkspaceResult {
  user: typeof users.$inferSelect;
  workspace: typeof workspaces.$inferSelect;
}

/**
 * Atomically creates a user and their default workspace in a single transaction.
 * If either insert fails the entire transaction is rolled back (REQ-001, REQ-005).
 */
export async function createUserWithWorkspace(
  input: CreateUserWithWorkspaceInput
): Promise<CreateUserWithWorkspaceResult> {
  return db.transaction(async (tx) => {
    const [user] = await tx.insert(users).values(input).returning();

    const workspaceName = `${input.name}'s Workspace`;
    const [workspace] = await tx
      .insert(workspaces)
      .values({ name: workspaceName, userId: user.id })
      .returning();

    return { user, workspace };
  });
}
