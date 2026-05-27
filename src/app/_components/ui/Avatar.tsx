const AVATAR_COLORS = [
  "#6E5C49",
  "#4D5E78",
  "#786049",
  "#3F6354",
  "#6B4E60",
  "#5A4E78",
  "#7A5C49",
  "#3F5E78",
];

function colorFor(name: string): string {
  let h = 0;
  for (const c of name) h = ((h << 5) - h + c.charCodeAt(0)) | 0;
  return AVATAR_COLORS[Math.abs(h) % AVATAR_COLORS.length];
}

function initials(name: string): string {
  return name
    .split(" ")
    .map((p) => p[0])
    .slice(0, 2)
    .join("")
    .toUpperCase();
}

type AvatarSize = "sm" | "md" | "lg" | "xl";

interface AvatarProps {
  name: string;
  size?: AvatarSize;
  active?: boolean;
  style?: React.CSSProperties;
}

const sizeClass: Record<AvatarSize, string> = {
  sm: "",
  md: "",
  lg: "lg",
  xl: "xl",
};

export function Avatar({ name, size = "md", active = false, style }: AvatarProps) {
  const cls = ["avatar", sizeClass[size], active ? "active" : ""]
    .filter(Boolean)
    .join(" ");
  return (
    <span className={cls} style={{ background: colorFor(name), ...style }}>
      {initials(name)}
    </span>
  );
}

interface AvatarStackProps {
  people: { id: string; name: string }[];
  max?: number;
  activeId?: string;
}

export function AvatarStack({ people, max = 5, activeId }: AvatarStackProps) {
  const shown = people.slice(0, max);
  const extra = Math.max(0, people.length - max);
  return (
    <div className="avatar-stack">
      {shown.map((p) => (
        <Avatar key={p.id} name={p.name} active={p.id === activeId} />
      ))}
      {extra > 0 && (
        <span
          className="avatar"
          style={{ background: "var(--ink-9)", color: "var(--ink-4)" }}
        >
          +{extra}
        </span>
      )}
    </div>
  );
}
