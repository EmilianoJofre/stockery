export default function BrandMark({ compact = false }) {
  return (
    <div className="flex items-center gap-3">
      <div className="flex h-10 w-10 items-center justify-center rounded-2xl bg-ink">
        <img src="/stockery-mark.svg" alt="Stockery" className="h-7 w-7 object-contain" />
      </div>

      {!compact && (
        <div>
          <p className="text-xs font-semibold uppercase tracking-[0.32em] text-muted">Stockery</p>
          <p className="text-base font-semibold tracking-[-0.04em] text-ink">Sistema operativo retail</p>
        </div>
      )}
    </div>
  );
}
