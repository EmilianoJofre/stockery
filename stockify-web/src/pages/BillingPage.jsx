import { useEffect, useMemo, useState } from "react";
import EmptyState from "../components/EmptyState";
import Modal from "../components/Modal";
import SectionCard from "../components/SectionCard";
import { useAuth } from "../context/AuthContext";
import { can } from "../lib/permissions";
import { apiRequest } from "../lib/api";
import { formatDate } from "../lib/format";
import { translateDocumentType } from "../lib/translations";

const EMPTY_SETTINGS = {
  provider: "simulated",
  environment: "sandbox",
  folio_strategy: "own_caf",
  api_key: "",
  rut_emisor: "",
  razon_social: "",
  giro: "",
  acteco: "",
  dir_origen: "",
  cmna_origen: "",
  cdg_sii_sucur: "",
  active: true,
};

const EMPTY_CAF = {
  document_type: 39,
  range_start: "",
  range_end: "",
  next_folio: "",
  authorized_on: "",
  expires_on: "",
};

const PROVIDER_LABELS = {
  simulated: "Simulado (sin conexión al SII)",
  openfactura: "OpenFactura (Haulmer)",
};

const STRATEGY_LABELS = {
  own_caf: "Folios propios (CAF cargado aquí)",
  provider: "Folios que asigna el proveedor",
};

