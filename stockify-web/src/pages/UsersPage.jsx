import { useEffect, useState } from "react";
import EmptyState from "../components/EmptyState";
import Modal from "../components/Modal";
import SectionCard from "../components/SectionCard";
import { useAuth } from "../context/AuthContext";
import { can } from "../lib/permissions";
import { apiRequest } from "../lib/api";
import { translateRole } from "../lib/translations";

const ROLES = ["owner", "admin", "manager", "clerk"];

const EMPTY_FORM = {
  name: "",
  email: "",
  password: "",
  password_confirmation: "",
  role: "clerk",
  active: true,
};

function PermissionMatrix({ allPermissions, selectedIds, onChange, disabled }) {
  const categories = Object.keys(allPermissions);
  return (
    <div className="space-y-4">
      {categories.map((category) => (
        <div key={category}>
          <p className="mb-2 text-xs font-semibold uppercase tracking-[0.22em] text-muted">{category}</p>
          <div className="grid gap-2 sm:grid-cols-2">
            {allPermissions[category].map((perm) => {
              const checked = selectedIds.includes(perm.id);
              return (
                <label key={perm.id} className="flex cursor-pointer items-start gap-2 rounded-xl p-2 hover:bg-cloud">
                  <input
                    checked={checked}
                    disabled={disabled}
                    onChange={() => onChange(checked ? selectedIds.filter((id) => id !== perm.id) : [...selectedIds, perm.id])}
                    type="checkbox"
                    className="mt-0.5"
                  />
                  <span className="text-sm text-ink">{perm.description}</span>
                </label>
              );
            })}
          </div>
        </div>
      ))}
    </div>
  );
}

