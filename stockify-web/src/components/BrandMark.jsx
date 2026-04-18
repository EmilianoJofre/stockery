export default function BrandMark({ compact = false }) {
  return (
    <div className="flex items-center gap-3">
      <img
        src="/stockery-mark.svg"
        alt="Stockery"
        className={compact ? "h-10 w-10 shrink-0 object-contain" : "h-11 w-11 shrink-0 object-contain"}
      />

      {!compact && (
        <div>
          <p className="text-xs font-semibold uppercase tracking-[0.32em] text-muted">Stockery</p>
          <p className="text-base font-semibold tracking-[-0.04em] text-ink">Sistema operativo retail</p>
        </div>
      )}
    </div>
  );
}
