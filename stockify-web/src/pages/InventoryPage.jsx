import { useDeferredValue, useEffect, useMemo, useState } from "react";
import { HiAdjustmentsHorizontal } from "react-icons/hi2";
import CategoryBar from "../components/CategoryBar";
import EmptyState from "../components/EmptyState";
import Modal from "../components/Modal";
import SectionCard from "../components/SectionCard";
import { useAuth } from "../context/AuthContext";
import { can } from "../lib/permissions";
import { apiRequest } from "../lib/api";
import { formatCurrency, formatDate } from "../lib/format";
import { translateAdjustmentReason } from "../lib/translations";
import { EXPIRY_HORIZONS, expiryStatus, summarizeLots } from "../lib/expiry";

const EMPTY_ADJUSTMENT = {
  product_id: "",
  store_id: "",
  quantity_change: "",
  reason: "audit",
  note: "",
};

export default function InventoryPage() {
  const { user } = useAuth();
  const canManage = can(user, "inventory.adjust");

  const [inventory, setInventory] = useState([]);
  const [adjustments, setAdjustments] = useState([]);
  const [stores, setStores] = useState([]);
  const [products, setProducts] = useState([]);
  const [categories, setCategories] = useState([]);
  const [search, setSearch] = useState("");
  const [storeId, setStoreId] = useState("");
  const [lowStockOnly, setLowStockOnly] = useState(false);
  const [selectedCategories, setSelectedCategories] = useState([]);
  const [showCategoryBar, setShowCategoryBar] = useState(false);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const deferredSearch = useDeferredValue(search);

  const [modalOpen, setModalOpen] = useState(false);
  const [form, setForm] = useState(EMPTY_ADJUSTMENT);
  const [isDirty, setIsDirty] = useState(false);
  const [saving, setSaving] = useState(false);
  const [formError, setFormError] = useState("");

  const [lots, setLots] = useState([]);
  const [horizon, setHorizon] = useState(30);
  const [lotsLoading, setLotsLoading] = useState(true);

  useEffect(() => { loadLookups(); }, []);
  useEffect(() => { loadInventory(); }, [deferredSearch, storeId, lowStockOnly, selectedCategories]);
  useEffect(() => { loadLots(); }, [horizon, storeId]);

  async function loadLookups() {
    try {
      const [storesRes, productsRes, categoriesRes] = await Promise.all([
        apiRequest("/api/v1/stores"),
        apiRequest("/api/v1/products"),
        apiRequest("/api/v1/product_categories"),
      ]);
      setStores(storesRes.stores);
      setProducts(productsRes.products);
      setCategories(categoriesRes.product_categories);
    } catch (err) {
      setError(err.message);
    }
  }

  async function loadInventory() {
    setLoading(true);
    setError("");
    try {
      const query = new URLSearchParams();
      if (deferredSearch) query.set("q", deferredSearch);
      if (storeId) query.set("store_id", storeId);
      if (lowStockOnly) query.set("low_stock", "true");
      selectedCategories.forEach((id) => query.append("category_ids[]", id));
      const response = await apiRequest(`/api/v1/inventory${query.toString() ? `?${query}` : ""}`);
      setInventory(response.inventory);
      setAdjustments(response.adjustments);
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  }

  // Los lotes vencidos se piden sin filtro de horizonte: `expiring_within` mira
  // hacia adelante, asi que un lote ya vencido no cae en esa ventana.
  async function loadLots() {
    setLotsLoading(true);
    try {
      const query = new URLSearchParams({ expiring_within: String(horizon) });
      if (storeId) query.set("store_id", storeId);

      const expiredQuery = new URLSearchParams({ expired: "true" });
      if (storeId) expiredQuery.set("store_id", storeId);

      const [upcoming, expired] = await Promise.all([
        apiRequest(`/api/v1/inventory/lots?${query}`),
        apiRequest(`/api/v1/inventory/lots?${expiredQuery}`),
      ]);

      const byId = new Map();
      [...expired.lots, ...upcoming.lots].forEach((lot) => byId.set(lot.id, lot));
      setLots(
        [...byId.values()].sort((a, b) => (a.days_to_expiry ?? 9e9) - (b.days_to_expiry ?? 9e9))
      );
    } catch (err) {
      setError(err.message);
    } finally {
      setLotsLoading(false);
    }
  }

  const lotSummary = useMemo(() => summarizeLots(lots), [lots]);

  function toggleCategory(id) {
    setSelectedCategories((prev) =>
      prev.includes(id) ? prev.filter((c) => c !== id) : [...prev, id]
    );
  }

  const productOptions = useMemo(
    () => products.map((p) => ({ label: `${p.name} (${p.sku})`, value: p.id })),
    [products]
  );

  function patch(field, value) {
    setForm((f) => ({ ...f, [field]: value }));
    setIsDirty(true);
  }

  function openAdjust(item = null) {
    const defaultStoreId = stores.length === 1 ? String(stores[0].id) : "";
    setForm(
      item
        ? { ...EMPTY_ADJUSTMENT, product_id: item.product_id, store_id: item.store_id || defaultStoreId }
        : { ...EMPTY_ADJUSTMENT, store_id: defaultStoreId }
    );
    setIsDirty(false);
    setFormError("");
    setModalOpen(true);
  }

  function closeModal() {
    if (isDirty && !window.confirm("¿Salir sin guardar el ajuste?")) return;
    setModalOpen(false);
    setIsDirty(false);
    setFormError("");
  }

  async function handleAdjust(event) {
    event.preventDefault();
    setSaving(true);
    setFormError("");
    try {
      await apiRequest("/api/v1/inventory/adjust", {
        method: "POST",
        body: { adjustment: { ...form, quantity_change: Number(form.quantity_change) } },
      });
      setModalOpen(false);
      setIsDirty(false);
      await loadInventory();
    } catch (err) {
      setFormError(err.message);
    } finally {
      setSaving(false);
    }
  }

  return (
    <div className="space-y-6">
      <SectionCard
        title="Niveles de inventario"
        description="Stock por ubicación con alertas de umbral en tiempo real."
        action={
          <div className="flex flex-wrap items-center gap-3">
            <input
              className="input-field w-[200px]"
              onChange={(e) => setSearch(e.target.value)}
              placeholder="Buscar inventario"
              value={search}
            />
            {categories.length > 0 && (
              <button
                type="button"
                onClick={() => setShowCategoryBar((v) => !v)}
                className={`btn-ghost shrink-0 flex items-center gap-2 ${
                  selectedCategories.length > 0 || showCategoryBar
                    ? "border-brand bg-brand/5 text-brand"
                    : ""
                }`}
              >
                <HiAdjustmentsHorizontal className="h-4 w-4" />
                Categorías
                {selectedCategories.length > 0 && (
                  <span className="flex h-5 w-5 items-center justify-center rounded-full bg-brand text-[11px] font-semibold text-white">
                    {selectedCategories.length}
                  </span>
                )}
              </button>
            )}
            {stores.length > 1 && (
              <select
                className="input-field w-[170px]"
                onChange={(e) => setStoreId(e.target.value)}
                value={storeId}
              >
                <option value="">Todas las tiendas</option>
                {stores.map((store) => (
                  <option key={store.id} value={store.id}>{store.name}</option>
                ))}
              </select>
            )}
            <button
              className={`btn-ghost ${lowStockOnly ? "border-accent bg-accent/5 text-accent" : ""}`}
              onClick={() => setLowStockOnly((v) => !v)}
              type="button"
            >
              {lowStockOnly ? "Modo stock bajo" : "Stock bajo"}
            </button>
            {canManage && (
              <button className="btn-secondary" onClick={() => openAdjust()} type="button">
                Ajustar stock
              </button>
            )}
          </div>
        }
      >
        {showCategoryBar && categories.length > 0 && (
          <div className="mb-5">
            <CategoryBar
              categories={categories}
              selected={selectedCategories}
              onToggle={toggleCategory}
              onClear={() => setSelectedCategories([])}
            />
          </div>
        )}

        {error ? <div className="mb-4 rounded-2xl bg-accent/5 px-4 py-3 text-sm text-accent">{error}</div> : null}

        {loading ? (
          <p className="text-sm text-muted">Cargando inventario...</p>
        ) : inventory.length ? (
          <div className="overflow-x-auto">
            <table className="min-w-full text-left text-sm">
              <thead className="text-xs uppercase tracking-[0.22em] text-muted">
                <tr>
                  <th className="pb-4">Producto</th>
                  {stores.length > 1 && <th className="pb-4">Tienda</th>}
                  <th className="pb-4">Cantidad</th>
                  <th className="pb-4">Umbral</th>
                  {canManage && <th className="pb-4 text-right">Acción</th>}
                </tr>
              </thead>
              <tbody className="divide-y divide-line">
                {inventory.map((item) => (
                  <tr key={item.id}>
                    <td className="py-4">
                      <p className="font-medium text-ink">{item.product_name}</p>
                      <p className="text-sm text-muted">{item.sku}</p>
                    </td>
                    {stores.length > 1 && <td className="py-4 text-muted">{item.store_name}</td>}
                    <td className="py-4">
                      <div className="flex items-center gap-2">
                        <span className="text-lg font-semibold text-ink">{item.quantity}</span>
                        {item.low_stock && <span className="chip chip-alert">Alerta</span>}
                      </div>
                    </td>
                    <td className="py-4 text-muted">{item.threshold}</td>
                    {canManage && (
                      <td className="py-4 text-right">
                        <button
                          className="btn-ghost h-9 px-4 text-sm"
                          onClick={() => openAdjust(item)}
                          type="button"
                        >
                          Ajustar
                        </button>
                      </td>
                    )}
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        ) : (
          <EmptyState
            description="Las filas aparecerán a medida que el inventario se distribuya por tienda."
            title="Sin filas de inventario"
          />
        )}
      </SectionCard>

      <SectionCard
        title="Control de vencimientos"
        description="Lotes con saldo ordenados por urgencia. El stock se descuenta primero del lote que vence antes (FEFO)."
        action={
          <div className="flex flex-wrap items-center gap-2">
            {EXPIRY_HORIZONS.map((option) => (
              <button
                key={option.days}
                type="button"
                onClick={() => setHorizon(option.days)}
                className={`btn-ghost h-9 px-3 text-sm ${
                  horizon === option.days ? "border-brand bg-brand/5 text-brand" : ""
                }`}
              >
                {option.label}
              </button>
            ))}
          </div>
        }
      >
        {lotsLoading ? (
          <p className="text-sm text-muted">Cargando lotes...</p>
        ) : lots.length ? (
          <>
            <div className="mb-5 grid gap-3 sm:grid-cols-3">
              <div className="rounded-2xl border border-rose-200 bg-rose-50 px-4 py-3">
                <p className="text-xs font-semibold uppercase tracking-[0.2em] text-rose-700">Vencidos</p>
                <p className="mt-2 text-2xl font-semibold tracking-[-0.04em] text-rose-800">
                  {lotSummary.expiredUnits}
                  <span className="ml-2 text-sm font-medium text-rose-600">
                    unid. en {lotSummary.expired} {lotSummary.expired === 1 ? "lote" : "lotes"}
                  </span>
                </p>
              </div>
              <div className="rounded-2xl border border-amber-200 bg-amber-50 px-4 py-3">
                <p className="text-xs font-semibold uppercase tracking-[0.2em] text-amber-800">Vencen en 7 días</p>
                <p className="mt-2 text-2xl font-semibold tracking-[-0.04em] text-amber-900">
                  {lotSummary.criticalUnits}
                  <span className="ml-2 text-sm font-medium text-amber-700">
                    unid. en {lotSummary.critical} {lotSummary.critical === 1 ? "lote" : "lotes"}
                  </span>
                </p>
              </div>
              <div className="rounded-2xl border border-line bg-cloud/70 px-4 py-3">
                <p className="text-xs font-semibold uppercase tracking-[0.2em] text-muted">
                  En la ventana de {horizon} días
                </p>
                <p className="mt-2 text-2xl font-semibold tracking-[-0.04em] text-ink">
                  {lotSummary.units}
                  <span className="ml-2 text-sm font-medium text-muted">
                    unid. en {lots.length} {lots.length === 1 ? "lote" : "lotes"}
                  </span>
                </p>
              </div>
            </div>

            <div className="overflow-x-auto">
              <table className="min-w-full text-left text-sm">
                <thead className="text-xs uppercase tracking-[0.22em] text-muted">
                  <tr>
                    <th className="pb-4">Producto</th>
                    <th className="pb-4">Lote</th>
                    {stores.length > 1 && <th className="pb-4">Tienda</th>}
                    <th className="pb-4">Vence</th>
                    <th className="pb-4">Estado</th>
                    <th className="pb-4 text-right">Saldo</th>
                    <th className="pb-4 text-right">Costo unit.</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-line">
                  {lots.map((lot) => {
                    const status = expiryStatus(lot);
                    return (
                      <tr key={lot.id} className={status.rowClass}>
                        <td className="py-4">
                          <p className="font-medium text-ink">{lot.product_name}</p>
                          <p className="text-sm text-muted">{lot.sku}</p>
                        </td>
                        <td className="py-4 text-muted">{lot.lot_code || "—"}</td>
                        {stores.length > 1 && <td className="py-4 text-muted">{lot.store_name}</td>}
                        <td className="py-4 text-muted">{formatDate(lot.expiry_date)}</td>
                        <td className="py-4">
                          <span className={`chip ${status.chipClass}`}>{status.label}</span>
                        </td>
                        <td className="py-4 text-right text-lg font-semibold text-ink">
                          {lot.quantity_remaining}
                        </td>
                        <td className="py-4 text-right text-muted">{formatCurrency(lot.unit_cost)}</td>
                      </tr>
                    );
                  })}
                </tbody>
              </table>
            </div>
          </>
        ) : (
          <EmptyState
            description={`Ningún lote con saldo vence en los próximos ${horizon} días. Los vencimientos se capturan al recibir una compra.`}
            title="Sin vencimientos próximos"
          />
        )}
      </SectionCard>

      <SectionCard
        title="Movimientos recientes"
        description="Últimos movimientos de stock con su lote de origen y el operador responsable."
      >
        {adjustments.length ? (
          <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
            {adjustments.map((adj) => (
              <div key={adj.id} className="rounded-2xl border border-line bg-cloud/70 p-4">
                <div className="flex items-start justify-between gap-3">
                  <div>
                    <p className="text-sm font-semibold text-ink">{adj.product_name}</p>
                    <p className="text-sm text-muted">
                      {adj.store_name} · {translateAdjustmentReason(adj.reason)}
                    </p>
                  </div>
                  <span className={`chip ${adj.quantity_change < 0 ? "chip-alert" : ""}`}>
                    {adj.quantity_change > 0 ? "+" : ""}{adj.quantity_change}
                  </span>
                </div>
                {(adj.lot_code || adj.expiry_date) && (
                  <p className="mt-2 text-xs text-muted">
                    Lote {adj.lot_code || "sin código"}
                    {adj.expiry_date ? ` · vence ${formatDate(adj.expiry_date)}` : ""}
                  </p>
                )}
                {adj.note && <p className="mt-3 text-sm text-muted">{adj.note}</p>}
                <p className="mt-3 text-xs uppercase tracking-[0.2em] text-muted">
                  {adj.actor_name} · {formatDate(adj.created_at)}
                </p>
              </div>
            ))}
          </div>
        ) : (
          <EmptyState description="Aún no se han registrado ajustes." title="Sin historial de ajustes" />
        )}
      </SectionCard>

      <Modal open={modalOpen} onClose={closeModal} title="Ajuste de stock" size="md">
        <form className="space-y-4" onSubmit={handleAdjust}>
          {formError && (
            <div className="rounded-2xl bg-accent/5 px-4 py-3 text-sm text-accent">{formError}</div>
          )}

          <div>
            <label className="mb-2 block text-sm font-medium text-ink">Producto</label>
            <select className="input-field" required value={form.product_id} onChange={(e) => patch("product_id", e.target.value)}>
              <option value="">Selecciona un producto</option>
              {productOptions.map((opt) => (
                <option key={opt.value} value={opt.value}>{opt.label}</option>
              ))}
            </select>
          </div>

          {stores.length > 1 && (
            <div>
              <label className="mb-2 block text-sm font-medium text-ink">Tienda</label>
              <select className="input-field" required value={form.store_id} onChange={(e) => patch("store_id", e.target.value)}>
                <option value="">Selecciona una tienda</option>
                {stores.map((s) => <option key={s.id} value={s.id}>{s.name}</option>)}
              </select>
            </div>
          )}

          <div>
            <label className="mb-2 block text-sm font-medium text-ink">Cambio de cantidad</label>
            <input
              className="input-field"
              placeholder="Negativo para descontar, positivo para agregar"
              required
              type="number"
              value={form.quantity_change}
              onChange={(e) => patch("quantity_change", e.target.value)}
            />
          </div>

          <div>
            <label className="mb-2 block text-sm font-medium text-ink">Motivo</label>
            <select className="input-field" value={form.reason} onChange={(e) => patch("reason", e.target.value)}>
              <option value="audit">Auditoría</option>
              <option value="restock">Reposición</option>
              <option value="damage">Merma</option>
              <option value="expiry">Vencimiento</option>
              <option value="display">Exhibición</option>
            </select>
            <p className="mt-2 text-xs text-muted">
              Un ajuste negativo descuenta del lote que vence antes; uno positivo crea un lote nuevo sin
              vencimiento.
            </p>
          </div>

          <div>
            <label className="mb-2 block text-sm font-medium text-ink">Nota</label>
            <textarea className="text-area-field" value={form.note} onChange={(e) => patch("note", e.target.value)} />
          </div>

          <div className="flex gap-3 pt-2">
            <button className="btn-secondary flex-1" disabled={saving} type="submit">
              {saving ? "Publicando..." : "Publicar ajuste"}
            </button>
            <button className="btn-ghost" onClick={closeModal} type="button">Cancelar</button>
          </div>
        </form>
      </Modal>
    </div>
  );
}
