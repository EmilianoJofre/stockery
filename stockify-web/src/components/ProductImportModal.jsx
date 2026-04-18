import { useEffect, useMemo, useRef, useState } from "react";
import {
  HiArrowUpTray,
  HiCheckCircle,
  HiCloudArrowUp,
  HiDocumentArrowDown,
  HiDocumentText,
  HiExclamationTriangle,
} from "react-icons/hi2";
import { apiRequest, buildApiUrl } from "../lib/api";
import Modal from "./Modal";

const ACCEPTED_EXTENSIONS = [".xlsx", ".csv"];
const TEMPLATE_COLUMNS = ["sku", "name", "description", "price", "low_stock_threshold", "category", "active"];

function getExtension(filename) {
  const lowerName = filename.toLowerCase();
  return ACCEPTED_EXTENSIONS.find((extension) => lowerName.endsWith(extension)) || "";
}

function validateFile(file) {
  if (!file) return "Debes seleccionar un archivo para continuar.";
  if (!getExtension(file.name)) {
    return "Formato no soportado. Usa un archivo .xlsx o .csv.";
  }

  return "";
}

function parseErrorPayload(payload) {
  if (typeof payload === "string") return payload;
  return payload?.error || payload?.message || "No se pudo descargar la plantilla.";
}

function getFilenameFromHeaders(contentDisposition, fallback) {
  if (!contentDisposition) return fallback;

  const utf8Match = contentDisposition.match(/filename\*=UTF-8''([^;]+)/i);
  if (utf8Match?.[1]) return decodeURIComponent(utf8Match[1]);

  const basicMatch = contentDisposition.match(/filename="?([^"]+)"?/i);
  return basicMatch?.[1] || fallback;
}

function ResultCard({ result }) {
  if (!result) return null;

  const successTone = result.status === "success";

  return (
    <div className={`space-y-4 rounded-2xl border px-4 py-4 ${successTone ? "border-brand/20 bg-brand/5" : "border-accent/20 bg-accent/5"}`}>
      <div className="flex items-start gap-3">
        {successTone ? (
          <HiCheckCircle className="mt-0.5 h-5 w-5 shrink-0 text-brand" />
        ) : (
          <HiExclamationTriangle className="mt-0.5 h-5 w-5 shrink-0 text-accent" />
        )}
        <div className="min-w-0 flex-1">
          <p className="font-medium text-ink">{result.message}</p>
          <p className="mt-1 text-sm text-muted">
            {result.summary.processed_rows} filas procesadas, {result.summary.created} creadas y {result.summary.updated} actualizadas.
          </p>
        </div>
      </div>

      <div className="grid gap-3 sm:grid-cols-4">
        <div className="rounded-2xl border border-white/70 bg-white/80 px-4 py-3">
          <p className="text-xs uppercase tracking-[0.18em] text-muted">Procesadas</p>
          <p className="mt-2 text-2xl font-semibold tracking-[-0.04em] text-ink">{result.summary.processed_rows}</p>
        </div>
        <div className="rounded-2xl border border-white/70 bg-white/80 px-4 py-3">
          <p className="text-xs uppercase tracking-[0.18em] text-muted">Exitosas</p>
          <p className="mt-2 text-2xl font-semibold tracking-[-0.04em] text-ink">{result.summary.successful_rows}</p>
        </div>
        <div className="rounded-2xl border border-white/70 bg-white/80 px-4 py-3">
          <p className="text-xs uppercase tracking-[0.18em] text-muted">Creadas</p>
          <p className="mt-2 text-2xl font-semibold tracking-[-0.04em] text-ink">{result.summary.created}</p>
        </div>
        <div className="rounded-2xl border border-white/70 bg-white/80 px-4 py-3">
          <p className="text-xs uppercase tracking-[0.18em] text-muted">Errores</p>
          <p className="mt-2 text-2xl font-semibold tracking-[-0.04em] text-ink">{result.summary.errors}</p>
        </div>
      </div>

      {result.errors?.length ? (
        <div className="space-y-2">
          <p className="text-sm font-medium text-ink">Filas con observaciones</p>
          <div className="max-h-56 space-y-2 overflow-y-auto pr-1">
            {result.errors.map((error) => (
              <div key={`${error.row}-${error.sku || "sin-sku"}-${error.message}`} className="rounded-2xl border border-accent/10 bg-white/80 px-4 py-3">
                <p className="text-sm font-medium text-ink">
                  Fila {error.row}
                  {error.sku ? ` · ${error.sku}` : ""}
                </p>
                <p className="mt-1 text-sm text-muted">{error.message}</p>
              </div>
            ))}
          </div>
        </div>
      ) : null}
    </div>
  );
}

