export default function BrandMark({ compact = false }) {
  return (
    <div className="flex items-center gap-3">
      <div className="flex h-12 w-12 items-center justify-center rounded-2xl bg-ink">
        <img src="/stockify-logo.png" alt="Stockify" className="h-8 w-8 object-contain" />
      </div>

      {!compact && (
        <div>
          <p className="text-xs font-semibold uppercase tracking-[0.32em] text-muted">Stockify</p>
          <p className="text-lg font-semibold tracking-[-0.04em] text-ink">Retail Operating System</p>
        </div>
      )}
    </div>
  );
}
