import { describe, it, expect, vi, beforeEach } from "vitest";

// Mock the repository module before importing the route handler
vi.mock("@/db/users", () => ({
  createUserWithWorkspace: vi.fn(),
}));

// Mock the DB client so it never tries to connect
vi.mock("@/db/client", () => ({
  db: {},
}));

import { POST } from "./route";
import { createUserWithWorkspace } from "@/db/users";

const mockCreate = vi.mocked(createUserWithWorkspace);

describe("POST /api/v1/auth/register", () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it("returns 400 when email is missing", async () => {
    const req = new Request("http://localhost/api/v1/auth/register", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ name: "Alice" }),
    });

    const res = await POST(req);

    expect(res.status).toBe(400);
    expect(mockCreate).not.toHaveBeenCalled();
  });

  it("returns 400 when name is missing", async () => {
    const req = new Request("http://localhost/api/v1/auth/register", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ email: "alice@example.com" }),
    });

    const res = await POST(req);

    expect(res.status).toBe(400);
    expect(mockCreate).not.toHaveBeenCalled();
  });

  it("returns 400 when email format is invalid", async () => {
    const req = new Request("http://localhost/api/v1/auth/register", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ email: "not-an-email", name: "Alice" }),
    });

    const res = await POST(req);

    expect(res.status).toBe(400);
    expect(mockCreate).not.toHaveBeenCalled();
  });

  it("calls createUserWithWorkspace and returns 201 for valid input", async () => {
    const fakeUser = {
      id: "00000000-0000-0000-0000-000000000001",
      email: "alice@example.com",
      name: "Alice",
      createdAt: new Date(),
      updatedAt: new Date(),
    };
    const fakeWorkspace = {
      id: "00000000-0000-0000-0000-000000000002",
      name: "Alice's Workspace",
      userId: fakeUser.id,
      createdAt: new Date(),
      updatedAt: new Date(),
    };
    mockCreate.mockResolvedValueOnce({
      user: fakeUser,
      workspace: fakeWorkspace,
    });

    const req = new Request("http://localhost/api/v1/auth/register", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ email: "alice@example.com", name: "Alice" }),
    });

    const res = await POST(req);

    expect(res.status).toBe(201);
    expect(mockCreate).toHaveBeenCalledOnce();
    expect(mockCreate).toHaveBeenCalledWith({
      email: "alice@example.com",
      name: "Alice",
    });
  });
});
