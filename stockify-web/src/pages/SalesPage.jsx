import { useEffect, useMemo, useState } from "react";
import EmptyState from "../components/EmptyState";
import Modal from "../components/Modal";
import SectionCard from "../components/SectionCard";
import { useAuth } from "../context/AuthContext";
import { can } from "../lib/permissions";
import { apiRequest } from "../lib/api";
import { formatCurrency, formatDate } from "../lib/format";

const EMPTY_FORM = {
  store_id: "",
  sold_on: new Date().toISOString().slice(0, 10),
  customer_name: "",
  status: "completed",
  notes: "",
  items: [{ product_id: "", quantity: 1, unit_price: "" }],
};

export default function SalesPage() {
  const { user } = useAuth();
  const canCreate = can(user, "sales.create");

  const [stores, setStores] = useState([]);
  const [products, setProducts] = useState([]);
  const [sales, setSales] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");

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
      const [storesRes, productsRes, salesRes] = await Promise.all([
        apiRequest("/api/v1/stores"),
        apiRequest("/api/v1/products"),
        apiRequest("/api/v1/sales"),
      ]);
      setStores(storesRes.stores);
      setProducts(productsRes.products);
      setSales(salesRes.sales);
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  }

  const liveTotal = useMemo(
    () => form.items.reduce((sum, item) => sum + (Number(item.unit_price) || 0) * (Number(item.quantity) || 0), 0),
    [form.items]
  );

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
    setForm(EMPTY_FORM);
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
                  <th className="pb-4">Referencia</th>
                  <th className="pb-4">Cliente</th>
                  <th className="pb-4">Tienda</th>
                  <th className="pb-4">Fecha</th>
                  <th className="pb-4 text-right">Total</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-line">
                {sales.map((sale) => (
                  <tr key={sale.id}>
                    <td className="py-4 font-medium text-ink">{sale.reference}</td>
                    <td className="py-4 text-muted">{sale.customer_name || "Cliente de mostrador"}</td>
                    <td className="py-4 text-muted">{sale.store.name}</td>
                    <td className="py-4 text-muted">{formatDate(sale.sold_on)}</td>
                    <td className="py-4 text-right font-medium text-ink">{formatCurrency(sale.total_amount)}</td>
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
              <label className="mb-2 block text-sm font-medium text-ink">Tienda</label>
              <select className="input-field" required value={form.store_id} onChange={(e) => patchForm("store_id", e.target.value)}>
                <option value="">Selecciona una tienda</option>
                {stores.map((s) => <option key={s.id} value={s.id}>{s.name}</option>)}
              </select>
            </div>
            <div>
              <label className="mb-2 block text-sm font-medium text-ink">Fecha de venta</label>
              <input className="input-field" type="date" value={form.sold_on} onChange={(e) => patchForm("sold_on", e.target.value)} />
            </div>
          </div>

          <div>
            <label className="mb-2 block text-sm font-medium text-ink">Cliente</label>
            <input
              className="input-field"
              placeholder="Opcional"
              value={form.customer_name}
              onChange={(e) => patchForm("customer_name", e.target.value)}
            />
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
                    {products.map((p) => <option key={p.id} value={p.id}>{p.name} ({p.sku})</option>)}
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

          {liveTotal > 0 && (
            <div className="rounded-2xl border border-brand/30 bg-brand/5 px-4 py-3">
              <p className="text-sm text-muted">Total estimado</p>
              <p className="text-2xl font-semibold tracking-[-0.04em] text-ink">{formatCurrency(liveTotal)}</p>
            </div>
          )}

          <div>
            <label className="mb-2 block text-sm font-medium text-ink">Notas</label>
            <textarea className="text-area-field" value={form.notes} onChange={(e) => patchForm("notes", e.target.value)} />
          </div>

          <div className="flex gap-3 pt-2">
            <button className="btn-secondary flex-1" disabled={saving} type="submit">
              {saving ? "Guardando venta..." : "Registrar venta"}
            </button>
            <button className="btn-ghost" onClick={closeModal} type="button">Cancelar</button>
          </div>
        </form>
      </Modal>
    </>
  );
}
