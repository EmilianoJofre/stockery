import { useDeferredValue, useEffect, useState } from "react";
import EmptyState from "../components/EmptyState";
import Modal from "../components/Modal";
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
  product_category_id: "",
};

export default function ProductsPage() {
  const { user } = useAuth();
  const canCreate = can(user, "products.create");
  const canDelete = can(user, "products.delete");

  const [products, setProducts] = useState([]);
  const [categories, setCategories] = useState([]);
  const [search, setSearch] = useState("");
  const [lowStockOnly, setLowStockOnly] = useState(false);
  const [categoryFilter, setCategoryFilter] = useState("");
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const deferredSearch = useDeferredValue(search);

  const [modalOpen, setModalOpen] = useState(false);
  const [editingProduct, setEditingProduct] = useState(null);
  const [form, setForm] = useState(EMPTY_FORM);
  const [isDirty, setIsDirty] = useState(false);
  const [saving, setSaving] = useState(false);
  const [formError, setFormError] = useState("");

  useEffect(() => { loadCategories(); }, []);
  useEffect(() => { loadProducts(); }, [deferredSearch, lowStockOnly, categoryFilter]);

  async function loadCategories() {
    try {
      const response = await apiRequest("/api/v1/product_categories");
      setCategories(response.product_categories);
    } catch {
      // non-critical, fail silently
    }
  }

  async function loadProducts() {
    setLoading(true);
    setError("");
    try {
      const query = new URLSearchParams();
      if (deferredSearch) query.set("q", deferredSearch);
      if (lowStockOnly) query.set("low_stock", "true");
      if (categoryFilter) query.set("category_id", categoryFilter);
      const response = await apiRequest(`/api/v1/products${query.toString() ? `?${query}` : ""}`);
      setProducts(response.products);
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  }

  function patch(field, value) {
    setForm((f) => ({ ...f, [field]: value }));
    setIsDirty(true);
  }

  function openCreate() {
    setEditingProduct(null);
    setForm(EMPTY_FORM);
    setIsDirty(false);
    setFormError("");
    setModalOpen(true);
  }

  function openEdit(product) {
    setEditingProduct(product);
    setForm({
      name: product.name,
      sku: product.sku,
      description: product.description || "",
      price: product.price,
      low_stock_threshold: product.low_stock_threshold,
      active: product.active,
      product_category_id: product.product_category_id ?? "",
    });
    setIsDirty(false);
    setFormError("");
    setModalOpen(true);
  }

  function closeModal() {
    if (isDirty && !window.confirm("¿Salir sin guardar los cambios?")) return;
    setModalOpen(false);
    setEditingProduct(null);
    setIsDirty(false);
    setFormError("");
  }

  async function handleSubmit(event) {
    event.preventDefault();
    setSaving(true);
    setFormError("");
    try {
      await apiRequest(
        editingProduct ? `/api/v1/products/${editingProduct.id}` : "/api/v1/products",
        {
          method: editingProduct ? "PUT" : "POST",
          body: {
            product: {
              ...form,
              price: Number(form.price),
              low_stock_threshold: Number(form.low_stock_threshold),
              product_category_id: form.product_category_id || null,
            },
          },
        }
      );
      setModalOpen(false);
      setIsDirty(false);
      await loadProducts();
    } catch (err) {
      setFormError(err.message);
    } finally {
      setSaving(false);
    }
  }

  async function handleDelete(product) {
    if (!window.confirm(`¿Eliminar "${product.name}"? Esta acción no se puede deshacer.`)) return;
    try {
      await apiRequest(`/api/v1/products/${product.id}`, { method: "DELETE" });
      if (editingProduct?.id === product.id) setModalOpen(false);
      await loadProducts();
    } catch (err) {
      setError(err.message);
    }
  }

  return (
    <>
      <SectionCard
        title="Productos"
        description="Catálogo vivo de productos con precios, umbrales y visibilidad por tienda."
        action={
          canCreate && (
            <button className="btn-secondary shrink-0" onClick={openCreate} type="button">
              Nuevo producto
            </button>
          )
        }
      >
        <div className="mb-5 flex flex-wrap items-center gap-3">
          <input
            className="input-field min-w-[200px] flex-1"
            onChange={(e) => setSearch(e.target.value)}
            placeholder="Buscar por nombre o SKU"
            value={search}
          />
          {categories.length > 0 && (
            <select
              className="input-field w-[180px] shrink-0"
              value={categoryFilter}
              onChange={(e) => setCategoryFilter(e.target.value)}
            >
              <option value="">Todas las categorías</option>
              {categories.map((c) => (
                <option key={c.id} value={c.id}>{c.name}</option>
              ))}
            </select>
          )}
          <button
            className={`btn-ghost shrink-0 ${lowStockOnly ? "border-accent bg-accent/5 text-accent" : ""}`}
            onClick={() => setLowStockOnly((v) => !v)}
            type="button"
          >
            {lowStockOnly ? "Mostrando stock bajo" : "Solo stock bajo"}
          </button>
        </div>
        {error ? <div className="mb-4 rounded-2xl bg-accent/5 px-4 py-3 text-sm text-accent">{error}</div> : null}

        {loading ? (
          <p className="text-sm text-muted">Cargando productos...</p>
        ) : products.length ? (
          <div className="overflow-x-auto">
            <table className="min-w-full text-left text-sm">
              <thead className="text-xs uppercase tracking-[0.22em] text-muted">
                <tr>
                  <th className="pb-4">Producto</th>
                  <th className="pb-4">Categoría</th>
                  <th className="pb-4">Precio</th>
                  <th className="pb-4">Inventario</th>
                  <th className="pb-4">Umbral</th>
                  {canCreate && <th className="pb-4 text-right">Acciones</th>}
                </tr>
              </thead>
              <tbody className="divide-y divide-line">
                {products.map((product) => (
                  <tr key={product.id}>
                    <td className="py-4 align-top">
                      <p className="font-medium text-ink">{product.name}</p>
                      <p className="mt-0.5 text-sm text-muted">{product.sku}</p>
                      <div className="mt-2 flex flex-wrap gap-1.5">
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
                    <td className="py-4 align-top">
                      {product.product_category ? (
                        <span className="chip">{product.product_category.name}</span>
                      ) : (
                        <span className="text-muted">—</span>
                      )}
                    </td>
                    <td className="py-4 align-top text-muted">{formatCurrency(product.price)}</td>
                    <td className="py-4 align-top">
                      <div className="flex items-center gap-2">
                        <span className="text-lg font-semibold text-ink">{product.inventory_total}</span>
                        {product.low_stock && <span className="chip chip-alert">Alerta</span>}
                      </div>
                    </td>
                    <td className="py-4 align-top text-muted">{product.low_stock_threshold}</td>
                    {canCreate && (
                      <td className="py-4 align-top">
                        <div className="flex justify-end gap-2">
                          <button className="btn-ghost h-9 px-4 text-sm" onClick={() => openEdit(product)} type="button">
                            Editar
                          </button>
                          {canDelete && (
                            <button
                              className="btn-ghost h-9 border-accent/20 px-4 text-sm text-accent hover:bg-accent/5"
                              onClick={() => handleDelete(product)}
                              type="button"
                            >
                              Eliminar
                            </button>
                          )}
                        </div>
                      </td>
                    )}
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        ) : (
          <EmptyState
            description={canCreate ? "Crea tu primer producto para comenzar a controlar inventario." : "No hay productos registrados aún."}
            title="Sin productos"
          />
        )}
      </SectionCard>

      <Modal
        open={modalOpen}
        onClose={closeModal}
        title={editingProduct ? "Editar producto" : "Nuevo producto"}
        size="lg"
      >
        <form className="space-y-4" onSubmit={handleSubmit}>
          {formError && (
            <div className="rounded-2xl bg-accent/5 px-4 py-3 text-sm text-accent">{formError}</div>
          )}

          <div>
            <label className="mb-2 block text-sm font-medium text-ink">Nombre</label>
            <input className="input-field" required value={form.name} onChange={(e) => patch("name", e.target.value)} />
          </div>

          <div>
            <label className="mb-2 block text-sm font-medium text-ink">SKU</label>
            <input className="input-field" required value={form.sku} onChange={(e) => patch("sku", e.target.value)} />
          </div>

          <div>
            <label className="mb-2 block text-sm font-medium text-ink">Categoría</label>
            <select
              className="input-field"
              value={form.product_category_id}
              onChange={(e) => patch("product_category_id", e.target.value)}
            >
              <option value="">Sin categoría</option>
              {categories.map((c) => (
                <option key={c.id} value={c.id}>{c.name}</option>
              ))}
            </select>
          </div>

          <div className="grid gap-4 sm:grid-cols-2">
            <div>
              <label className="mb-2 block text-sm font-medium text-ink">Precio</label>
              <input
                className="input-field"
                min="0"
                required
                step="1"
                type="number"
                value={form.price}
                onChange={(e) => patch("price", e.target.value)}
              />
            </div>
            <div>
              <label className="mb-2 block text-sm font-medium text-ink">Umbral de stock bajo</label>
              <input
                className="input-field"
                min="0"
                type="number"
                value={form.low_stock_threshold}
                onChange={(e) => patch("low_stock_threshold", e.target.value)}
              />
            </div>
          </div>

          <div>
            <label className="mb-2 block text-sm font-medium text-ink">Descripción</label>
            <textarea
              className="text-area-field"
              value={form.description}
              onChange={(e) => patch("description", e.target.value)}
            />
          </div>

          <label className="flex items-center gap-3 text-sm text-muted">
            <input
              type="checkbox"
              checked={form.active}
              onChange={(e) => patch("active", e.target.checked)}
            />
            Producto activo
          </label>

          <div className="flex flex-wrap gap-3 pt-2">
            <button className="btn-secondary" disabled={saving} type="submit">
              {saving ? "Guardando..." : editingProduct ? "Actualizar producto" : "Crear producto"}
            </button>
            {editingProduct && canDelete && (
              <button
                className="btn-ghost border-accent/20 text-accent hover:bg-accent/5"
                onClick={() => handleDelete(editingProduct)}
                type="button"
              >
                Eliminar
              </button>
            )}
            <button className="btn-ghost" onClick={closeModal} type="button">
              Cancelar
            </button>
          </div>
        </form>
      </Modal>
    </>
  );
}
