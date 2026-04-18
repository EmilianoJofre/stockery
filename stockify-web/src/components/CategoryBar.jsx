import { HiXMark } from "react-icons/hi2";
import { getIconComponent } from "../lib/categoryIcons";

export default function CategoryBar({ categories, selected, onToggle, onClear }) {
  return (
    <div className="flex items-start gap-2 border-t border-line pt-4">
      <div className="flex flex-1 flex-wrap gap-2">
        {categories.map((c) => {
          const Icon = getIconComponent(c.icon);
          const active = selected.includes(String(c.id));
          return (
            <button
              key={c.id}
              type="button"
              onClick={() => onToggle(String(c.id))}
              className={`flex items-center gap-2 rounded-xl border px-3 py-2 text-sm transition-colors ${
                active
                  ? "border-brand bg-brand/8 font-medium text-brand"
                  : "border-line bg-surface text-muted hover:border-brand/30 hover:text-ink"
              }`}
            >
              <Icon className={`h-4 w-4 shrink-0 ${active ? "text-brand" : "text-muted"}`} />
              {c.name}
            </button>
          );
        })}
      </div>
      {selected.length > 0 && (
        <button
          type="button"
          onClick={onClear}
          className="mt-0.5 flex shrink-0 items-center gap-1.5 rounded-lg px-2 py-1.5 text-xs text-muted hover:text-ink"
        >
          <HiXMark className="h-3.5 w-3.5" />
          Limpiar
        </button>
      )}
    </div>
  );
}