export default function UsersPage() {
  const { user: currentUser } = useAuth();
  const canEdit = can(currentUser, "users.edit");
  const canCreate = can(currentUser, "users.create");
  const canDelete = can(currentUser, "users.delete");

  const [users, setUsers] = useState([]);
  const [allPermissions, setAllPermissions] = useState({});
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");

  const [modalOpen, setModalOpen] = useState(false);
  const [editingUser, setEditingUser] = useState(null);
  const [form, setForm] = useState(EMPTY_FORM);
  const [isDirty, setIsDirty] = useState(false);
  const [extraPermIds, setExtraPermIds] = useState([]);
  const [saving, setSaving] = useState(false);
  const [formError, setFormError] = useState("");
  const [deactivating, setDeactivating] = useState(null);

  useEffect(() => { loadData(); }, []);

  async function loadData() {
    setLoading(true);
    setError("");
    try {
      const [usersRes, permsRes] = await Promise.all([
        apiRequest("/api/v1/users"),
        apiRequest("/api/v1/catalog/permissions"),
      ]);
      setUsers(usersRes.users);
      setAllPermissions(permsRes.permissions);
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
    setEditingUser(null);
    setForm(EMPTY_FORM);
    setExtraPermIds([]);
    setIsDirty(false);
    setFormError("");
    setModalOpen(true);
  }

  function openEdit(user) {
    setEditingUser(user);
    setForm({
      name: user.name,
      email: user.email,
      password: "",
      password_confirmation: "",
      role: user.role,
      active: user.active,
    });
    setExtraPermIds(user.extra_permission_ids || []);
    setIsDirty(false);
    setFormError("");
    setModalOpen(true);
  }

  function closeModal() {
    if (isDirty && !window.confirm("¿Salir sin guardar los cambios?")) return;
    setModalOpen(false);
    setIsDirty(false);
    setFormError("");
  }

  async function handleSubmit(event) {
    event.preventDefault();
    setSaving(true);
    setFormError("");
    try {
      const body = { user: { ...form } };
      if (!body.user.password) {
        delete body.user.password;
        delete body.user.password_confirmation;
      }

      let saved;
      if (editingUser) {
        saved = await apiRequest(`/api/v1/users/${editingUser.id}`, { method: "PATCH", body });
      } else {
        saved = await apiRequest("/api/v1/users", { method: "POST", body });
      }

      if (canEdit) {
        await apiRequest(`/api/v1/users/${saved.user.id}/update_permissions`, {
          method: "PATCH",
          body: { permission_ids: extraPermIds },
        });
      }

      setModalOpen(false);
      setIsDirty(false);
      await loadData();
    } catch (err) {
      setFormError(err.message);
    } finally {
      setSaving(false);
    }
  }

  async function handleDeactivate(user) {
    if (!window.confirm(`¿Desactivar a ${user.name}?`)) return;
    setDeactivating(user.id);
    try {
      await apiRequest(`/api/v1/users/${user.id}`, { method: "DELETE" });
      setModalOpen(false);
      setIsDirty(false);
      await loadData();
    } catch (err) {
      setError(err.message);
    } finally {
      setDeactivating(null);
    }
  }

  return (
    <>
      <SectionCard
        title="Usuarios"
        description="Gestiona los miembros de tu compañía, sus roles y permisos."
        action={
          canCreate && (
            <button className="btn-secondary" onClick={openCreate} type="button">
              Nuevo usuario
            </button>
          )
        }
      >
        {error ? <div className="mb-4 rounded-2xl bg-accent/5 px-4 py-3 text-sm text-accent">{error}</div> : null}

        {loading ? (
          <p className="text-sm text-muted">Cargando usuarios...</p>
        ) : users.length ? (
          <div className="overflow-x-auto">
            <table className="min-w-full text-left text-sm">
              <thead className="text-xs uppercase tracking-[0.22em] text-muted">
                <tr>
                  <th className="pb-4">Usuario</th>
                  <th className="pb-4">Rol</th>
                  <th className="pb-4">Estado</th>
                  <th className="pb-4">Permisos extra</th>
                  {canEdit && <th className="pb-4 text-right">Acciones</th>}
                </tr>
              </thead>
              <tbody className="divide-y divide-line">
                {users.map((u) => (
                  <tr key={u.id}>
                    <td className="py-4 align-top">
                      <p className="font-medium text-ink">{u.name}</p>
                      <p className="mt-0.5 text-sm text-muted">{u.email}</p>
                    </td>
                    <td className="py-4 align-top">
                      <span className="chip">{translateRole(u.role)}</span>
                    </td>
                    <td className="py-4 align-top">
                      <span className={`chip ${u.active ? "" : "chip-alert"}`}>
                        {u.active ? "Activo" : "Inactivo"}
                      </span>
                    </td>
                    <td className="py-4 align-top text-sm text-muted">
                      {u.extra_permission_ids?.length > 0 ? `+${u.extra_permission_ids.length} extra` : "—"}
                    </td>
                    {canEdit && (
                      <td className="py-4 align-top text-right">
                        <button className="btn-ghost h-9 px-4 text-sm" onClick={() => openEdit(u)} type="button">
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
          <EmptyState title="Sin usuarios" description="Crea el primer usuario de tu compañía." />
        )}
      </SectionCard>

      <Modal
        open={modalOpen}
        onClose={closeModal}
        title={editingUser ? "Editar usuario" : "Nuevo usuario"}
        size="xl"
      >
        <form className="space-y-4" onSubmit={handleSubmit}>
          {formError && (
            <div className="rounded-2xl bg-accent/5 px-4 py-3 text-sm text-accent">{formError}</div>
          )}

          <div className="grid gap-4 sm:grid-cols-2">
            <div>
              <label className="mb-2 block text-sm font-medium text-ink">Nombre</label>
              <input className="input-field" required value={form.name} onChange={(e) => patch("name", e.target.value)} />
            </div>
            <div>
              <label className="mb-2 block text-sm font-medium text-ink">Email</label>
              <input className="input-field" type="email" required value={form.email} onChange={(e) => patch("email", e.target.value)} />
            </div>
          </div>

          <div className="grid gap-4 sm:grid-cols-2">
            <div>
              <label className="mb-2 block text-sm font-medium text-ink">
                Contraseña {editingUser && <span className="text-muted font-normal">(opcional)</span>}
              </label>
              <input
                className="input-field"
                type="password"
                required={!editingUser}
                value={form.password}
                onChange={(e) => patch("password", e.target.value)}
              />
            </div>
            <div>
              <label className="mb-2 block text-sm font-medium text-ink">Confirmar</label>
              <input
                className="input-field"
                type="password"
                required={!editingUser || form.password.length > 0}
                value={form.password_confirmation}
                onChange={(e) => patch("password_confirmation", e.target.value)}
              />
            </div>
          </div>

          <div className="grid gap-4 sm:grid-cols-2">
            <div>
              <label className="mb-2 block text-sm font-medium text-ink">Rol</label>
              <select className="input-field" value={form.role} onChange={(e) => patch("role", e.target.value)}>
                {ROLES.map((r) => <option key={r} value={r}>{translateRole(r)}</option>)}
              </select>
            </div>
            {editingUser && (
              <div className="flex items-end pb-1">
                <label className="flex items-center gap-3 text-sm text-muted">
                  <input
                    type="checkbox"
                    checked={form.active}
                    onChange={(e) => patch("active", e.target.checked)}
                  />
                  Usuario activo
                </label>
              </div>
            )}
          </div>

          {Object.keys(allPermissions).length > 0 && (
            <div>
              <p className="mb-1 text-sm font-medium text-ink">Permisos adicionales</p>
              <p className="mb-3 text-xs text-muted">Se suman a los permisos base del rol seleccionado.</p>
              <PermissionMatrix
                allPermissions={allPermissions}
                selectedIds={extraPermIds}
                onChange={(ids) => { setExtraPermIds(ids); setIsDirty(true); }}
                disabled={!canEdit}
              />
            </div>
          )}

          <div className="flex flex-wrap gap-3 pt-2">
            <button className="btn-secondary flex-1" disabled={saving} type="submit">
              {saving ? "Guardando..." : editingUser ? "Actualizar usuario" : "Crear usuario"}
            </button>
            {editingUser && canDelete && editingUser.id !== currentUser.id && (
              <button
                className="btn-ghost border-accent/30 text-accent hover:bg-accent/5"
                disabled={deactivating === editingUser.id}
                onClick={() => handleDeactivate(editingUser)}
                type="button"
              >
                {deactivating === editingUser.id ? "Desactivando..." : "Desactivar"}
              </button>
            )}
            <button className="btn-ghost" onClick={closeModal} type="button">Cancelar</button>
          </div>
        </form>
      </Modal>
    </>
  );
}
