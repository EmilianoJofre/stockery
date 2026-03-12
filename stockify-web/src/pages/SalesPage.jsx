import { useEffect, useState } from "react";
import EmptyState from "../components/EmptyState";
import SectionCard from "../components/SectionCard";
import { apiRequest } from "../lib/api";
import { formatCurrency, formatDate } from "../lib/format";

const EMPTY_SALE = {
  store_id: "",
  sold_on: new Date().toISOString().slice(0, 10),
  customer_name: "",
  status: "completed",
  notes: "",
  items: [{ product_id: "", quantity: 1, unit_price: "" }],
};

export default function SalesPage() {
  const [stores, setStores] = useState([]);
  const [products, setProducts] = useState([]);
  const [sales, setSales] = useState([]);
  const [form, setForm] = useState(EMPTY_SALE);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState("");

  useEffect(() => {
    loadPage();
  }, []);

  async function loadPage() {
    setLoading(true);
    setError("");

    try {
      const [storeResponse, productResponse, salesResponse] = await Promise.all([
        apiRequest("/api/v1/stores"),
        apiRequest("/api/v1/products"),
        apiRequest("/api/v1/sales"),
      ]);

      setStores(storeResponse.stores);
      setProducts(productResponse.products);
      setSales(salesResponse.sales);
    } catch (requestError) {
      setError(requestError.message);
    } finally {
      setLoading(false);
    }
  }

  function updateSaleItem(index, field, value) {
    setForm((current) => ({
      ...current,
      items: current.items.map((item, itemIndex) =>
        itemIndex === index ? { ...item, [field]: value } : item
      ),
    }));
  }

  function addSaleItem() {
    setForm((current) => ({
      ...current,
      items: [...current.items, { product_id: "", quantity: 1, unit_price: "" }],
    }));
  }

  function removeSaleItem(index) {
    setForm((current) => ({
      ...current,
      items: current.items.filter((_, itemIndex) => itemIndex !== index),
    }));
  }

  async function saveSale(event) {
    event.preventDefault();
    setSaving(true);
    setError("");

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

      setForm(EMPTY_SALE);
      await loadPage();
    } catch (submitError) {
      setError(submitError.message);
    } finally {
      setSaving(false);
    }
  }

  return (
    <div className="grid gap-6 xl:grid-cols-[1fr_1.05fr]">
      <SectionCard description="Capture outbound orders and decrease inventory in the same transaction." title="Create Sale">
        {error ? <div className="mb-4 rounded-2xl bg-accent/5 px-4 py-3 text-sm text-accent">{error}</div> : null}

        <form className="space-y-4" onSubmit={saveSale}>
          <div className="grid gap-4 md:grid-cols-2">
            <div>
              <label className="mb-2 block text-sm font-medium text-ink">Store</label>
              <select
                className="input-field"
                onChange={(event) => setForm((current) => ({ ...current, store_id: event.target.value }))}
                value={form.store_id}
              >
                <option value="">Select store</option>
                {stores.map((store) => (
                  <option key={store.id} value={store.id}>
                    {store.name}
                  </option>
                ))}
              </select>
            </div>
            <div>
              <label className="mb-2 block text-sm font-medium text-ink">Sold on</label>
              <input
                className="input-field"
                onChange={(event) => setForm((current) => ({ ...current, sold_on: event.target.value }))}
                type="date"
                value={form.sold_on}
              />
            </div>
          </div>
          <div>
            <label className="mb-2 block text-sm font-medium text-ink">Customer name</label>
            <input
              className="input-field"
              onChange={(event) => setForm((current) => ({ ...current, customer_name: event.target.value }))}
              placeholder="Optional"
              value={form.customer_name}
            />
          </div>

          <div className="space-y-3">
            {form.items.map((item, index) => (
              <div key={`sale-item-${index}`} className="rounded-2xl border border-line bg-cloud/70 p-4">
                <div className="grid gap-4 md:grid-cols-[1.6fr_0.7fr_0.8fr_auto]">
                  <select
                    className="input-field"
                    onChange={(event) => updateSaleItem(index, "product_id", event.target.value)}
                    value={item.product_id}
                  >
                    <option value="">Select product</option>
                    {products.map((product) => (
                      <option key={product.id} value={product.id}>
                        {product.name} ({product.sku})
                      </option>
                    ))}
                  </select>
                  <input
                    className="input-field"
                    min="1"
                    onChange={(event) => updateSaleItem(index, "quantity", event.target.value)}
                    placeholder="Qty"
                    type="number"
                    value={item.quantity}
                  />
                  <input
                    className="input-field"
                    min="0"
                    onChange={(event) => updateSaleItem(index, "unit_price", event.target.value)}
                    placeholder="Price"
                    step="0.01"
                    type="number"
                    value={item.unit_price}
                  />
                  <button
                    className="btn-ghost"
                    disabled={form.items.length === 1}
                    onClick={() => removeSaleItem(index)}
                    type="button"
                  >
                    Remove
                  </button>
                </div>
              </div>
            ))}
          </div>

          <div className="flex flex-wrap gap-3">
            <button className="btn-ghost" onClick={addSaleItem} type="button">
              Add line item
            </button>
          </div>

          <div>
            <label className="mb-2 block text-sm font-medium text-ink">Notes</label>
            <textarea
              className="text-area-field"
              onChange={(event) => setForm((current) => ({ ...current, notes: event.target.value }))}
              value={form.notes}
            />
          </div>
          <button className="btn-secondary w-full" disabled={saving} type="submit">
            {saving ? "Saving sale..." : "Record sale"}
          </button>
        </form>
      </SectionCard>

      <SectionCard description="Recent orders and their commercial value." title="Sales History">
        {loading ? (
          <p className="text-sm text-muted">Loading sales...</p>
        ) : sales.length ? (
          <div className="overflow-x-auto">
            <table className="min-w-full text-left text-sm">
              <thead className="text-xs uppercase tracking-[0.22em] text-muted">
                <tr>
                  <th className="pb-4">Reference</th>
                  <th className="pb-4">Customer</th>
                  <th className="pb-4">Store</th>
                  <th className="pb-4">Date</th>
                  <th className="pb-4 text-right">Total</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-line">
                {sales.map((sale) => (
                  <tr key={sale.id}>
                    <td className="py-4 font-medium text-ink">{sale.reference}</td>
                    <td className="py-4 text-muted">{sale.customer_name || "Walk-in customer"}</td>
                    <td className="py-4 text-muted">{sale.store.name}</td>
                    <td className="py-4 text-muted">{formatDate(sale.sold_on)}</td>
                    <td className="py-4 text-right font-medium text-ink">{formatCurrency(sale.total_amount)}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        ) : (
          <EmptyState description="Sales history will populate as orders are recorded." title="No sales recorded" />
        )}
      </SectionCard>
    </div>
  );
}
