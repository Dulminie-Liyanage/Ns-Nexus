import { useState } from "react";
import { DayPicker } from "react-day-picker";
import "react-day-picker/dist/style.css";

type Props = {
  value: Date | undefined;
  onChange: (date: Date | undefined) => void;
};

export default function DatePicker({ value, onChange }: Props) {
  const [isOpen, setIsOpen] = useState(false);

  const now = new Date();
  const minDate = new Date(now.getTime() + 48 * 60 * 60 * 1000);

  return (
    <div className="relative">
      {/* Input */}
      <input
        readOnly
        value={value ? value.toDateString() : ""}
        onClick={() => setIsOpen(!isOpen)}
        placeholder="Select delivery date"
        className="w-full border border-blue-200 rounded-xl px-4 py-2 focus:outline-none focus:ring-2 focus:ring-blue-[#0a3c75] cursor-pointer"
      />

      {/* Calendar Popup */}
      {isOpen && (
        <div className="absolute z-50 mt-2 bg-white shadow-lg rounded-xl p-4 border border-blue-100">
          <DayPicker
            mode="single"
            selected={value}
            onSelect={(date) => {
              if (date && date >= minDate) {
                onChange(date);
                setIsOpen(false);
              }
            }}
            disabled={{ before: minDate }}
          />

          <p className="text-xs text-red-500 mt-2">
            Minimum 48-hour lead time required
          </p>
        </div>
      )}
    </div>
  );
}