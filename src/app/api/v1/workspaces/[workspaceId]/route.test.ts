import { describe, it, expect, vi, beforeEach } from "vitest";

vi.mock("@/app/_lib/session");
vi.mock("@/db/workspaces");
vi.mock("@/db/client", () => ({ db: {} }));

import { GET } from "./route";
import { getRequiredSession } from "@/app/_lib/session";
import { getWorkspaceById } from "@/db/workspaces";

const mockGetRequiredSession = vi.mocked(getRequiredSession);
const mockGetWorkspaceById = vi.mocked(getWorkspaceById);

function makeParams(workspaceId: string): {
  params: Promise<{ workspaceId: string }>;
} {
  return { params: Promise.resolve({ workspaceId }) };
}

describe("GET /api/v1/workspaces/:workspaceId", () => {
  beforeEach(() => {
    vi.resetAllMocks();
  });

  it("returns 401 when no session is present", async () => {
    mockGetRequiredSession.mockRejectedValue(new Error("Unauthorized"));

    const response = await GET(
      new Request("http://localhost/api/v1/workspaces/some-id"),
      makeParams("some-id")
    );

    expect(response.status).toBe(401);
  });

  it("returns 200 with workspace data when authenticated and workspace belongs to user", async () => {
    mockGetRequiredSession.mockResolvedValue({
      userId: "user-a",
      workspaceId: "ws-a",
    });
    mockGetWorkspaceById.mockResolvedValue({
      id: "ws-a",
      name: "User A Workspace",
      userId: "user-a",
      createdAt: new Date("2024-01-01"),
      updatedAt: new Date("2024-01-01"),
    });

    const response = await GET(
      new Request("http://localhost/api/v1/workspaces/ws-a"),
      makeParams("ws-a")
    );
    const body = await response.json();

    expect(response.status).toBe(200);
    expect(body).toEqual({ id: "ws-a", name: "User A Workspace" });
  });

  it("returns 403 when workspace does not belong to the authenticated user", async () => {
    mockGetRequiredSession.mockResolvedValue({
      userId: "user-a",
      workspaceId: "ws-a",
    });
    // getWorkspaceById returns undefined — workspace either doesn't exist or belongs to another user
    mockGetWorkspaceById.mockResolvedValue(undefined);

    const response = await GET(
      new Request("http://localhost/api/v1/workspaces/ws-b"),
      makeParams("ws-b")
    );

    expect(response.status).toBe(403);
  });
});
