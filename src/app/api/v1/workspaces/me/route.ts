import { getRequiredSession } from "@/app/_lib/session";
import { getWorkspaceForUser } from "@/db/workspaces";

export async function GET() {
  let session;
  try {
    session = await getRequiredSession();
  } catch {
    return Response.json({ error: "Unauthorized" }, { status: 401 });
  }

  const workspace = await getWorkspaceForUser(session.userId);

  if (!workspace) {
    return Response.json({ error: "Not found" }, { status: 404 });
  }

  return Response.json({ id: workspace.id, name: workspace.name });
}
