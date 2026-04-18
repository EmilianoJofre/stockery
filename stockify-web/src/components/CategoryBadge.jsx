import { getIconComponent } from "../lib/categoryIcons";

export default function CategoryBadge({ category }) {
  if (!category) return <span className="text-muted">—</span>;

  const Icon = getIconComponent(category.icon);

  return (
    <span className="chip inline-flex items-center gap-1.5">
      <Icon className="h-3.5 w-3.5 shrink-0" />
      {category.name}
    </span>
  );
}
