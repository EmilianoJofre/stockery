import { useDeferredValue, useEffect, useState } from "react";
import EmptyState from "../components/EmptyState";
import SectionCard from "../components/SectionCard";
import { useAuth } from "../context/AuthContext";
import { apiRequest } from "../lib/api";
import { formatCurrency } from "../lib/format";

const EMPTY_FORM = {
  name: "",
  sku: "",
  description: "",
  price: "",
  low_stock_threshold: 10,
  active: true,
};

export default function ProductsPage() {
  const { user } = useAuth();
  const canManage = user?.capabilities?.can_manage_products;
  const [products, setProducts] = useState([]);
  const [search, setSearch] = useState("");
  const [lowStockOnly, setLowStockOnly] = useState(false);
  const [form, setForm] = useState(EMPTY_FORM);
  const [editingId, setEditingId] = useState(null);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState("");
  const deferredSearch = useDeferredValue(search);

  useEffect(() => {
    loadProducts();
  }, [deferredSearch, lowStockOnly]);

  async function loadProducts() {
    setLoading(true);
    setError("");

    try {
      const query = new URLSearchParams();
      if (deferredSearch) {
        query.set("q", deferredSearch);
      }
      if (lowStockOnly) {
        query.set("low_stock", "true");
      }

      const response = await apiRequest(`/api/v1/products${query.toString() ? `?${query}` : ""}`);
      setProducts(response.products);
    } catch (requestError) {
      setError(requestError.message);
    } finally {
      setLoading(false);
    }
  }

  function resetForm() {
    setForm(EMPTY_FORM);
    setEditingId(null);
  }

  function beginEdit(product) {
    setEditingId(product.id);
    setForm({
      name: product.name,
      sku: product.sku,
      description: product.description || "",
      price: product.price,
      low_stock_threshold: product.low_stock_threshold,
      active: product.active,
    });
  }

  async function handleSubmit(event) {
    event.preventDefault();
    setSaving(true);
    setError("");

    try {
      await apiRequest(editingId ? `/api/v1/products/${editingId}` : "/api/v1/products", {
        method: editingId ? "PUT" : "POST",
        body: {
          product: {
            ...form,
            price: Number(form.price),
            low_stock_threshold: Number(form.low_stock_threshold),
          },
        },
      });

      resetForm();
      await loadProducts();
    } catch (submitError) {
      setError(submitError.message);
    } finally {
      setSaving(false);
    }
  }

  async function handleDelete(id) {
    if (!window.confirm("Delete this product?")) {
      return;
    }

    try {
      await apiRequest(`/api/v1/products/${id}`, { method: "DELETE" });
      await loadProducts();
    } catch (deleteError) {
      setError(deleteError.message);
    }
  }

  return (
    <div className="grid gap-6 xl:grid-cols-[1.25fr_0.9fr]">
      <SectionCard
        action={
          <div className="flex flex-wrap gap-3">
            <input
              className="input-field w-[220px]"
              onChange={(event) => setSearch(event.target.value)}
              placeholder="Search name or SKU"
              value={search}
            />
            <button
              className={`btn-ghost ${lowStockOnly ? "border-accent bg-accent/5 text-accent" : ""}`}
              onClick={() => setLowStockOnly((current) => !current)}
              type="button"
            >
              {lowStockOnly ? "Showing low stock" : "Low stock only"}
            </button>
          </div>
        }
        description="Live product catalog with pricing, thresholds, and store visibility."
        title="Products"
      >
        {error ? <div className="mb-4 rounded-2xl bg-accent/5 px-4 py-3 text-sm text-accent">{error}</div> : null}

        {loading ? (
          <p className="text-sm text-muted">Loading products...</p>
        ) : products.length ? (
          <div className="overflow-x-auto">
            <table className="min-w-full text-left text-sm">
              <thead className="text-xs uppercase tracking-[0.22em] text-muted">
                <tr>
                  <th className="pb-4">Product</th>
                  <th className="pb-4">Price</th>
                  <th className="pb-4">Inventory</th>
                  <th className="pb-4">Threshold</th>
                  {canManage ? <th className="pb-4 text-right">Actions</th> : null}
                </tr>
              </thead>
              <tbody className="divide-y divide-line">
                {products.map((product) => (
                  <tr key={product.id}>
                    <td className="py-4 align-top">
                      <p className="font-medium text-ink">{product.name}</p>
                      <p className="mt-1 text-sm text-muted">{product.sku}</p>
                      <div className="mt-3 flex flex-wrap gap-2">
                        {product.store_quantities.map((store) => (
                          <span
                            key={`${product.id}-${store.store_id}`}
                            className={`chip ${store.low_stock ? "chip-alert" : ""}`}
                          >
                            {store.store_name}: {store.quantity}
                          </span>
                        ))}
                      </div>
                    </td>
                    <td className="py-4 align-top text-muted">{formatCurrency(product.price)}</td>
                    <td className="py-4 align-top">
                      <div className="flex items-center gap-2">
                        <span className="text-lg font-semibold text-ink">{product.inventory_total}</span>
                        {product.low_stock ? <span className="chip chip-alert">Alert</span> : null}
                      </div>
                    </td>
                    <td className="py-4 align-top text-muted">{product.low_stock_threshold}</td>
                    {canManage ? (
                      <td className="py-4 align-top">
                        <div className="flex justify-end gap-2">
                          <button className="btn-ghost h-10 px-4" onClick={() => beginEdit(product)} type="button">
                            Edit
                          </button>
                          <button className="btn-primary h-10 bg-accent px-4" onClick={() => handleDelete(product.id)} type="button">
                            Delete
                          </button>
                        </div>
                      </td>
                    ) : null}
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        ) : (
          <EmptyState description="Create your first product to start tracking inventory." title="No products yet" />
        )}
      </SectionCard>

      <SectionCard
        description={
          canManage
            ? "Add new SKUs or update pricing and thresholds."
            : "Your role has read-only access to the product catalog."
        }
        title={editingId ? "Edit Product" : "Product Form"}
      >
        {canManage ? (
          <form className="space-y-4" onSubmit={handleSubmit}>
            <div>
              <label className="mb-2 block text-sm font-medium text-ink">Name</label>
              <input
                className="input-field"
                onChange={(event) => setForm((current) => ({ ...current, name: event.target.value }))}
                value={form.name}
              />
            </div>
            <div>
              <label className="mb-2 block text-sm font-medium text-ink">SKU</label>
              <input
                className="input-field"
                onChange={(event) => setForm((current) => ({ ...current, sku: event.target.value }))}
                value={form.sku}
              />
            </div>
            <div className="grid gap-4 sm:grid-cols-2">
              <div>
                <label className="mb-2 block text-sm font-medium text-ink">Price</label>
                <input
                  className="input-field"
                  min="0"
                  onChange={(event) => setForm((current) => ({ ...current, price: event.target.value }))}
                  step="0.01"
                  type="number"
                  value={form.price}
                />
              </div>
              <div>
                <label className="mb-2 block text-sm font-medium text-ink">Low stock threshold</label>
                <input
                  className="input-field"
                  min="0"
                  onChange={(event) => setForm((current) => ({ ...current, low_stock_threshold: event.target.value }))}
                  type="number"
                  value={form.low_stock_threshold}
                />
              </div>
            </div>
            <div>
              <label className="mb-2 block text-sm font-medium text-ink">Description</label>
              <textarea
                className="text-area-field"
                onChange={(event) => setForm((current) => ({ ...current, description: event.target.value }))}
                value={form.description}
              />
            </div>
            <label className="flex items-center gap-3 text-sm text-muted">
              <input
                checked={form.active}
                onChange={(event) => setForm((current) => ({ ...current, active: event.target.checked }))}
                type="checkbox"
              />
              Product is active
            </label>
            <div className="flex flex-wrap gap-3">
              <button className="btn-secondary" disabled={saving} type="submit">
                {saving ? "Saving..." : editingId ? "Update product" : "Create product"}
              </button>
              <button className="btn-ghost" onClick={resetForm} type="button">
                Reset
              </button>
            </div>
          </form>
        ) : (
          <EmptyState
            description="Admin and Manager accounts can create, update, or remove products."
            title="Read-only access"
          />
        )}
      </SectionCard>
    </div>
  );
}
