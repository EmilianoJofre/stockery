export default function EmptyState({ title, description }) {
  return (
    <div className="rounded-2xl border border-dashed border-line bg-cloud/60 px-5 py-10 text-center">
      <h4 className="text-lg font-semibold tracking-[-0.03em] text-ink">{title}</h4>
      <p className="mx-auto mt-3 max-w-xl text-[13px] leading-6 text-muted">{description}</p>
    </div>
  );
}
