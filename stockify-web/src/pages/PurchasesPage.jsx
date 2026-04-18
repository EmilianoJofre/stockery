import { useEffect, useState } from "react";
import AccessNotice from "../components/AccessNotice";
import EmptyState from "../components/EmptyState";
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
  const [supplierForm, setSupplierForm] = useState(EMPTY_SUPPLIER);
  const [purchaseForm, setPurchaseForm] = useState(EMPTY_PURCHASE);
  const [editingSupplierId, setEditingSupplierId] = useState(null);
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
      const [supplierResponse, storeResponse, productResponse, purchaseResponse] = await Promise.all([
        apiRequest("/api/v1/suppliers"),
        apiRequest("/api/v1/stores"),
        apiRequest("/api/v1/products"),
        apiRequest("/api/v1/purchases"),
      ]);

      setSuppliers(supplierResponse.suppliers);
      setStores(storeResponse.stores);
      setProducts(productResponse.products);
      setPurchases(purchaseResponse.purchases);
    } catch (requestError) {
      setError(requestError.message);
    } finally {
      setLoading(false);
    }
  }

  function resetSupplierForm() {
    setSupplierForm(EMPTY_SUPPLIER);
    setEditingSupplierId(null);
  }

  function updatePurchaseItem(index, field, value) {
    setPurchaseForm((current) => ({
      ...current,
      items: current.items.map((item, itemIndex) =>
        itemIndex === index ? { ...item, [field]: value } : item
      ),
    }));
  }

  function addPurchaseItem() {
    setPurchaseForm((current) => ({
      ...current,
      items: [...current.items, { product_id: "", quantity: 1, unit_cost: "" }],
    }));
  }

  function removePurchaseItem(index) {
    setPurchaseForm((current) => ({
      ...current,
      items: current.items.filter((_, itemIndex) => itemIndex !== index),
    }));
  }

  async function saveSupplier(event) {
    event.preventDefault();
    setSaving(true);
    setError("");

    try {
      await apiRequest(editingSupplierId ? `/api/v1/suppliers/${editingSupplierId}` : "/api/v1/suppliers", {
        method: editingSupplierId ? "PUT" : "POST",
        body: { supplier: supplierForm },
      });

      resetSupplierForm();
      await loadPage();
    } catch (submitError) {
      setError(submitError.message);
    } finally {
      setSaving(false);
    }
  }

  async function deleteSupplier(id) {
    if (!window.confirm("¿Eliminar este proveedor?")) {
      return;
    }

    try {
      await apiRequest(`/api/v1/suppliers/${id}`, { method: "DELETE" });
      await loadPage();
    } catch (deleteError) {
      setError(deleteError.message);
    }
  }

  async function savePurchase(event) {
    event.preventDefault();
    setSaving(true);
    setError("");

    try {
      await apiRequest("/api/v1/purchases", {
        method: "POST",
        body: {
          purchase: {
            ...purchaseForm,
            items: purchaseForm.items.map((item) => ({
              ...item,
              quantity: Number(item.quantity),
              unit_cost: Number(item.unit_cost),
            })),
          },
        },
      });

      setPurchaseForm(EMPTY_PURCHASE);
      await loadPage();
    } catch (submitError) {
      setError(submitError.message);
    } finally {
      setSaving(false);
    }
  }

  return (
    <div className="space-y-6">
      {!canManage ? (
        <AccessNotice description="Las cuentas Operador pueden revisar el historial de compras, pero no crear proveedores ni recibir nuevas ordenes." />
      ) : null}

      {error ? <div className="rounded-2xl bg-accent/5 px-4 py-3 text-sm text-accent">{error}</div> : null}

      <div className="grid gap-6 xl:grid-cols-[0.88fr_1.12fr]">
        <SectionCard description="Ficha de proveedores para los flujos de recepcion y abastecimiento." title="Proveedores">
          {canManage ? (
            <form className="space-y-4" onSubmit={saveSupplier}>
              <div>
                <label className="mb-2 block text-sm font-medium text-ink">Nombre del proveedor</label>
                <input
                  className="input-field"
                  onChange={(event) => setSupplierForm((current) => ({ ...current, name: event.target.value }))}
                  value={supplierForm.name}
                />
              </div>
              <div className="grid gap-4 sm:grid-cols-2">
                <div>
                  <label className="mb-2 block text-sm font-medium text-ink">Contacto</label>
                  <input
                    className="input-field"
                    onChange={(event) =>
                      setSupplierForm((current) => ({ ...current, contact_name: event.target.value }))
                    }
                    value={supplierForm.contact_name}
                  />
                </div>
                <div>
                  <label className="mb-2 block text-sm font-medium text-ink">Phone</label>
                  <input
                    className="input-field"
                    onChange={(event) => setSupplierForm((current) => ({ ...current, phone: event.target.value }))}
                    value={supplierForm.phone}
                  />
                </div>
              </div>
              <div>
                <label className="mb-2 block text-sm font-medium text-ink">Email</label>
                <input
                  className="input-field"
                  onChange={(event) => setSupplierForm((current) => ({ ...current, email: event.target.value }))}
                  value={supplierForm.email}
                />
              </div>
              <div>
                <label className="mb-2 block text-sm font-medium text-ink">Notas</label>
                <textarea
                  className="text-area-field"
                  onChange={(event) => setSupplierForm((current) => ({ ...current, notes: event.target.value }))}
                  value={supplierForm.notes}
                />
              </div>
              <div className="flex flex-wrap gap-3">
                <button className="btn-secondary" disabled={saving} type="submit">
                  {saving ? "Guardando..." : editingSupplierId ? "Actualizar proveedor" : "Crear proveedor"}
                </button>
                <button className="btn-ghost" onClick={resetSupplierForm} type="button">
                  Limpiar
                </button>
              </div>
            </form>
          ) : null}

          <div className={`space-y-3 ${canManage ? "mt-6" : ""}`}>
            {loading ? (
              <p className="text-sm text-muted">Cargando proveedores...</p>
            ) : suppliers.length ? (
              suppliers.map((supplier) => (
                <div key={supplier.id} className="rounded-2xl border border-line bg-cloud/70 p-4">
                  <div className="flex items-start justify-between gap-3">
                    <div>
                      <p className="font-semibold text-ink">{supplier.name}</p>
                      <p className="mt-1 text-sm text-muted">
                        {supplier.contact_name || "Sin contacto"} · {supplier.phone || "Sin telefono"}
                      </p>
                    </div>
                    <span className="chip">{supplier.active ? "Activo" : "Inactivo"}</span>
                  </div>
                  <p className="mt-3 text-sm text-muted">{supplier.email || "Sin correo definido"}</p>
                  {canManage ? (
                    <div className="mt-4 flex gap-2">
                      <button
                        className="btn-ghost h-10 px-4"
                        onClick={() => {
                          setEditingSupplierId(supplier.id);
                          setSupplierForm(supplier);
                        }}
                        type="button"
                      >
                        Editar
                      </button>
                      <button className="btn-primary h-10 bg-accent px-4" onClick={() => deleteSupplier(supplier.id)} type="button">
                        Eliminar
                      </button>
                    </div>
                  ) : null}
                </div>
              ))
            ) : (
              <EmptyState description="Agrega proveedores para comenzar a registrar compras." title="No hay proveedores disponibles" />
            )}
          </div>
        </SectionCard>

        <SectionCard description="Recibe mercaderia de proveedores y aumenta inventario automaticamente." title="Ingreso de compras">
          {canManage ? (
            <form className="space-y-4" onSubmit={savePurchase}>
              <div className="grid gap-4 md:grid-cols-2">
                <div>
                  <label className="mb-2 block text-sm font-medium text-ink">Proveedor</label>
                  <select
                    className="input-field"
                    onChange={(event) =>
                      setPurchaseForm((current) => ({ ...current, supplier_id: event.target.value }))
                    }
                    value={purchaseForm.supplier_id}
                  >
                    <option value="">Selecciona un proveedor</option>
                    {suppliers.map((supplier) => (
                      <option key={supplier.id} value={supplier.id}>
                        {supplier.name}
                      </option>
                    ))}
                  </select>
                </div>
                <div>
                  <label className="mb-2 block text-sm font-medium text-ink">Tienda</label>
                  <select
                    className="input-field"
                    onChange={(event) => setPurchaseForm((current) => ({ ...current, store_id: event.target.value }))}
                    value={purchaseForm.store_id}
                  >
                    <option value="">Selecciona una tienda</option>
                    {stores.map((store) => (
                      <option key={store.id} value={store.id}>
                        {store.name}
                      </option>
                    ))}
                  </select>
                </div>
              </div>
              <div className="grid gap-4 md:grid-cols-2">
                <div>
                  <label className="mb-2 block text-sm font-medium text-ink">Fecha de recepcion</label>
                  <input
                    className="input-field"
                    onChange={(event) => setPurchaseForm((current) => ({ ...current, received_on: event.target.value }))}
                    type="date"
                    value={purchaseForm.received_on}
                  />
                </div>
                <div>
                  <label className="mb-2 block text-sm font-medium text-ink">Estado</label>
                  <select
                    className="input-field"
                    onChange={(event) => setPurchaseForm((current) => ({ ...current, status: event.target.value }))}
                    value={purchaseForm.status}
                  >
                    <option value="received">Recibida</option>
                    <option value="draft">Borrador</option>
                  </select>
                </div>
              </div>
              <div className="space-y-3">
                {purchaseForm.items.map((item, index) => (
                  <div key={`purchase-item-${index}`} className="rounded-2xl border border-line bg-cloud/70 p-4">
                    <div className="grid gap-4 md:grid-cols-[1.6fr_0.7fr_0.7fr_auto]">
                      <select
                        className="input-field"
                        onChange={(event) => updatePurchaseItem(index, "product_id", event.target.value)}
                        value={item.product_id}
                      >
                        <option value="">Selecciona un producto</option>
                        {products.map((product) => (
                          <option key={product.id} value={product.id}>
                            {product.name} ({product.sku})
                          </option>
                        ))}
                      </select>
                      <input
                        className="input-field"
                        min="1"
                        onChange={(event) => updatePurchaseItem(index, "quantity", event.target.value)}
                        placeholder="Cant."
                        type="number"
                        value={item.quantity}
                      />
                      <input
                        className="input-field"
                        min="0"
                        onChange={(event) => updatePurchaseItem(index, "unit_cost", event.target.value)}
                        placeholder="Costo $"
                        step="1"
                        type="number"
                        value={item.unit_cost}
                      />
                      <button
                        className="btn-ghost"
                        disabled={purchaseForm.items.length === 1}
                        onClick={() => removePurchaseItem(index)}
                        type="button"
                      >
                        Quitar
                      </button>
                    </div>
                  </div>
                ))}
              </div>
              <div className="flex flex-wrap gap-3">
                <button className="btn-ghost" onClick={addPurchaseItem} type="button">
                  Agregar linea
                </button>
              </div>
              <div>
                <label className="mb-2 block text-sm font-medium text-ink">Notas</label>
                <textarea
                  className="text-area-field"
                  onChange={(event) => setPurchaseForm((current) => ({ ...current, notes: event.target.value }))}
                  value={purchaseForm.notes}
                />
              </div>
              <button className="btn-secondary w-full" disabled={saving} type="submit">
                {saving ? "Guardando compra..." : "Registrar compra"}
              </button>
            </form>
          ) : null}

          <div className={`${canManage ? "mt-6" : ""} overflow-x-auto`}>
            {purchases.length ? (
              <table className="min-w-full text-left text-sm">
                <thead className="text-xs uppercase tracking-[0.22em] text-muted">
                  <tr>
                    <th className="pb-4">Referencia</th>
                    <th className="pb-4">Proveedor</th>
                    <th className="pb-4">Tienda</th>
                    <th className="pb-4">Fecha</th>
                    <th className="pb-4 text-right">Total</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-line">
                  {purchases.map((purchase) => (
                    <tr key={purchase.id}>
                      <td className="py-4 font-medium text-ink">{purchase.reference}</td>
                      <td className="py-4 text-muted">{purchase.supplier.name}</td>
                      <td className="py-4 text-muted">{purchase.store.name}</td>
                      <td className="py-4 text-muted">{formatDate(purchase.received_on)}</td>
                      <td className="py-4 text-right font-medium text-ink">{formatCurrency(purchase.total_amount)}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            ) : (
              <EmptyState description="Las transacciones apareceran una vez que comience el ingreso de compras." title="Sin historial de compras" />
            )}
          </div>
        </SectionCard>
      </div>
    </div>
  );
}
