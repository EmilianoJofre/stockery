export default function AccessNotice({ title = "Acceso restringido", description }) {
  return (
    <div className="surface-card border border-accent/20 bg-accent/5 p-6">
      <span className="chip chip-alert">Permiso limitado</span>
      <h3 className="mt-4 text-2xl font-semibold tracking-[-0.04em] text-ink">{title}</h3>
      <p className="mt-3 max-w-2xl text-sm leading-6 text-muted">{description}</p>
    </div>
  );
}
