import { createUserWithWorkspace } from "@/db/users";

function isValidEmail(email: string): boolean {
  const at = email.indexOf("@");
  if (at <= 0 || at !== email.lastIndexOf("@")) return false;
  const domain = email.slice(at + 1);
  const dot = domain.lastIndexOf(".");
  return dot > 0 && dot < domain.length - 1 && !email.includes(" ");
}

export async function POST(request: Request): Promise<Response> {
  let body: unknown;
  try {
    body = await request.json();
  } catch {
    return Response.json({ error: "Invalid JSON body" }, { status: 400 });
  }

  if (
    typeof body !== "object" ||
    body === null ||
    !("email" in body) ||
    typeof (body as Record<string, unknown>).email !== "string" ||
    !(body as Record<string, unknown>).email
  ) {
    return Response.json({ error: "email is required" }, { status: 400 });
  }

  if (
    !("name" in body) ||
    typeof (body as Record<string, unknown>).name !== "string" ||
    !(body as Record<string, unknown>).name
  ) {
    return Response.json({ error: "name is required" }, { status: 400 });
  }

  const { email, name } = body as { email: string; name: string };

  if (!isValidEmail(email)) {
    return Response.json({ error: "email format is invalid" }, { status: 400 });
  }

  try {
    const result = await createUserWithWorkspace({ email, name });
    return Response.json(result, { status: 201 });
  } catch {
    return Response.json({ error: "Registration failed" }, { status: 500 });
  }
}
