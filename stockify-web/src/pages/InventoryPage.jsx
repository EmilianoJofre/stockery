import { useDeferredValue, useEffect, useMemo, useState } from "react";
import EmptyState from "../components/EmptyState";
import SectionCard from "../components/SectionCard";
import { useAuth } from "../context/AuthContext";
import { apiRequest } from "../lib/api";
import { formatDate } from "../lib/format";
import { translateAdjustmentReason } from "../lib/translations";

const EMPTY_ADJUSTMENT = {
  product_id: "",
  store_id: "",
  quantity_change: "",
  reason: "audit",
  note: "",
};

export default function InventoryPage() {
  const { user } = useAuth();
  const canManage = user?.capabilities?.can_manage_inventory;
  const [inventory, setInventory] = useState([]);
  const [adjustments, setAdjustments] = useState([]);
  const [stores, setStores] = useState([]);
  const [products, setProducts] = useState([]);
  const [search, setSearch] = useState("");
  const [storeId, setStoreId] = useState("");
  const [lowStockOnly, setLowStockOnly] = useState(false);
  const [form, setForm] = useState(EMPTY_ADJUSTMENT);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState("");
  const deferredSearch = useDeferredValue(search);

  useEffect(() => {
    loadLookups();
  }, []);

  useEffect(() => {
    loadInventory();
  }, [deferredSearch, storeId, lowStockOnly]);

  async function loadLookups() {
    try {
      const [storesResponse, productsResponse] = await Promise.all([
        apiRequest("/api/v1/stores"),
        apiRequest("/api/v1/products"),
      ]);

      setStores(storesResponse.stores);
      setProducts(productsResponse.products);
    } catch (lookupError) {
      setError(lookupError.message);
    }
  }

  async function loadInventory() {
    setLoading(true);
    setError("");

    try {
      const query = new URLSearchParams();
      if (deferredSearch) {
        query.set("q", deferredSearch);
      }
      if (storeId) {
        query.set("store_id", storeId);
      }
      if (lowStockOnly) {
        query.set("low_stock", "true");
      }

      const response = await apiRequest(`/api/v1/inventory${query.toString() ? `?${query}` : ""}`);
      setInventory(response.inventory);
      setAdjustments(response.adjustments);
    } catch (requestError) {
      setError(requestError.message);
    } finally {
      setLoading(false);
    }
  }

  const inventoryProductOptions = useMemo(
    () => products.map((product) => ({ label: `${product.name} (${product.sku})`, value: product.id })),
    [products]
  );

  async function handleAdjust(event) {
    event.preventDefault();
    setSaving(true);
    setError("");

    try {
      await apiRequest("/api/v1/inventory/adjust", {
        method: "POST",
        body: {
          adjustment: {
            ...form,
            quantity_change: Number(form.quantity_change),
          },
        },
      });

      setForm(EMPTY_ADJUSTMENT);
      await loadInventory();
    } catch (submitError) {
      setError(submitError.message);
    } finally {
      setSaving(false);
    }
  }

  return (
    <div className="grid gap-6 xl:grid-cols-[1.2fr_0.95fr]">
      <SectionCard
        action={
          <div className="flex flex-wrap gap-3">
            <input
              className="input-field w-[220px]"
              onChange={(event) => setSearch(event.target.value)}
              placeholder="Buscar inventario"
              value={search}
            />
            <select className="input-field w-[180px]" onChange={(event) => setStoreId(event.target.value)} value={storeId}>
              <option value="">Todas las tiendas</option>
              {stores.map((store) => (
                <option key={store.id} value={store.id}>
                  {store.name}
                </option>
              ))}
            </select>
            <button
              className={`btn-ghost ${lowStockOnly ? "border-accent bg-accent/5 text-accent" : ""}`}
              onClick={() => setLowStockOnly((current) => !current)}
              type="button"
            >
              {lowStockOnly ? "Modo stock bajo" : "Filtrar stock bajo"}
            </button>
          </div>
        }
        description="Sigue cantidades por ubicacion y monitorea el riesgo frente a los umbrales."
        title="Niveles de inventario"
      >
        {error ? <div className="mb-4 rounded-2xl bg-accent/5 px-4 py-3 text-sm text-accent">{error}</div> : null}

        {loading ? (
          <p className="text-sm text-muted">Cargando inventario...</p>
        ) : inventory.length ? (
          <div className="overflow-x-auto">
            <table className="min-w-full text-left text-sm">
              <thead className="text-xs uppercase tracking-[0.22em] text-muted">
                <tr>
                  <th className="pb-4">Producto</th>
                  <th className="pb-4">Tienda</th>
                  <th className="pb-4">Cantidad</th>
                  <th className="pb-4">Umbral</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-line">
                {inventory.map((item) => (
                  <tr key={item.id}>
                    <td className="py-4">
                      <p className="font-medium text-ink">{item.product_name}</p>
                      <p className="text-sm text-muted">{item.sku}</p>
                    </td>
                    <td className="py-4 text-muted">{item.store_name}</td>
                    <td className="py-4">
                      <div className="flex items-center gap-2">
                        <span className="text-lg font-semibold text-ink">{item.quantity}</span>
                        {item.low_stock ? <span className="chip chip-alert">Alerta</span> : null}
                      </div>
                    </td>
                    <td className="py-4 text-muted">{item.threshold}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        ) : (
          <EmptyState description="Las filas apareceran a medida que el inventario se distribuya por tienda." title="Sin filas de inventario" />
        )}
      </SectionCard>

      <div className="space-y-6">
        <SectionCard
          description={
            canManage
              ? "Aumenta o disminuye stock y deja una trazabilidad del motivo."
              : "Tu rol puede revisar inventario, pero no publicar ajustes."
          }
          title="Ajuste de stock"
        >
          {canManage ? (
            <form className="space-y-4" onSubmit={handleAdjust}>
              <div>
                <label className="mb-2 block text-sm font-medium text-ink">Producto</label>
                <select
                  className="input-field"
                  onChange={(event) => setForm((current) => ({ ...current, product_id: event.target.value }))}
                  value={form.product_id}
                >
                  <option value="">Selecciona un producto</option>
                  {inventoryProductOptions.map((option) => (
                    <option key={option.value} value={option.value}>
                      {option.label}
                    </option>
                  ))}
                </select>
              </div>
              <div>
                <label className="mb-2 block text-sm font-medium text-ink">Tienda</label>
                <select
                  className="input-field"
                  onChange={(event) => setForm((current) => ({ ...current, store_id: event.target.value }))}
                  value={form.store_id}
                >
                  <option value="">Selecciona una tienda</option>
                  {stores.map((store) => (
                    <option key={store.id} value={store.id}>
                      {store.name}
                    </option>
                  ))}
                </select>
              </div>
              <div>
                <label className="mb-2 block text-sm font-medium text-ink">Cambio de cantidad</label>
                <input
                  className="input-field"
                  onChange={(event) => setForm((current) => ({ ...current, quantity_change: event.target.value }))}
                  placeholder="Usa numeros negativos para descontar"
                  type="number"
                  value={form.quantity_change}
                />
              </div>
              <div>
                <label className="mb-2 block text-sm font-medium text-ink">Motivo</label>
                <select
                  className="input-field"
                  onChange={(event) => setForm((current) => ({ ...current, reason: event.target.value }))}
                  value={form.reason}
                >
                  <option value="audit">Auditoria</option>
                  <option value="purchase">Compra</option>
                  <option value="sale">Venta</option>
                  <option value="display">Exhibicion</option>
                  <option value="damage">Merma</option>
                </select>
              </div>
              <div>
                <label className="mb-2 block text-sm font-medium text-ink">Nota</label>
                <textarea
                  className="text-area-field"
                  onChange={(event) => setForm((current) => ({ ...current, note: event.target.value }))}
                  value={form.note}
                />
              </div>
              <button className="btn-secondary w-full" disabled={saving} type="submit">
                {saving ? "Publicando..." : "Publicar ajuste"}
              </button>
            </form>
          ) : (
            <EmptyState
              description="Los roles Administrador y Gerente pueden publicar ajustes de stock."
              title="Acceso solo de visualizacion"
            />
          )}
        </SectionCard>

        <SectionCard description="Ultimos movimientos de stock con contexto del operador." title="Ajustes recientes">
          {adjustments.length ? (
            <div className="space-y-3">
              {adjustments.map((adjustment) => (
                <div key={adjustment.id} className="rounded-2xl border border-line bg-cloud/70 p-4">
                  <div className="flex items-start justify-between gap-3">
                    <div>
                      <p className="text-sm font-semibold text-ink">{adjustment.product_name}</p>
                      <p className="text-sm text-muted">
                        {adjustment.store_name} · {translateAdjustmentReason(adjustment.reason)}
                      </p>
                    </div>
                    <span className={`chip ${adjustment.quantity_change < 0 ? "chip-alert" : ""}`}>
                      {adjustment.quantity_change > 0 ? "+" : ""}
                      {adjustment.quantity_change}
                    </span>
                  </div>
                  <p className="mt-3 text-sm text-muted">{adjustment.note || "Sin nota registrada."}</p>
                  <p className="mt-3 text-xs uppercase tracking-[0.2em] text-muted">
                    {adjustment.actor_name} · {formatDate(adjustment.created_at)}
                  </p>
                </div>
              ))}
            </div>
          ) : (
            <EmptyState description="Aun no se han registrado ajustes." title="Sin historial de ajustes" />
          )}
        </SectionCard>
      </div>
    </div>
  );
}
