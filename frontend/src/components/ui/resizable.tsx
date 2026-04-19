import React from "react";
import { GripVertical } from "lucide-react";
import { cn } from "../../lib/utils";

// ---------------- PANEL GROUP ----------------
interface GroupProps {
  children: React.ReactNode[];
  direction?: "horizontal" | "vertical";
  className?: string;
}

const ResizablePanelGroup = ({
  children,
  direction = "horizontal",
  className,
}: GroupProps) => {
  return (
    <div
      className={cn(
        "flex w-full h-full",
        direction === "horizontal" ? "flex-row" : "flex-col",
        className
      )}
    >
      {children}
    </div>
  );
};

// ---------------- PANEL ----------------
const ResizablePanel = ({
  children,
}: {
  children: React.ReactNode;
}) => {
  return <div className="w-full h-full">{children}</div>;
};

// ---------------- HANDLE (OPTIONAL UI ONLY) ----------------
const ResizableHandle = ({
  withHandle,
  className,
}: {
  withHandle?: boolean;
  className?: string;
}) => {
  return (
    <div className={cn("flex items-center justify-center", className)}>
      {withHandle && <GripVertical className="w-4 h-4" />}
    </div>
  );
};

export { ResizablePanelGroup, ResizablePanel, ResizableHandle };