export default function ProductImportModal({ open, onClose, onImported }) {
  const inputRef = useRef(null);
  const [dragActive, setDragActive] = useState(false);
  const [selectedFile, setSelectedFile] = useState(null);
  const [localError, setLocalError] = useState("");
  const [importing, setImporting] = useState(false);
  const [downloadingTemplate, setDownloadingTemplate] = useState(false);
  const [result, setResult] = useState(null);

  useEffect(() => {
    if (open) return;

    setDragActive(false);
    setSelectedFile(null);
    setLocalError("");
    setImporting(false);
    setDownloadingTemplate(false);
    setResult(null);
    if (inputRef.current) inputRef.current.value = "";
  }, [open]);

  const state = useMemo(() => {
    if (importing) {
      return {
        accent: "border-brand/30 bg-brand/5 text-brand",
        icon: <HiCloudArrowUp className="h-8 w-8 text-brand" />,
        title: "Importando archivo",
        description: "Estamos validando filas y aplicando cambios en tu catálogo.",
      };
    }

    if (localError) {
      return {
        accent: "border-accent/30 bg-accent/5 text-accent",
        icon: <HiExclamationTriangle className="h-8 w-8 text-accent" />,
        title: "Archivo con problema",
        description: localError,
      };
    }

    if (selectedFile) {
      return {
        accent: "border-brand/30 bg-brand/5 text-brand",
        icon: <HiCheckCircle className="h-8 w-8 text-brand" />,
        title: "Archivo listo para importar",
        description: selectedFile.name,
      };
    }

    return {
      accent: dragActive ? "border-brand bg-brand/5 text-brand" : "border-line bg-cloud/40 text-muted",
      icon: <HiArrowUpTray className={`h-8 w-8 ${dragActive ? "text-brand" : "text-muted"}`} />,
      title: "Arrastra tu archivo aquí",
      description: "O haz click para seleccionar una plantilla .xlsx o .csv.",
    };
  }, [dragActive, importing, localError, selectedFile]);

  function assignFile(file) {
    const validationMessage = validateFile(file);
    setSelectedFile(validationMessage ? null : file);
    setLocalError(validationMessage);
    setResult(null);
  }

  function handleFileSelection(event) {
    assignFile(event.target.files?.[0]);
  }

  function handleDrop(event) {
    event.preventDefault();
    setDragActive(false);
    if (importing) return;

    assignFile(event.dataTransfer.files?.[0]);
  }

  async function handleTemplateDownload() {
    setDownloadingTemplate(true);
    setLocalError("");

    try {
      const response = await fetch(buildApiUrl("/api/v1/products/import_template"), {
        credentials: "include",
      });

      if (!response.ok) {
        const contentType = response.headers.get("content-type") || "";
        const payload = contentType.includes("application/json") ? await response.json() : await response.text();
        throw new Error(parseErrorPayload(payload));
      }

      const blob = await response.blob();
      const url = window.URL.createObjectURL(blob);
      const link = document.createElement("a");
      link.href = url;
      link.download = getFilenameFromHeaders(
        response.headers.get("content-disposition"),
        "plantilla_importacion_productos.xlsx"
      );
      document.body.appendChild(link);
      link.click();
      link.remove();
      window.URL.revokeObjectURL(url);
    } catch (error) {
      setLocalError(error.message);
    } finally {
      setDownloadingTemplate(false);
    }
  }

  async function handleSubmit(event) {
    event.preventDefault();

    const validationMessage = validateFile(selectedFile);
    if (validationMessage) {
      setLocalError(validationMessage);
      return;
    }

    setImporting(true);
    setLocalError("");
    setResult(null);

    try {
      const formData = new FormData();
      formData.append("file", selectedFile);

      const response = await apiRequest("/api/v1/products/import", {
        method: "POST",
        body: formData,
      });

      setResult(response);
      onImported?.(response);
    } catch (error) {
      setLocalError(error.message);
    } finally {
      setImporting(false);
    }
  }

  return (
    <Modal
      open={open}
      onClose={onClose}
      title="Importar productos"
      size="xl"
      disableClose={importing}
      headerAction={(
        <button
          className="btn-ghost h-10 px-4 text-sm"
          disabled={downloadingTemplate || importing}
          onClick={handleTemplateDownload}
          type="button"
        >
          <HiDocumentArrowDown className="mr-2 h-4 w-4" />
          {downloadingTemplate ? "Descargando..." : "Descargar plantilla"}
        </button>
      )}
    >
      <form className="space-y-5" onSubmit={handleSubmit}>
        <div className="flex flex-wrap gap-2">
          {TEMPLATE_COLUMNS.map((column) => (
            <span key={column} className="chip">
              {column}
            </span>
          ))}
        </div>

        <div className="rounded-2xl border border-line bg-cloud/30 px-4 py-4">
          <p className="text-sm font-medium text-ink">Cómo funciona la importación</p>
          <p className="mt-2 text-sm leading-6 text-muted">
            El sistema identifica productos por SKU. Si el SKU existe en tu compañía, se actualiza; si no existe, se crea. Las filas vacías se ignoran, las categorías deben existir previamente y las columnas opcionales vacías no sobrescriben valores existentes.
          </p>
        </div>

        <button
          className={`w-full rounded-[24px] border-2 border-dashed px-6 py-8 text-left transition ${state.accent}`}
          onClick={() => !importing && inputRef.current?.click()}
          onDragEnter={(event) => {
            event.preventDefault();
            if (!importing) setDragActive(true);
          }}
          onDragLeave={(event) => {
            event.preventDefault();
            if (event.currentTarget.contains(event.relatedTarget)) return;
            setDragActive(false);
          }}
          onDragOver={(event) => event.preventDefault()}
          onDrop={handleDrop}
          type="button"
        >
          <div className="flex flex-col items-start gap-4 sm:flex-row sm:items-center">
            <div className="rounded-2xl border border-white/80 bg-white/80 p-3 shadow-soft">
              {state.icon}
            </div>
            <div className="min-w-0 flex-1">
              <p className="text-lg font-semibold tracking-[-0.03em] text-ink">{state.title}</p>
              <p className="mt-1 text-sm leading-6 text-muted">{state.description}</p>
              {selectedFile ? (
                <div className="mt-3 flex flex-wrap items-center gap-2">
                  <span className="chip">{selectedFile.name}</span>
                  <span className="chip">{Math.max(1, Math.round(selectedFile.size / 1024))} KB</span>
                </div>
              ) : null}
            </div>
          </div>
        </button>

        <input
          ref={inputRef}
          accept=".xlsx,.csv"
          className="hidden"
          onChange={handleFileSelection}
          type="file"
        />

        <div className="rounded-2xl border border-line bg-white px-4 py-4">
          <div className="flex items-start gap-3">
            <HiDocumentText className="mt-0.5 h-5 w-5 shrink-0 text-muted" />
            <div>
              <p className="text-sm font-medium text-ink">Campos esperados</p>
              <p className="mt-1 text-sm leading-6 text-muted">
                SKU, name y price son obligatorios. Description, category, low_stock_threshold y active son opcionales.
              </p>
            </div>
          </div>
        </div>

        <ResultCard result={result} />

        <div className="flex justify-end gap-3 pt-2">
          <button className="btn-ghost" disabled={importing} onClick={onClose} type="button">
            Cerrar
          </button>
          <button className="btn-secondary min-w-[150px]" disabled={!selectedFile || importing} type="submit">
            {importing ? "Importando..." : "Guardar"}
          </button>
        </div>
      </form>
    </Modal>
  );
}
