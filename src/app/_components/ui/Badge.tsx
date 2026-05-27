type BadgeTone =
  | "default"
  | "cobalt"
  | "coral"
  | "success"
  | "warn"
  | "danger"
  | "ink"
  | "outline";

interface BadgeProps {
  tone?: BadgeTone;
  square?: boolean;
  dot?: boolean;
  children: React.ReactNode;
  style?: React.CSSProperties;
}

export function Badge({
  tone = "default",
  square = false,
  dot = false,
  children,
  style,
}: BadgeProps) {
  const cls = ["chip", tone !== "default" ? tone : "", square ? "sq" : ""]
    .filter(Boolean)
    .join(" ");

  return (
    <span className={cls} style={style}>
      {dot && <span className="dot" />}
      {children}
    </span>
  );
}
