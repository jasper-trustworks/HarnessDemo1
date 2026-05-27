"use client";

import { Icon } from "./Icon";

interface CheckboxProps {
  done: boolean;
  onChange?: (done: boolean) => void;
  size?: number;
}

export function Checkbox({ done, onChange, size = 18 }: CheckboxProps) {
  return (
    <button
      type="button"
      className={`checkbox${done ? " done" : ""}`}
      style={{ width: size, height: size }}
      onClick={(e) => {
        e.stopPropagation();
        onChange?.(! done);
      }}
      aria-pressed={done}
      aria-label={done ? "Mark incomplete" : "Mark complete"}
    >
      {done && <Icon name="check" size={Math.round(size * 0.6)} stroke={2} />}
    </button>
  );
}
