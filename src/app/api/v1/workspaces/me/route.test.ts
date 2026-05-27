import { describe, it, expect, vi, beforeEach } from "vitest";

vi.mock("@/app/_lib/session");
vi.mock("@/db/workspaces");
vi.mock("@/db/client", () => ({ db: {} }));

import { GET } from "./route";
import { getRequiredSession } from "@/app/_lib/session";
import { getWorkspaceForUser } from "@/db/workspaces";

const mockGetRequiredSession = vi.mocked(getRequiredSession);
const mockGetWorkspaceForUser = vi.mocked(getWorkspaceForUser);

describe("GET /api/v1/workspaces/me", () => {
  beforeEach(() => {
    vi.resetAllMocks();
  });

  it("returns 401 when no session is present", async () => {
    mockGetRequiredSession.mockRejectedValue(new Error("Unauthorized"));

    const response = await GET();

    expect(response.status).toBe(401);
  });

  it("returns 200 with workspace data when authenticated and workspace exists", async () => {
    mockGetRequiredSession.mockResolvedValue({
      userId: "test-user-id",
      workspaceId: "test-ws-id",
    });
    mockGetWorkspaceForUser.mockResolvedValue({
      id: "test-ws-id",
      name: "Test Workspace",
      userId: "test-user-id",
      createdAt: new Date("2024-01-01"),
      updatedAt: new Date("2024-01-01"),
    });

    const response = await GET();
    const body = await response.json();

    expect(response.status).toBe(200);
    expect(body).toEqual({ id: "test-ws-id", name: "Test Workspace" });
  });

  it("returns 404 when session is valid but no workspace is found", async () => {
    mockGetRequiredSession.mockResolvedValue({
      userId: "test-user-id",
      workspaceId: "test-ws-id",
    });
    mockGetWorkspaceForUser.mockResolvedValue(undefined);

    const response = await GET();

    expect(response.status).toBe(404);
  });
});
