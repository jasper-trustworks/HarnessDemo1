import { getRequiredSession } from "@/app/_lib/session";
import { getWorkspaceById } from "@/db/workspaces";

export async function GET(
  _request: Request,
  { params }: { params: Promise<{ workspaceId: string }> }
) {
  let session;
  try {
    session = await getRequiredSession();
  } catch {
    return Response.json({ error: "Unauthorized" }, { status: 401 });
  }

  const { workspaceId } = await params;
  const workspace = await getWorkspaceById(workspaceId, session.userId);

  if (!workspace) {
    return Response.json({ error: "Forbidden" }, { status: 403 });
  }

  return Response.json({ id: workspace.id, name: workspace.name });
}
