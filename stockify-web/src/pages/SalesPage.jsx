import { useEffect, useMemo, useState } from "react";
import EmptyState from "../components/EmptyState";
import Modal from "../components/Modal";
import SectionCard from "../components/SectionCard";
import { useAuth } from "../context/AuthContext";
import { can } from "../lib/permissions";
import { apiRequest } from "../lib/api";
import { formatCurrency, formatDate } from "../lib/format";
import { translateDocumentType, translateSiiStatus } from "../lib/translations";
import { computeTaxBreakdown, DEFAULT_TAX_RATE } from "../lib/tax";

const EMPTY_FORM = {
  store_id: "",
  sold_on: new Date().toISOString().slice(0, 10),
  document_type: "boleta",
  customer_id: "",
  customer_name: "",
  customer_rut: "",
  customer_giro: "",
  issue: true,
  status: "completed",
  notes: "",
  items: [{ product_id: "", quantity: 1, unit_price: "" }],
};

// Una factura debe identificar al receptor; una boleta no.
const REQUIRES_CUSTOMER = ["factura", "factura_exenta"];

export default function SalesPage() {
  const { user } = useAuth();
  const canCreate = can(user, "sales.create");

  const [stores, setStores] = useState([]);
  const [products, setProducts] = useState([]);
  const [customers, setCustomers] = useState([]);
  const [sales, setSales] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [issuingId, setIssuingId] = useState(null);

  const [modalOpen, setModalOpen] = useState(false);
  const [form, setForm] = useState(EMPTY_FORM);
  const [isDirty, setIsDirty] = useState(false);
  const [saving, setSaving] = useState(false);
  const [formError, setFormError] = useState("");

  useEffect(() => { loadPage(); }, []);

  async function loadPage() {
    setLoading(true);
    setError("");
    try {
      const [storesRes, productsRes, salesRes, customersRes] = await Promise.all([
        apiRequest("/api/v1/stores"),
        apiRequest("/api/v1/products"),
        apiRequest("/api/v1/sales"),
        apiRequest("/api/v1/customers"),
      ]);
      setStores(storesRes.stores);
      setProducts(productsRes.products);
      setSales(salesRes.sales);
      setCustomers(customersRes.customers);
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  }

  const productsById = useMemo(
    () => Object.fromEntries(products.map((p) => [String(p.id), p])),
    [products]
  );

  const breakdown = useMemo(
    () => computeTaxBreakdown(form.items, productsById),
    [form.items, productsById]
  );

  const needsCustomer = REQUIRES_CUSTOMER.includes(form.document_type);

  async function handleIssue(sale) {
    if (!window.confirm(
      `Emitir ${translateDocumentType(sale.document_type).toLowerCase()} para ${sale.reference}?\n\n` +
      "Se le asignará un folio y el documento quedará inmutable."
    )) return;

    setIssuingId(sale.id);
    setError("");
    try {
      await apiRequest(`/api/v1/sales/${sale.id}/issue`, { method: "POST" });
      await loadPage();
    } catch (err) {
      setError(err.message);
    } finally {
      setIssuingId(null);
    }
  }

  function patchForm(field, value) {
    setForm((f) => ({ ...f, [field]: value }));
    setIsDirty(true);
  }

  function updateItem(index, field, value) {
    setForm((f) => ({
      ...f,
      items: f.items.map((item, i) => (i === index ? { ...item, [field]: value } : item)),
    }));
    setIsDirty(true);
  }

  function addItem() {
    setForm((f) => ({ ...f, items: [...f.items, { product_id: "", quantity: 1, unit_price: "" }] }));
    setIsDirty(true);
  }

  function removeItem(index) {
    setForm((f) => ({ ...f, items: f.items.filter((_, i) => i !== index) }));
    setIsDirty(true);
  }

  function openModal() {
    const defaultStoreId = stores.length === 1 ? String(stores[0].id) : "";
    setForm({ ...EMPTY_FORM, store_id: defaultStoreId });
    setIsDirty(false);
    setFormError("");
    setModalOpen(true);
  }

  function closeModal() {
    if (isDirty && !window.confirm("¿Salir sin registrar la venta?")) return;
    setModalOpen(false);
    setIsDirty(false);
    setFormError("");
  }

  async function handleSubmit(event) {
    event.preventDefault();
    setSaving(true);
    setFormError("");
    try {
      await apiRequest("/api/v1/sales", {
        method: "POST",
        body: {
          sale: {
            ...form,
            items: form.items.map((item) => ({
              ...item,
              quantity: Number(item.quantity),
              unit_price: item.unit_price ? Number(item.unit_price) : "",
            })),
          },
        },
      });
      setModalOpen(false);
      setIsDirty(false);
      await loadPage();
    } catch (err) {
      setFormError(err.message);
    } finally {
      setSaving(false);
    }
  }

  return (
    <>
      <SectionCard
        title="Historial de ventas"
        description="Órdenes salientes e impacto en inventario."
        action={
          canCreate && (
            <button className="btn-secondary" onClick={openModal} type="button">
              Registrar venta
            </button>
          )
        }
      >
        {error ? <div className="mb-4 rounded-2xl bg-accent/5 px-4 py-3 text-sm text-accent">{error}</div> : null}

        {loading ? (
          <p className="text-sm text-muted">Cargando ventas...</p>
        ) : sales.length ? (
          <div className="overflow-x-auto">
            <table className="min-w-full text-left text-sm">
              <thead className="text-xs uppercase tracking-[0.22em] text-muted">
                <tr>
                  <th className="pb-4">Documento</th>
                  <th className="pb-4">Receptor</th>
                  {stores.length > 1 && <th className="pb-4">Tienda</th>}
                  <th className="pb-4">Fecha</th>
                  <th className="pb-4 text-right">Neto</th>
                  <th className="pb-4 text-right">IVA</th>
                  <th className="pb-4 text-right">Total</th>
                  {canCreate && <th className="pb-4 text-right">Acción</th>}
                </tr>
              </thead>
              <tbody className="divide-y divide-line">
                {sales.map((sale) => (
                  <tr key={sale.id}>
                    <td className="py-4">
                      <div className="flex items-center gap-2">
                        <span className="font-medium text-ink">
                          {translateDocumentType(sale.document_type, { short: true })}
                        </span>
                        {sale.folio ? (
                          <span className="chip border-transparent bg-brand/10 text-brand">
                            N° {sale.folio}
                          </span>
                        ) : (
                          <span className="chip">Sin emitir</span>
                        )}
                      </div>
                      <p className="mt-1 text-sm text-muted">{sale.reference}</p>
                      {sale.issued && (
                        <p className="mt-1 text-xs uppercase tracking-[0.18em] text-muted">
                          {translateSiiStatus(sale.sii_status)}
                        </p>
                      )}
                    </td>
                    <td className="py-4 text-muted">
                      {sale.customer ? (
                        <>
                          <p className="text-ink">{sale.customer.name}</p>
                          {sale.customer.formatted_rut && (
                            <p className="text-sm">{sale.customer.formatted_rut}</p>
                          )}
                        </>
                      ) : (
                        sale.customer_name || "Cliente de mostrador"
                      )}
                    </td>
                    {stores.length > 1 && <td className="py-4 text-muted">{sale.store.name}</td>}
                    <td className="py-4 text-muted">{formatDate(sale.sold_on)}</td>
                    <td className="py-4 text-right text-muted">{formatCurrency(sale.net_amount)}</td>
                    <td className="py-4 text-right text-muted">
                      {formatCurrency(sale.tax_amount)}
                      {sale.exempt_amount > 0 && (
                        <p className="text-xs">+ {formatCurrency(sale.exempt_amount)} exento</p>
                      )}
                    </td>
                    <td className="py-4 text-right font-medium text-ink">{formatCurrency(sale.total_amount)}</td>
                    {canCreate && (
                      <td className="py-4 text-right">
                        {sale.issued ? (
                          <span className="text-xs uppercase tracking-[0.18em] text-muted">Emitido</span>
                        ) : (
                          <button
                            className="btn-ghost h-9 px-4 text-sm"
                            disabled={issuingId === sale.id}
                            onClick={() => handleIssue(sale)}
                            type="button"
                          >
                            {issuingId === sale.id ? "Emitiendo..." : "Emitir"}
                          </button>
                        )}
                      </td>
                    )}
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        ) : (
          <EmptyState
            description="El historial se poblará a medida que registres ventas."
            title="Sin ventas registradas"
          />
        )}
      </SectionCard>

      <Modal open={modalOpen} onClose={closeModal} title="Registrar venta" size="xl">
        <form className="space-y-5" onSubmit={handleSubmit}>
          {formError && (
            <div className="rounded-2xl bg-accent/5 px-4 py-3 text-sm text-accent">{formError}</div>
          )}

          <div className="grid gap-4 sm:grid-cols-2">
            <div>
              <label className="mb-2 block text-sm font-medium text-ink">Tipo de documento</label>
              <select
                className="input-field"
                value={form.document_type}
                onChange={(e) => patchForm("document_type", e.target.value)}
              >
                <option value="boleta">Boleta electrónica</option>
                <option value="factura">Factura electrónica</option>
              </select>
            </div>
            <div>
              <label className="mb-2 block text-sm font-medium text-ink">Fecha de venta</label>
              <input className="input-field" type="date" value={form.sold_on} onChange={(e) => patchForm("sold_on", e.target.value)} />
            </div>
            {stores.length > 1 && (
              <div className="sm:col-span-2">
                <label className="mb-2 block text-sm font-medium text-ink">Tienda</label>
                <select className="input-field" required value={form.store_id} onChange={(e) => patchForm("store_id", e.target.value)}>
                  <option value="">Selecciona una tienda</option>
                  {stores.map((s) => <option key={s.id} value={s.id}>{s.name}</option>)}
                </select>
              </div>
            )}
          </div>

          <div className="rounded-2xl border border-line bg-cloud/50 p-4">
            <div className="mb-3 flex items-center justify-between">
              <label className="text-sm font-medium text-ink">
                Receptor {needsCustomer && <span className="text-accent">*</span>}
              </label>
              {!needsCustomer && <span className="text-xs text-muted">Opcional en boleta</span>}
            </div>

            {customers.length > 0 && (
              <select
                className="input-field mb-2"
                value={form.customer_id}
                onChange={(e) => patchForm("customer_id", e.target.value)}
              >
                <option value="">Cliente nuevo o de mostrador</option>
                {customers.map((c) => (
                  <option key={c.id} value={c.id}>
                    {c.name}{c.formatted_rut ? ` — ${c.formatted_rut}` : ""}
                  </option>
                ))}
              </select>
            )}

            {!form.customer_id && (
              <div className="grid gap-2 sm:grid-cols-2">
                <input
                  className="input-field"
                  placeholder="RUT (ej. 76192083-9)"
                  required={needsCustomer}
                  value={form.customer_rut}
                  onChange={(e) => patchForm("customer_rut", e.target.value)}
                />
                <input
                  className="input-field"
                  placeholder="Razón social o nombre"
                  required={needsCustomer}
                  value={form.customer_name}
                  onChange={(e) => patchForm("customer_name", e.target.value)}
                />
                {needsCustomer && (
                  <input
                    className="input-field sm:col-span-2"
                    placeholder="Giro"
                    value={form.customer_giro}
                    onChange={(e) => patchForm("customer_giro", e.target.value)}
                  />
                )}
              </div>
            )}
          </div>

          <div>
            <div className="mb-3 flex items-center justify-between">
              <label className="text-sm font-medium text-ink">Líneas de venta</label>
              <button className="btn-ghost h-9 px-4 text-sm" onClick={addItem} type="button">
                + Agregar línea
              </button>
            </div>
            <div className="space-y-2">
              {form.items.map((item, index) => (
                <div key={`sale-item-${index}`} className="grid gap-2 rounded-2xl border border-line bg-cloud/60 p-3 md:grid-cols-[1.6fr_0.6fr_0.8fr_auto]">
                  <select
                    className="input-field"
                    value={item.product_id}
                    onChange={(e) => updateItem(index, "product_id", e.target.value)}
                  >
                    <option value="">Producto</option>
                    {products.map((p) => (
                      <option key={p.id} value={p.id}>
                        {p.name} ({p.sku}){p.tax_exempt ? " · exento" : ""}
                      </option>
                    ))}
                  </select>
                  <input
                    className="input-field"
                    min="1"
                    placeholder="Cant."
                    type="number"
                    value={item.quantity}
                    onChange={(e) => updateItem(index, "quantity", e.target.value)}
                  />
                  <input
                    className="input-field"
                    min="0"
                    placeholder="Precio $"
                    step="1"
                    type="number"
                    value={item.unit_price}
                    onChange={(e) => updateItem(index, "unit_price", e.target.value)}
                  />
                  <button
                    className="btn-ghost h-12 px-3 text-sm disabled:opacity-40"
                    disabled={form.items.length === 1}
                    onClick={() => removeItem(index)}
                    type="button"
                  >
                    Quitar
                  </button>
                </div>
              ))}
            </div>
          </div>

          {breakdown.total > 0 && (
            <div className="rounded-2xl border border-brand/30 bg-brand/5 px-4 py-4">
              <p className="mb-3 text-xs font-semibold uppercase tracking-[0.2em] text-muted">
                Desglose tributario
              </p>
              <dl className="space-y-1.5 text-sm">
                <div className="flex justify-between">
                  <dt className="text-muted">Neto</dt>
                  <dd className="font-medium text-ink">{formatCurrency(breakdown.net)}</dd>
                </div>
                <div className="flex justify-between">
                  <dt className="text-muted">IVA ({Math.round(DEFAULT_TAX_RATE * 100)}%)</dt>
                  <dd className="font-medium text-ink">{formatCurrency(breakdown.tax)}</dd>
                </div>
                {breakdown.hasExempt && (
                  <div className="flex justify-between">
                    <dt className="text-muted">Exento de IVA</dt>
                    <dd className="font-medium text-ink">{formatCurrency(breakdown.exempt)}</dd>
                  </div>
                )}
                <div className="flex justify-between border-t border-brand/20 pt-2">
                  <dt className="font-semibold text-ink">Total</dt>
                  <dd className="text-2xl font-semibold tracking-[-0.04em] text-ink">
                    {formatCurrency(breakdown.total)}
                  </dd>
                </div>
              </dl>
              <p className="mt-3 text-xs text-muted">
                Los precios ingresados son brutos (IVA incluido); el neto se deriva del total.
              </p>
            </div>
          )}

          <label className="flex items-start gap-3 rounded-2xl border border-line bg-white px-4 py-3">
            <input
              checked={form.issue}
              className="mt-0.5 h-4 w-4 rounded border-line text-brand focus:ring-brand/30"
              onChange={(e) => patchForm("issue", e.target.checked)}
              type="checkbox"
            />
            <span>
              <span className="text-sm font-medium text-ink">Emitir el documento ahora</span>
              <span className="mt-1 block text-xs text-muted">
                Le asigna folio del CAF vigente y lo deja inmutable. Sin marcar, la venta queda
                registrada como borrador y puedes emitirla después.
              </span>
            </span>
          </label>

          <div>
            <label className="mb-2 block text-sm font-medium text-ink">Notas</label>
            <textarea className="text-area-field" value={form.notes} onChange={(e) => patchForm("notes", e.target.value)} />
          </div>

          <div className="flex gap-3 pt-2">
            <button className="btn-secondary flex-1" disabled={saving} type="submit">
              {saving
                ? "Guardando venta..."
                : form.issue
                  ? `Registrar y emitir ${translateDocumentType(form.document_type, { short: true }).toLowerCase()}`
                  : "Registrar sin emitir"}
            </button>
            <button className="btn-ghost" onClick={closeModal} type="button">Cancelar</button>
          </div>
        </form>
      </Modal>
    </>
  );
}
