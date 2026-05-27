// Integration tests for GET /api/v1/workspaces/me
// These tests run against a real database and are excluded from `npm test`.
// Run with the integration vitest config when a DATABASE_URL is available.

describe("GET /api/v1/workspaces/me", () => {
  it.todo("authenticated user receives their workspace");
  it.todo("unauthenticated request receives 401");
});
