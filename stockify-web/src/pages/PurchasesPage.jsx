import { useEffect, useMemo, useState } from "react";
import EmptyState from "../components/EmptyState";
import Modal from "../components/Modal";
import SectionCard from "../components/SectionCard";
import { useAuth } from "../context/AuthContext";
import { can } from "../lib/permissions";
import { apiRequest } from "../lib/api";
import { formatCurrency, formatDate } from "../lib/format";

const EMPTY_SUPPLIER = {
  name: "",
  contact_name: "",
  email: "",
  phone: "",
  notes: "",
  active: true,
};

const EMPTY_PURCHASE = {
  supplier_id: "",
  store_id: "",
  status: "received",
  received_on: new Date().toISOString().slice(0, 10),
  notes: "",
  items: [{ product_id: "", quantity: 1, unit_cost: "" }],
};

export default function PurchasesPage() {
  const { user } = useAuth();
  const canManage = can(user, "purchases.create");

  const [suppliers, setSuppliers] = useState([]);
  const [stores, setStores] = useState([]);
  const [products, setProducts] = useState([]);
  const [purchases, setPurchases] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");

  const [purchaseOpen, setPurchaseOpen] = useState(false);
  const [purchaseForm, setPurchaseForm] = useState(EMPTY_PURCHASE);
  const [purchaseDirty, setPurchaseDirty] = useState(false);
  const [purchaseSaving, setPurchaseSaving] = useState(false);
  const [purchaseError, setPurchaseError] = useState("");

  const [supplierOpen, setSupplierOpen] = useState(false);
  const [supplierForm, setSupplierForm] = useState(EMPTY_SUPPLIER);
  const [editingSupplierId, setEditingSupplierId] = useState(null);
  const [supplierDirty, setSupplierDirty] = useState(false);
  const [supplierSaving, setSupplierSaving] = useState(false);
  const [supplierError, setSupplierError] = useState("");

  useEffect(() => { loadPage(); }, []);

  async function loadPage() {
    setLoading(true);
    setError("");
    try {
      const [suppliersRes, storesRes, productsRes, purchasesRes] = await Promise.all([
        apiRequest("/api/v1/suppliers"),
        apiRequest("/api/v1/stores"),
        apiRequest("/api/v1/products"),
        apiRequest("/api/v1/purchases"),
      ]);
      setSuppliers(suppliersRes.suppliers);
      setStores(storesRes.stores);
      setProducts(productsRes.products);
      setPurchases(purchasesRes.purchases);
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  }

  const liveTotal = useMemo(
    () => purchaseForm.items.reduce((sum, item) => sum + (Number(item.unit_cost) || 0) * (Number(item.quantity) || 0), 0),
    [purchaseForm.items]
  );

  function patchPurchase(field, value) {
    setPurchaseForm((f) => ({ ...f, [field]: value }));
    setPurchaseDirty(true);
  }

  function updateItem(index, field, value) {
    setPurchaseForm((f) => ({
      ...f,
      items: f.items.map((item, i) => (i === index ? { ...item, [field]: value } : item)),
    }));
    setPurchaseDirty(true);
  }

  function addItem() {
    setPurchaseForm((f) => ({ ...f, items: [...f.items, { product_id: "", quantity: 1, unit_cost: "" }] }));
    setPurchaseDirty(true);
  }

  function removeItem(index) {
    setPurchaseForm((f) => ({ ...f, items: f.items.filter((_, i) => i !== index) }));
    setPurchaseDirty(true);
  }

  function openPurchase() {
    const defaultStoreId = stores.length === 1 ? String(stores[0].id) : "";
    setPurchaseForm({ ...EMPTY_PURCHASE, store_id: defaultStoreId });
    setPurchaseDirty(false);
    setPurchaseError("");
    setPurchaseOpen(true);
  }

  function closePurchase() {
    if (purchaseDirty && !window.confirm("¿Salir sin registrar la compra?")) return;
    setPurchaseOpen(false);
    setPurchaseDirty(false);
    setPurchaseError("");
  }

  async function handlePurchaseSubmit(event) {
    event.preventDefault();
    setPurchaseSaving(true);
    setPurchaseError("");
    try {
      await apiRequest("/api/v1/purchases", {
        method: "POST",
        body: {
          purchase: {
            ...purchaseForm,
            items: purchaseForm.items.map((item) => ({
              ...item,
              quantity: Number(item.quantity),
              unit_cost: item.unit_cost ? Number(item.unit_cost) : "",
            })),
          },
        },
      });
      setPurchaseOpen(false);
      setPurchaseDirty(false);
      await loadPage();
    } catch (err) {
      setPurchaseError(err.message);
    } finally {
      setPurchaseSaving(false);
    }
  }

  function patchSupplier(field, value) {
    setSupplierForm((f) => ({ ...f, [field]: value }));
    setSupplierDirty(true);
  }

  function openNewSupplier() {
    setEditingSupplierId(null);
    setSupplierForm(EMPTY_SUPPLIER);
    setSupplierDirty(false);
    setSupplierError("");
    setSupplierOpen(true);
  }

  function openEditSupplier(supplier) {
    setEditingSupplierId(supplier.id);
    setSupplierForm({
      name: supplier.name,
      contact_name: supplier.contact_name || "",
      email: supplier.email || "",
      phone: supplier.phone || "",
      notes: supplier.notes || "",
      active: supplier.active,
    });
    setSupplierDirty(false);
    setSupplierError("");
    setSupplierOpen(true);
  }

  function closeSupplier() {
    if (supplierDirty && !window.confirm("¿Salir sin guardar el proveedor?")) return;
    setSupplierOpen(false);
    setSupplierDirty(false);
    setSupplierError("");
  }

  async function handleSupplierSubmit(event) {
    event.preventDefault();
    setSupplierSaving(true);
    setSupplierError("");
    try {
      await apiRequest(
        editingSupplierId ? `/api/v1/suppliers/${editingSupplierId}` : "/api/v1/suppliers",
        {
          method: editingSupplierId ? "PUT" : "POST",
          body: { supplier: supplierForm },
        }
      );
      setSupplierOpen(false);
      setSupplierDirty(false);
      await loadPage();
    } catch (err) {
      setSupplierError(err.message);
    } finally {
      setSupplierSaving(false);
    }
  }

  async function deleteSupplier(supplier) {
    if (!window.confirm(`¿Eliminar "${supplier.name}"?`)) return;
    try {
      await apiRequest(`/api/v1/suppliers/${supplier.id}`, { method: "DELETE" });
      await loadPage();
    } catch (err) {
      setError(err.message);
    }
  }

  return (
    <div className="space-y-6">
      <SectionCard
        title="Historial de compras"
        description="Órdenes de ingreso de mercadería con impacto automático en inventario."
        action={
          canManage && (
            <button className="btn-secondary" onClick={openPurchase} type="button">
              Registrar compra
            </button>
          )
        }
      >
        {error ? <div className="mb-4 rounded-2xl bg-accent/5 px-4 py-3 text-sm text-accent">{error}</div> : null}

        {loading ? (
          <p className="text-sm text-muted">Cargando compras...</p>
        ) : purchases.length ? (
          <div className="overflow-x-auto">
            <table className="min-w-full text-left text-sm">
              <thead className="text-xs uppercase tracking-[0.22em] text-muted">
                <tr>
                  <th className="pb-4">Referencia</th>
                  <th className="pb-4">Proveedor</th>
                  {stores.length > 1 && <th className="pb-4">Tienda</th>}
                  <th className="pb-4">Fecha</th>
                  <th className="pb-4 text-right">Total</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-line">
                {purchases.map((purchase) => (
                  <tr key={purchase.id}>
                    <td className="py-4 font-medium text-ink">{purchase.reference}</td>
                    <td className="py-4 text-muted">{purchase.supplier.name}</td>
                    {stores.length > 1 && <td className="py-4 text-muted">{purchase.store.name}</td>}
                    <td className="py-4 text-muted">{formatDate(purchase.received_on)}</td>
                    <td className="py-4 text-right font-medium text-ink">{formatCurrency(purchase.total_amount)}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        ) : (
          <EmptyState
            description="Las transacciones aparecerán una vez que comience el ingreso de compras."
            title="Sin historial de compras"
          />
        )}
      </SectionCard>

      <SectionCard
        title="Proveedores"
        description="Directorio de proveedores para los flujos de recepción y abastecimiento."
        action={
          canManage && (
            <button className="btn-secondary" onClick={openNewSupplier} type="button">
              Nuevo proveedor
            </button>
          )
        }
      >
        {suppliers.length ? (
          <div className="overflow-x-auto">
            <table className="min-w-full text-left text-sm">
              <thead className="text-xs uppercase tracking-[0.22em] text-muted">
                <tr>
                  <th className="pb-4">Proveedor</th>
                  <th className="pb-4">Contacto</th>
                  <th className="pb-4">Email</th>
                  <th className="pb-4">Estado</th>
                  {canManage && <th className="pb-4 text-right">Acciones</th>}
                </tr>
              </thead>
              <tbody className="divide-y divide-line">
                {suppliers.map((supplier) => (
                  <tr key={supplier.id}>
                    <td className="py-4">
                      <p className="font-medium text-ink">{supplier.name}</p>
                      {supplier.phone && <p className="mt-0.5 text-sm text-muted">{supplier.phone}</p>}
                    </td>
                    <td className="py-4 text-muted">{supplier.contact_name || "—"}</td>
                    <td className="py-4 text-muted">{supplier.email || "—"}</td>
                    <td className="py-4">
                      <span className={`chip ${supplier.active ? "" : "chip-alert"}`}>
                        {supplier.active ? "Activo" : "Inactivo"}
                      </span>
                    </td>
                    {canManage && (
                      <td className="py-4 text-right">
                        <div className="flex justify-end gap-2">
                          <button
                            className="btn-ghost h-9 px-4 text-sm"
                            onClick={() => openEditSupplier(supplier)}
                            type="button"
                          >
                            Editar
                          </button>
                          <button
                            className="btn-ghost h-9 border-accent/20 px-4 text-sm text-accent hover:bg-accent/5"
                            onClick={() => deleteSupplier(supplier)}
                            type="button"
                          >
                            Eliminar
                          </button>
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
            description="Agrega proveedores para comenzar a registrar compras."
            title="Sin proveedores"
          />
        )}
      </SectionCard>

      <Modal open={purchaseOpen} onClose={closePurchase} title="Registrar compra" size="xl">
        <form className="space-y-5" onSubmit={handlePurchaseSubmit}>
          {purchaseError && (
            <div className="rounded-2xl bg-accent/5 px-4 py-3 text-sm text-accent">{purchaseError}</div>
          )}

          <div className={`grid gap-4 ${stores.length > 1 ? "sm:grid-cols-2" : ""}`}>
            <div>
              <label className="mb-2 block text-sm font-medium text-ink">Proveedor</label>
              <select className="input-field" required value={purchaseForm.supplier_id} onChange={(e) => patchPurchase("supplier_id", e.target.value)}>
                <option value="">Selecciona un proveedor</option>
                {suppliers.map((s) => <option key={s.id} value={s.id}>{s.name}</option>)}
              </select>
            </div>
            {stores.length > 1 && (
              <div>
                <label className="mb-2 block text-sm font-medium text-ink">Tienda</label>
                <select className="input-field" required value={purchaseForm.store_id} onChange={(e) => patchPurchase("store_id", e.target.value)}>
                  <option value="">Selecciona una tienda</option>
                  {stores.map((s) => <option key={s.id} value={s.id}>{s.name}</option>)}
                </select>
              </div>
            )}
          </div>

          <div className="grid gap-4 sm:grid-cols-2">
            <div>
              <label className="mb-2 block text-sm font-medium text-ink">Fecha de recepción</label>
              <input className="input-field" type="date" value={purchaseForm.received_on} onChange={(e) => patchPurchase("received_on", e.target.value)} />
            </div>
            <div>
              <label className="mb-2 block text-sm font-medium text-ink">Estado</label>
              <select className="input-field" value={purchaseForm.status} onChange={(e) => patchPurchase("status", e.target.value)}>
                <option value="received">Recibida</option>
                <option value="draft">Borrador</option>
              </select>
            </div>
          </div>

          <div>
            <div className="mb-3 flex items-center justify-between">
              <label className="text-sm font-medium text-ink">Líneas de compra</label>
              <button className="btn-ghost h-9 px-4 text-sm" onClick={addItem} type="button">
                + Agregar línea
              </button>
            </div>
            <div className="space-y-2">
              {purchaseForm.items.map((item, index) => (
                <div key={`purchase-item-${index}`} className="grid gap-2 rounded-2xl border border-line bg-cloud/60 p-3 md:grid-cols-[1.6fr_0.6fr_0.8fr_auto]">
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
                    placeholder="Costo $"
                    step="1"
                    type="number"
                    value={item.unit_cost}
                    onChange={(e) => updateItem(index, "unit_cost", e.target.value)}
                  />
                  <button
                    className="btn-ghost h-12 px-3 text-sm disabled:opacity-40"
                    disabled={purchaseForm.items.length === 1}
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
            <textarea className="text-area-field" value={purchaseForm.notes} onChange={(e) => patchPurchase("notes", e.target.value)} />
          </div>

          <div className="flex gap-3 pt-2">
            <button className="btn-secondary flex-1" disabled={purchaseSaving} type="submit">
              {purchaseSaving ? "Guardando compra..." : "Registrar compra"}
            </button>
            <button className="btn-ghost" onClick={closePurchase} type="button">Cancelar</button>
          </div>
        </form>
      </Modal>

      <Modal open={supplierOpen} onClose={closeSupplier} title={editingSupplierId ? "Editar proveedor" : "Nuevo proveedor"} size="md">
        <form className="space-y-4" onSubmit={handleSupplierSubmit}>
          {supplierError && (
            <div className="rounded-2xl bg-accent/5 px-4 py-3 text-sm text-accent">{supplierError}</div>
          )}

          <div>
            <label className="mb-2 block text-sm font-medium text-ink">Nombre</label>
            <input className="input-field" required value={supplierForm.name} onChange={(e) => patchSupplier("name", e.target.value)} />
          </div>

          <div className="grid gap-4 sm:grid-cols-2">
            <div>
              <label className="mb-2 block text-sm font-medium text-ink">Contacto</label>
              <input className="input-field" value={supplierForm.contact_name} onChange={(e) => patchSupplier("contact_name", e.target.value)} />
            </div>
            <div>
              <label className="mb-2 block text-sm font-medium text-ink">Teléfono</label>
              <input className="input-field" value={supplierForm.phone} onChange={(e) => patchSupplier("phone", e.target.value)} />
            </div>
          </div>

          <div>
            <label className="mb-2 block text-sm font-medium text-ink">Email</label>
            <input className="input-field" type="email" value={supplierForm.email} onChange={(e) => patchSupplier("email", e.target.value)} />
          </div>

          <div>
            <label className="mb-2 block text-sm font-medium text-ink">Notas</label>
            <textarea className="text-area-field" value={supplierForm.notes} onChange={(e) => patchSupplier("notes", e.target.value)} />
          </div>

          {editingSupplierId && (
            <label className="flex items-center gap-3 text-sm text-muted">
              <input type="checkbox" checked={supplierForm.active} onChange={(e) => patchSupplier("active", e.target.checked)} />
              Proveedor activo
            </label>
          )}

          <div className="flex gap-3 pt-2">
            <button className="btn-secondary flex-1" disabled={supplierSaving} type="submit">
              {supplierSaving ? "Guardando..." : editingSupplierId ? "Actualizar proveedor" : "Crear proveedor"}
            </button>
            <button className="btn-ghost" onClick={closeSupplier} type="button">Cancelar</button>
          </div>
        </form>
      </Modal>
    </div>
  );
}
