export default function EmptyState({ title, description }) {
  return (
    <div className="rounded-2xl border border-dashed border-line bg-cloud/60 px-6 py-12 text-center">
      <h4 className="text-xl font-semibold tracking-[-0.03em] text-ink">{title}</h4>
      <p className="mx-auto mt-3 max-w-xl text-sm leading-6 text-muted">{description}</p>
    </div>
  );
}
