import * as React from "react";
import { ChevronLeft, ChevronRight } from "lucide-react";
import { DayPicker, DayPickerProps, CustomComponents } from "react-day-picker";

import { cn } from "@/lib/utils";
import { buttonVariants } from "@/components/ui/button";

// Extend CustomComponents to allow IconPrevious and IconNext
interface MyComponents extends CustomComponents {
  IconPrevious?: React.FC<any>;
  IconNext?: React.FC<any>;
}

export type CalendarProps = DayPickerProps;

function Calendar({
  className,
  classNames,
  showOutsideDays = true,
  ...props
}: CalendarProps) {
  return (
    <DayPicker
      showOutsideDays={showOutsideDays}
      className={cn("p-3", className)}
      classNames={{
        /* your classNames here */
        ...classNames,
      }}
      // Cast components to our extended type
      components={{
        IconPrevious: (props) => <ChevronLeft {...props} className="h-4 w-4" />,
        IconNext: (props) => <ChevronRight {...props} className="h-4 w-4" />,
      } as MyComponents}
      {...props}
    />
  );
}

Calendar.displayName = "Calendar";

export { Calendar };