export default function BillingPage() {
  const { user } = useAuth();
  const canManage = can(user, "billing.manage");

  const [settings, setSettings] = useState(EMPTY_SETTINGS);
  const [apiKeyConfigured, setApiKeyConfigured] = useState(false);
  const [cafRanges, setCafRanges] = useState([]);
  const [documentTypes, setDocumentTypes] = useState({});
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [saving, setSaving] = useState(false);
  const [savedAt, setSavedAt] = useState(null);

  const [cafOpen, setCafOpen] = useState(false);
  const [cafForm, setCafForm] = useState(EMPTY_CAF);
  const [cafSaving, setCafSaving] = useState(false);
  const [cafError, setCafError] = useState("");

  useEffect(() => { loadPage(); }, []);

  async function loadPage() {
    setLoading(true);
    setError("");
    try {
      const response = await apiRequest("/api/v1/billing/settings");
      if (response.settings) {
        // La api_key nunca vuelve del servidor; el campo queda vacío y solo se
        // envía cuando el usuario escribe una nueva.
        setSettings({ ...EMPTY_SETTINGS, ...response.settings, api_key: "" });
        setApiKeyConfigured(response.settings.api_key_configured);
      }
      setCafRanges(response.caf_ranges);
      setDocumentTypes(response.document_types || {});
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  }

  const needsApiKey = settings.provider !== "simulated";
  const usesOwnCaf = settings.folio_strategy === "own_caf";

  const documentOptions = useMemo(
    () => Object.entries(documentTypes).map(([name, code]) => ({ name, code })),
    [documentTypes]
  );

  function patch(field, value) {
    setSettings((s) => ({ ...s, [field]: value }));
    setSavedAt(null);
  }

  function patchCaf(field, value) {
    setCafForm((f) => ({ ...f, [field]: value }));
  }

  async function handleSave(event) {
    event.preventDefault();
    setSaving(true);
    setError("");
    try {
      const response = await apiRequest("/api/v1/billing/settings", {
        method: "PUT",
        body: { settings },
      });
      setSettings({ ...EMPTY_SETTINGS, ...response.settings, api_key: "" });
      setApiKeyConfigured(response.settings.api_key_configured);
      setSavedAt(new Date());
    } catch (err) {
      setError(err.message);
    } finally {
      setSaving(false);
    }
  }

  async function handleCafSubmit(event) {
    event.preventDefault();
    setCafSaving(true);
    setCafError("");
    try {
      await apiRequest("/api/v1/billing/caf_ranges", {
        method: "POST",
        body: {
          caf_range: {
            ...cafForm,
            document_type: Number(cafForm.document_type),
            range_start: Number(cafForm.range_start),
            range_end: Number(cafForm.range_end),
            next_folio: cafForm.next_folio ? Number(cafForm.next_folio) : "",
          },
        },
      });
      setCafOpen(false);
      setCafForm(EMPTY_CAF);
      await loadPage();
    } catch (err) {
      setCafError(err.message);
    } finally {
      setCafSaving(false);
    }
  }

  async function toggleCaf(range) {
    try {
      await apiRequest(`/api/v1/billing/caf_ranges/${range.id}`, {
        method: "PATCH",
        body: { active: !range.active },
      });
      await loadPage();
    } catch (err) {
      setError(err.message);
    }
  }

  if (!canManage) {
    return (
      <EmptyState
        title="Sin acceso"
        description="Necesitas el permiso de configuración de facturación para ver esta sección."
      />
    );
  }

  return (
    <div className="space-y-6">
      {settings.provider === "simulated" && (
        <div className="rounded-2xl border border-amber-200 bg-amber-50 px-5 py-4">
          <p className="text-sm font-semibold text-amber-900">Modo simulado activo</p>
          <p className="mt-1 text-[13px] leading-6 text-amber-800">
            Los documentos se registran con folio y quedan inmutables, pero <strong>no se envían al
            SII ni tienen validez tributaria</strong>. Sirve para probar el flujo completo antes de
            contratar un proveedor y obtener el certificado digital.
          </p>
        </div>
      )}

      <SectionCard
        title="Emisión electrónica"
        description="Configuración del emisor y del proveedor que transmite los documentos al SII."
      >
        {error ? <div className="mb-4 rounded-2xl bg-accent/5 px-4 py-3 text-sm text-accent">{error}</div> : null}

        {loading ? (
          <p className="text-sm text-muted">Cargando configuración...</p>
        ) : (
          <form className="space-y-5" onSubmit={handleSave}>
            <div className="grid gap-4 sm:grid-cols-3">
              <div>
                <label className="mb-2 block text-sm font-medium text-ink">Proveedor</label>
                <select className="input-field" value={settings.provider} onChange={(e) => patch("provider", e.target.value)}>
                  {Object.entries(PROVIDER_LABELS).map(([value, label]) => (
                    <option key={value} value={value}>{label}</option>
                  ))}
                </select>
              </div>
              <div>
                <label className="mb-2 block text-sm font-medium text-ink">Ambiente</label>
                <select className="input-field" value={settings.environment} onChange={(e) => patch("environment", e.target.value)}>
                  <option value="sandbox">Pruebas</option>
                  <option value="production">Producción</option>
                </select>
              </div>
              <div>
                <label className="mb-2 block text-sm font-medium text-ink">Origen del folio</label>
                <select className="input-field" value={settings.folio_strategy} onChange={(e) => patch("folio_strategy", e.target.value)}>
                  {Object.entries(STRATEGY_LABELS).map(([value, label]) => (
                    <option key={value} value={value}>{label}</option>
                  ))}
                </select>
              </div>
            </div>

            {needsApiKey && (
              <div>
                <label className="mb-2 block text-sm font-medium text-ink">
                  API key del proveedor
                  {apiKeyConfigured && (
                    <span className="ml-2 chip border-transparent bg-brand/10 text-brand">Configurada</span>
                  )}
                </label>
                <input
                  className="input-field"
                  placeholder={apiKeyConfigured ? "Déjala vacía para conservar la actual" : "Pega aquí la API key"}
                  type="password"
                  value={settings.api_key}
                  onChange={(e) => patch("api_key", e.target.value)}
                />
                <p className="mt-2 text-xs text-muted">
                  Se guarda cifrada y nunca vuelve al navegador.
                </p>
              </div>
            )}

            <div>
              <p className="mb-3 text-xs font-semibold uppercase tracking-[0.2em] text-muted">
                Datos del emisor (van en el encabezado del DTE)
              </p>
              <div className="grid gap-4 sm:grid-cols-2">
                <div>
                  <label className="mb-2 block text-sm font-medium text-ink">RUT del emisor</label>
                  <input className="input-field" placeholder="76543210-K" value={settings.rut_emisor || ""} onChange={(e) => patch("rut_emisor", e.target.value)} />
                </div>
                <div>
                  <label className="mb-2 block text-sm font-medium text-ink">Razón social</label>
                  <input className="input-field" value={settings.razon_social || ""} onChange={(e) => patch("razon_social", e.target.value)} />
                </div>
                <div>
                  <label className="mb-2 block text-sm font-medium text-ink">Giro</label>
                  <input className="input-field" value={settings.giro || ""} onChange={(e) => patch("giro", e.target.value)} />
                </div>
                <div>
                  <label className="mb-2 block text-sm font-medium text-ink">Código de actividad económica</label>
                  <input className="input-field" placeholder="471100" value={settings.acteco || ""} onChange={(e) => patch("acteco", e.target.value)} />
                </div>
                <div>
                  <label className="mb-2 block text-sm font-medium text-ink">Dirección de origen</label>
                  <input className="input-field" value={settings.dir_origen || ""} onChange={(e) => patch("dir_origen", e.target.value)} />
                </div>
                <div>
                  <label className="mb-2 block text-sm font-medium text-ink">Comuna de origen</label>
                  <input className="input-field" value={settings.cmna_origen || ""} onChange={(e) => patch("cmna_origen", e.target.value)} />
                </div>
              </div>
            </div>

            <div className="flex items-center gap-3 pt-2">
              <button className="btn-secondary" disabled={saving} type="submit">
                {saving ? "Guardando..." : "Guardar configuración"}
              </button>
              {savedAt && <span className="text-sm text-muted">Guardado</span>}
            </div>
          </form>
        )}
      </SectionCard>

      {usesOwnCaf && (
        <SectionCard
          title="Folios autorizados (CAF)"
          description="Rangos de folios entregados por el SII. Cada documento emitido consume uno."
          action={
            <button className="btn-secondary" onClick={() => setCafOpen(true)} type="button">
              Cargar rango
            </button>
          }
        >
          {cafRanges.length ? (
            <div className="overflow-x-auto">
              <table className="min-w-full text-left text-sm">
                <thead className="text-xs uppercase tracking-[0.22em] text-muted">
                  <tr>
                    <th className="pb-4">Documento</th>
                    <th className="pb-4">Rango</th>
                    <th className="pb-4">Próximo folio</th>
                    <th className="pb-4">Disponibles</th>
                    <th className="pb-4">Vence</th>
                    <th className="pb-4">Estado</th>
                    <th className="pb-4 text-right">Acción</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-line">
                  {cafRanges.map((range) => {
                    const low = !range.exhausted && range.available_folios <= 10;
                    return (
                      <tr key={range.id} className={range.exhausted ? "bg-rose-50/50" : low ? "bg-amber-50/40" : ""}>
                        <td className="py-4">
                          <p className="font-medium text-ink">
                            {translateDocumentType(range.document_name, { short: true })}
                          </p>
                          <p className="text-sm text-muted">Tipo {range.document_type}</p>
                        </td>
                        <td className="py-4 text-muted">{range.range_start} – {range.range_end}</td>
                        <td className="py-4 font-medium text-ink">{range.next_folio}</td>
                        <td className="py-4">
                          <span className={`text-lg font-semibold ${low || range.exhausted ? "text-rose-700" : "text-ink"}`}>
                            {range.available_folios}
                          </span>
                        </td>
                        <td className="py-4 text-muted">{range.expires_on ? formatDate(range.expires_on) : "—"}</td>
                        <td className="py-4">
                          {range.exhausted ? (
                            <span className="chip border-transparent bg-rose-100 text-rose-700">Agotado</span>
                          ) : range.expired ? (
                            <span className="chip border-transparent bg-rose-100 text-rose-700">Vencido</span>
                          ) : range.active ? (
                            <span className="chip border-transparent bg-brand/10 text-brand">Vigente</span>
                          ) : (
                            <span className="chip">Inactivo</span>
                          )}
                        </td>
                        <td className="py-4 text-right">
                          <button className="btn-ghost h-9 px-4 text-sm" onClick={() => toggleCaf(range)} type="button">
                            {range.active ? "Desactivar" : "Activar"}
                          </button>
                        </td>
                      </tr>
                    );
                  })}
                </tbody>
              </table>
            </div>
          ) : (
            <EmptyState
              title="Sin folios cargados"
              description="Sin un rango CAF vigente no se puede emitir ningún documento. Solicítalo en el portal del SII y cárgalo aquí."
            />
          )}
        </SectionCard>
      )}

      <Modal open={cafOpen} onClose={() => setCafOpen(false)} title="Cargar rango de folios" size="lg">
        <form className="space-y-4" onSubmit={handleCafSubmit}>
          {cafError && (
            <div className="rounded-2xl bg-accent/5 px-4 py-3 text-sm text-accent">{cafError}</div>
          )}

          <div>
            <label className="mb-2 block text-sm font-medium text-ink">Tipo de documento</label>
            <select className="input-field" value={cafForm.document_type} onChange={(e) => patchCaf("document_type", e.target.value)}>
              {documentOptions.map((opt) => (
                <option key={opt.code} value={opt.code}>
                  {translateDocumentType(opt.name)} ({opt.code})
                </option>
              ))}
            </select>
          </div>

          <div className="grid gap-4 sm:grid-cols-3">
            <div>
              <label className="mb-2 block text-sm font-medium text-ink">Folio inicial</label>
              <input className="input-field" required type="number" min="1" value={cafForm.range_start} onChange={(e) => patchCaf("range_start", e.target.value)} />
            </div>
            <div>
              <label className="mb-2 block text-sm font-medium text-ink">Folio final</label>
              <input className="input-field" required type="number" min="1" value={cafForm.range_end} onChange={(e) => patchCaf("range_end", e.target.value)} />
            </div>
            <div>
              <label className="mb-2 block text-sm font-medium text-ink">Próximo folio</label>
              <input className="input-field" type="number" min="1" placeholder="= inicial" value={cafForm.next_folio} onChange={(e) => patchCaf("next_folio", e.target.value)} />
            </div>
          </div>
          <p className="text-xs text-muted">
            Deja el próximo folio vacío salvo que migres desde otro sistema con folios ya consumidos.
          </p>

          <div className="grid gap-4 sm:grid-cols-2">
            <div>
              <label className="mb-2 block text-sm font-medium text-ink">Autorizado el</label>
              <input className="input-field" type="date" value={cafForm.authorized_on} onChange={(e) => patchCaf("authorized_on", e.target.value)} />
            </div>
            <div>
              <label className="mb-2 block text-sm font-medium text-ink">Vence el</label>
              <input className="input-field" type="date" value={cafForm.expires_on} onChange={(e) => patchCaf("expires_on", e.target.value)} />
            </div>
          </div>

          <div className="flex gap-3 pt-2">
            <button className="btn-secondary flex-1" disabled={cafSaving} type="submit">
              {cafSaving ? "Cargando..." : "Cargar rango"}
            </button>
            <button className="btn-ghost" onClick={() => setCafOpen(false)} type="button">Cancelar</button>
          </div>
        </form>
      </Modal>
    </div>
  );
}
