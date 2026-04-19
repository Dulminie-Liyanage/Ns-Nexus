import React, { useState } from "react";
import { GripVertical } from "lucide-react";
import { cn } from "../../lib/utils";

interface GroupProps {
  children: React.ReactNode[];
  direction?: "horizontal" | "vertical";
  className?: string;
}

export const ResizablePanelGroup = ({
  children,
  direction = "horizontal",
  className,
}: GroupProps) => {
  const [size, setSize] = useState(50);
  const isHorizontal = direction === "horizontal";

  const handleDrag = (_: React.MouseEvent) => {
    const total = isHorizontal ? window.innerWidth : window.innerHeight;

    const move = (event: MouseEvent) => {
      const current = isHorizontal ? event.clientX : event.clientY;
      const newSize = (current / total) * 100;
      setSize(Math.min(80, Math.max(20, newSize)));
    };

    const stop = () => {
      window.removeEventListener("mousemove", move);
      window.removeEventListener("mouseup", stop);
    };

    window.addEventListener("mousemove", move);
    window.addEventListener("mouseup", stop);
  };

  const [first, second] = children;

  return (
    <div
      className={cn(
        "flex w-full h-full",
        isHorizontal ? "flex-row" : "flex-col",
        className
      )}
    >
      <div style={{ flexBasis: `${size}%` }}>{first}</div>

      <div
        onMouseDown={handleDrag}
        className="flex items-center justify-center bg-border cursor-col-resize w-2"
      >
        <GripVertical className="w-4 h-4" />
      </div>

      <div style={{ flexBasis: `${100 - size}%` }}>{second}</div>
    </div>
  );
};

export const ResizablePanel = ({
  children,
}: {
  children: React.ReactNode;
}) => {
  return <div className="h-full w-full">{children}</div>;
};

export const ResizableHandle = () => null; // not needed anymore