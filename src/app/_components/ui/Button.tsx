"use client";

import { type ButtonHTMLAttributes } from "react";
import { Icon, type IconName } from "./Icon";

type ButtonVariant = "default" | "primary" | "ghost" | "danger";
type ButtonSize = "sm" | "md" | "lg";

interface ButtonProps extends ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: ButtonVariant;
  size?: ButtonSize;
  block?: boolean;
}

export function Button({
  variant = "default",
  size = "md",
  block = false,
  className,
  children,
  ...props
}: ButtonProps) {
  const classes = [
    "btn",
    variant !== "default" ? variant : "",
    size !== "md" ? size : "",
    block ? "block" : "",
    className ?? "",
  ]
    .filter(Boolean)
    .join(" ");

  return (
    <button className={classes} {...props}>
      {children}
    </button>
  );
}

interface IconButtonProps extends ButtonHTMLAttributes<HTMLButtonElement> {
  icon: IconName;
  label: string;
  iconSize?: number;
}

export function IconButton({
  icon,
  label,
  iconSize = 16,
  className,
  ...props
}: IconButtonProps) {
  return (
    <button
      type="button"
      className={["btn", "icon", className].filter(Boolean).join(" ")}
      title={label}
      aria-label={label}
      {...props}
    >
      <Icon name={icon} size={iconSize} />
    </button>
  );
}
