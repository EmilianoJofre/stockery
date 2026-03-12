export default function SectionCard({ title, description, action, children, className = "" }) {
  return (
    <section className={`table-card p-5 sm:p-6 ${className}`}>
      <div className="mb-5 flex flex-col gap-3 sm:flex-row sm:items-start sm:justify-between">
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
