import { useDeferredValue, useEffect, useState } from "react";
import EmptyState from "../components/EmptyState";
import Modal from "../components/Modal";
import SectionCard from "../components/SectionCard";
import { useAuth } from "../context/AuthContext";
import { can } from "../lib/permissions";
import { apiRequest } from "../lib/api";

const EMPTY_CUSTOMER = {
  rut: "",
  name: "",
  giro: "",
  email: "",
  phone: "",
  address: "",
  comuna: "",
  active: true,
};

export default function CustomersPage() {
  const { user } = useAuth();
  const canManage = can(user, "sales.create");

  const [customers, setCustomers] = useState([]);
  const [search, setSearch] = useState("");
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const deferredSearch = useDeferredValue(search);

  const [modalOpen, setModalOpen] = useState(false);
  const [editingId, setEditingId] = useState(null);
  const [form, setForm] = useState(EMPTY_CUSTOMER);
  const [isDirty, setIsDirty] = useState(false);
  const [saving, setSaving] = useState(false);
  const [formError, setFormError] = useState("");

  useEffect(() => { loadCustomers(); }, [deferredSearch]);

  async function loadCustomers() {
    setLoading(true);
    setError("");
    try {
      const query = deferredSearch ? `?q=${encodeURIComponent(deferredSearch)}` : "";
      const response = await apiRequest(`/api/v1/customers${query}`);
      setCustomers(response.customers);
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

  function openNew() {
    setEditingId(null);
    setForm(EMPTY_CUSTOMER);
    setIsDirty(false);
    setFormError("");
    setModalOpen(true);
  }

  function openEdit(customer) {
    setEditingId(customer.id);
    setForm({
      rut: customer.rut || "",
      name: customer.name,
      giro: customer.giro || "",
      email: customer.email || "",
      phone: customer.phone || "",
      address: customer.address || "",
      comuna: customer.comuna || "",
      active: customer.active,
    });
    setIsDirty(false);
    setFormError("");
    setModalOpen(true);
  }

  function closeModal() {
    if (isDirty && !window.confirm("¿Salir sin guardar el cliente?")) return;
    setModalOpen(false);
    setIsDirty(false);
    setFormError("");
  }

  async function handleSubmit(event) {
    event.preventDefault();
    setSaving(true);
    setFormError("");
    try {
      await apiRequest(
        editingId ? `/api/v1/customers/${editingId}` : "/api/v1/customers",
        { method: editingId ? "PUT" : "POST", body: { customer: form } }
      );
      setModalOpen(false);
      setIsDirty(false);
      await loadCustomers();
    } catch (err) {
      setFormError(err.message);
    } finally {
      setSaving(false);
    }
  }

  // Un cliente sirve para factura solo si tiene RUT y comuna: son los dos
  // campos que el SII exige en el receptor.
  function readyForFactura(customer) {
    return Boolean(customer.rut) && Boolean(customer.comuna);
  }

  return (
    <SectionCard
      title="Clientes"
      description="Receptores de documentos tributarios. Una factura exige RUT y comuna."
      action={
        <div className="flex flex-wrap items-center gap-3">
          <input
            className="input-field w-[220px]"
            onChange={(e) => setSearch(e.target.value)}
            placeholder="Buscar por nombre o RUT"
            value={search}
          />
          {canManage && (
            <button className="btn-secondary" onClick={openNew} type="button">
              Nuevo cliente
            </button>
          )}
        </div>
      }
    >
      {error ? <div className="mb-4 rounded-2xl bg-accent/5 px-4 py-3 text-sm text-accent">{error}</div> : null}

      {loading ? (
        <p className="text-sm text-muted">Cargando clientes...</p>
      ) : customers.length ? (
        <div className="overflow-x-auto">
          <table className="min-w-full text-left text-sm">
            <thead className="text-xs uppercase tracking-[0.22em] text-muted">
              <tr>
                <th className="pb-4">Cliente</th>
                <th className="pb-4">RUT</th>
                <th className="pb-4">Giro</th>
                <th className="pb-4">Comuna</th>
                <th className="pb-4">Contacto</th>
                <th className="pb-4">Estado</th>
                {canManage && <th className="pb-4 text-right">Acción</th>}
              </tr>
            </thead>
            <tbody className="divide-y divide-line">
              {customers.map((customer) => (
                <tr key={customer.id}>
                  <td className="py-4 font-medium text-ink">{customer.name}</td>
                  <td className="py-4 text-muted">{customer.formatted_rut || "—"}</td>
                  <td className="py-4 text-muted">{customer.giro || "—"}</td>
                  <td className="py-4 text-muted">{customer.comuna || "—"}</td>
                  <td className="py-4 text-muted">
                    {customer.email || customer.phone || "—"}
                  </td>
                  <td className="py-4">
                    {!customer.active ? (
                      <span className="chip">Inactivo</span>
                    ) : readyForFactura(customer) ? (
                      <span className="chip border-transparent bg-brand/10 text-brand">Apto factura</span>
                    ) : (
                      <span className="chip border-transparent bg-amber-100 text-amber-800">Solo boleta</span>
                    )}
                  </td>
                  {canManage && (
                    <td className="py-4 text-right">
                      <button className="btn-ghost h-9 px-4 text-sm" onClick={() => openEdit(customer)} type="button">
                        Editar
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
          title="Sin clientes"
          description="Los clientes se crean aquí o automáticamente al emitir una factura con RUT desde el formulario de venta."
        />
      )}

      <Modal
        open={modalOpen}
        onClose={closeModal}
        title={editingId ? "Editar cliente" : "Nuevo cliente"}
        size="xl"
      >
        <form className="space-y-4" onSubmit={handleSubmit}>
          {formError && (
            <div className="rounded-2xl bg-accent/5 px-4 py-3 text-sm text-accent">{formError}</div>
          )}

          <div className="grid gap-4 sm:grid-cols-2">
            <div>
              <label className="mb-2 block text-sm font-medium text-ink">RUT</label>
              <input
                className="input-field"
                placeholder="76192083-9"
                value={form.rut}
                onChange={(e) => patch("rut", e.target.value)}
              />
              <p className="mt-1 text-xs text-muted">Obligatorio para emitir facturas</p>
            </div>
            <div>
              <label className="mb-2 block text-sm font-medium text-ink">Razón social o nombre</label>
              <input className="input-field" required value={form.name} onChange={(e) => patch("name", e.target.value)} />
            </div>
            <div className="sm:col-span-2">
              <label className="mb-2 block text-sm font-medium text-ink">Giro</label>
              <input className="input-field" value={form.giro} onChange={(e) => patch("giro", e.target.value)} />
            </div>
            <div>
              <label className="mb-2 block text-sm font-medium text-ink">Dirección</label>
              <input className="input-field" value={form.address} onChange={(e) => patch("address", e.target.value)} />
            </div>
            <div>
              <label className="mb-2 block text-sm font-medium text-ink">Comuna</label>
              <input
                className="input-field"
                placeholder="Providencia"
                value={form.comuna}
                onChange={(e) => patch("comuna", e.target.value)}
              />
              <p className="mt-1 text-xs text-muted">Obligatoria para emitir facturas</p>
            </div>
            <div>
              <label className="mb-2 block text-sm font-medium text-ink">Email</label>
              <input className="input-field" type="email" value={form.email} onChange={(e) => patch("email", e.target.value)} />
            </div>
            <div>
              <label className="mb-2 block text-sm font-medium text-ink">Teléfono</label>
              <input className="input-field" value={form.phone} onChange={(e) => patch("phone", e.target.value)} />
            </div>
          </div>

          <label className="flex items-center gap-3">
            <input
              checked={form.active}
              className="h-4 w-4 rounded border-line text-brand focus:ring-brand/30"
              onChange={(e) => patch("active", e.target.checked)}
              type="checkbox"
            />
            <span className="text-sm text-ink">Cliente activo</span>
          </label>

          <div className="flex gap-3 pt-2">
            <button className="btn-secondary flex-1" disabled={saving} type="submit">
              {saving ? "Guardando..." : editingId ? "Guardar cambios" : "Crear cliente"}
            </button>
            <button className="btn-ghost" onClick={closeModal} type="button">Cancelar</button>
          </div>
        </form>
      </Modal>
    </SectionCard>
  );
}
