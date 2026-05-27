// Integration tests for GET /api/v1/workspaces/:workspaceId
// These tests run against a real database and are excluded from `npm test`.
// Run with the integration vitest config when a DATABASE_URL is available.

describe("GET /api/v1/workspaces/:workspaceId", () => {
  it.todo("owner receives their workspace");
  it.todo("user requesting another user's workspace receives 403");
});
