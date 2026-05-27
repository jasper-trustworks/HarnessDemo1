// Stub: Replace with Auth.js integration once ADR-0005 is implemented.
// getRequiredSession() should call auth() from next-auth and derive the session
// from the authenticated user. Until then, all requests will be treated as unauthenticated.

export interface Session {
  userId: string;
  workspaceId: string;
}

export async function getRequiredSession(): Promise<Session> {
  throw new Error("Unauthorized");
}
