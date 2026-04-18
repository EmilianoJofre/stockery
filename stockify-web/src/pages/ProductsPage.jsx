import { useDeferredValue, useEffect, useState } from "react";
import EmptyState from "../components/EmptyState";
import SectionCard from "../components/SectionCard";
import { useAuth } from "../context/AuthContext";
import { can } from "../lib/permissions";
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
  const canManage = can(user, "products.create");
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
    if (!window.confirm("¿Eliminar este producto?")) {
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
              placeholder="Buscar por nombre o SKU"
              value={search}
            />
            <button
              className={`btn-ghost ${lowStockOnly ? "border-accent bg-accent/5 text-accent" : ""}`}
              onClick={() => setLowStockOnly((current) => !current)}
              type="button"
            >
              {lowStockOnly ? "Mostrando stock bajo" : "Solo stock bajo"}
            </button>
          </div>
        }
        description="Catalogo vivo de productos con precios, umbrales y visibilidad por tienda."
        title="Productos"
      >
        {error ? <div className="mb-4 rounded-2xl bg-accent/5 px-4 py-3 text-sm text-accent">{error}</div> : null}

        {loading ? (
          <p className="text-sm text-muted">Cargando productos...</p>
        ) : products.length ? (
          <div className="overflow-x-auto">
            <table className="min-w-full text-left text-sm">
              <thead className="text-xs uppercase tracking-[0.22em] text-muted">
                <tr>
                  <th className="pb-4">Producto</th>
                  <th className="pb-4">Precio</th>
                  <th className="pb-4">Inventario</th>
                  <th className="pb-4">Umbral</th>
                  {canManage ? <th className="pb-4 text-right">Acciones</th> : null}
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
                        {product.low_stock ? <span className="chip chip-alert">Alerta</span> : null}
                      </div>
                    </td>
                    <td className="py-4 align-top text-muted">{product.low_stock_threshold}</td>
                    {canManage ? (
                      <td className="py-4 align-top">
                        <div className="flex justify-end gap-2">
                          <button className="btn-ghost h-10 px-4" onClick={() => beginEdit(product)} type="button">
                            Editar
                          </button>
                          <button className="btn-primary h-10 bg-accent px-4" onClick={() => handleDelete(product.id)} type="button">
                            Eliminar
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
          <EmptyState description="Crea tu primer producto para comenzar a controlar inventario." title="Aun no hay productos" />
        )}
      </SectionCard>

      <SectionCard
        description={
          canManage
            ? "Agrega nuevos SKU o actualiza precios y umbrales."
            : "Tu rol tiene acceso de solo lectura al catalogo de productos."
        }
        title={editingId ? "Editar producto" : "Formulario de producto"}
      >
        {canManage ? (
          <form className="space-y-4" onSubmit={handleSubmit}>
            <div>
              <label className="mb-2 block text-sm font-medium text-ink">Nombre</label>
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
                <label className="mb-2 block text-sm font-medium text-ink">Precio</label>
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
                <label className="mb-2 block text-sm font-medium text-ink">Umbral de stock bajo</label>
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
              <label className="mb-2 block text-sm font-medium text-ink">Descripcion</label>
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
              Producto activo
            </label>
            <div className="flex flex-wrap gap-3">
              <button className="btn-secondary" disabled={saving} type="submit">
                {saving ? "Guardando..." : editingId ? "Actualizar producto" : "Crear producto"}
              </button>
              <button className="btn-ghost" onClick={resetForm} type="button">
                Limpiar
              </button>
            </div>
          </form>
        ) : (
          <EmptyState
            description="Las cuentas Administrador y Gerente pueden crear, actualizar o eliminar productos."
            title="Acceso de solo lectura"
          />
        )}
      </SectionCard>
    </div>
  );
}
