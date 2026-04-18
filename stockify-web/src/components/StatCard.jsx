import { formatCompactNumber, formatCurrency } from "../lib/format";

export default function StatCard({ label, value, type = "number", note, accent = false }) {
  const renderedValue = type === "currency" ? formatCurrency(value) : formatCompactNumber(value);

  return (
    <div className={`surface-card p-4 ${accent ? "bg-ink text-white" : ""}`}>
      <p className={`text-xs font-semibold uppercase tracking-[0.24em] ${accent ? "text-white/70" : "text-muted"}`}>
        {label}
      </p>
      <p className={`mt-3 text-3xl font-semibold tracking-[-0.05em] ${accent ? "text-white" : "text-ink"}`}>
        {renderedValue}
      </p>
      {note ? <p className={`mt-2 text-[13px] ${accent ? "text-white/70" : "text-muted"}`}>{note}</p> : null}
    </div>
  );
}
