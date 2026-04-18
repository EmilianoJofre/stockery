export default function SectionCard({ title, description, action, children, className = "" }) {
  return (
    <section className={`table-card p-4 sm:p-5 ${className}`}>
      <div className="mb-4 flex flex-col gap-3 sm:flex-row sm:items-start sm:justify-between">
        <div>
          <h3 className="section-title">{title}</h3>
          {description ? <p className="mt-2 muted-copy">{description}</p> : null}
        </div>
        {action}
      </div>
      {children}
    </section>
  );
}
