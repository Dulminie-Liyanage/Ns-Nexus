import * as React from "react";
import * as RechartsPrimitive from "recharts";

import { cn } from "@/lib/utils";

// Format: { THEME_NAME: CSS_SELECTOR }
const THEMES = { light: "", dark: ".dark" } as const;

export type ChartConfig = {
  [k in string]: {
    label?: React.ReactNode;
    icon?: React.ComponentType;
  } & (
    | { color?: string; theme?: never }
    | { color?: never; theme: Record<keyof typeof THEMES, string> }
  );
};

type ChartContextProps = {
  config: ChartConfig;
};

const ChartContext = React.createContext<ChartContextProps | null>(null);

function useChart() {
  const context = React.useContext(ChartContext);
  if (!context) {
    throw new Error("useChart must be used within a <ChartContainer />");
  }
  return context;
}

/* ---------------- CONTAINER ---------------- */

const ChartContainer = ({
  id,
  className,
  children,
  config,
  ...props
}: React.ComponentProps<"div"> & {
  config: ChartConfig;
  children: React.ReactNode;
}) => {
  const uniqueId = React.useId();
  const chartId = `chart-${id || uniqueId.replace(/:/g, "")}`;

  return (
    <ChartContext.Provider value={{ config }}>
      <div
        data-chart={chartId}
        className={cn("flex aspect-video justify-center text-xs", className)}
        {...props}
      >
        <ChartStyle id={chartId} config={config} />
        <RechartsPrimitive.ResponsiveContainer>
          {children}
        </RechartsPrimitive.ResponsiveContainer>
      </div>
    </ChartContext.Provider>
  );
};

/* ---------------- STYLE ---------------- */

const ChartStyle = ({
  id,
  config,
}: {
  id: string;
  config: ChartConfig;
}) => {
  const colorConfig = Object.entries(config).filter(
    ([_, c]) => c.theme || c.color
  );

  if (!colorConfig.length) return null;

  return (
    <style
      dangerouslySetInnerHTML={{
        __html: Object.entries(THEMES)
          .map(
            ([theme, prefix]) => `
${prefix} [data-chart=${id}] {
${colorConfig
  .map(([key, itemConfig]) => {
    const color =
      itemConfig.theme?.[theme as keyof typeof itemConfig.theme] ||
      itemConfig.color;
    return color ? `--color-${key}: ${color};` : null;
  })
  .join("\n")}
}`
          )
          .join("\n"),
      }}
    />
  );
};

/* ---------------- TOOLTIP ---------------- */

const ChartTooltip = RechartsPrimitive.Tooltip;

const ChartTooltipContent = (props: any) => {
  const {
    active,
    payload,
    label,
    className,
    hideLabel = false,
    hideIndicator = false,
    formatter,
    nameKey,
  } = props;

  const { config } = useChart();

  if (!active || !payload?.length) return null;

  return (
    <div
      className={cn(
        "grid min-w-[8rem] gap-1.5 rounded-lg border p-2 text-xs shadow-xl bg-background",
        className
      )}
    >
      {!hideLabel && label && (
        <div className="font-medium">{label}</div>
      )}

      <div className="grid gap-1.5">
        {payload.map((item: any, index: number) => {
          const key = `${nameKey || item.name || item.dataKey || "value"}`;
          const itemConfig = config[key];

          const indicatorColor =
            item.payload?.fill || item.color;

          return (
            <div key={index} className="flex justify-between gap-2">
              <div className="flex items-center gap-2">
                {!hideIndicator && (
                  <div
                    className="h-2.5 w-2.5 rounded"
                    style={{ backgroundColor: indicatorColor }}
                  />
                )}
                <span>
                  {itemConfig?.label || item.name}
                </span>
              </div>

              <span className="font-mono">
                {formatter
                  ? formatter(
                      item.value,
                      item.name,
                      item,
                      index,
                      item.payload
                    )
                  : item.value}
              </span>
            </div>
          );
        })}
      </div>
    </div>
  );
};

/* ---------------- LEGEND ---------------- */

const ChartLegend = RechartsPrimitive.Legend;

const ChartLegendContent = ({
  className,
  payload,
  verticalAlign = "bottom",
  hideIcon,
  nameKey,
}: {
  className?: string;
  payload?: any[];
  verticalAlign?: "top" | "bottom" | "middle";
  hideIcon?: boolean;
  nameKey?: string;
}) => {
  const { config } = useChart();

  if (!payload?.length) return null;

  return (
    <div
      className={cn(
        "flex items-center justify-center gap-4",
        verticalAlign === "top" ? "pb-3" : "pt-3",
        className
      )}
    >
      {payload.map((item: any, index: number) => {
        const key = `${nameKey || item.dataKey || "value"}`;
        const itemConfig = config[key];

        return (
          <div key={index} className="flex items-center gap-1.5">
            {!hideIcon && (
              <div
                className="h-2 w-2 rounded"
                style={{ backgroundColor: item.color }}
              />
            )}
            {itemConfig?.label}
          </div>
        );
      })}
    </div>
  );
};

/* ---------------- EXPORTS ---------------- */

export {
  ChartContainer,
  ChartTooltip,
  ChartTooltipContent,
  ChartLegend,
  ChartLegendContent,
  ChartStyle,
};
