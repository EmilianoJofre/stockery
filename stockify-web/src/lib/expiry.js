// Urgencia de vencimiento de un lote.
//
// El backend entrega `days_to_expiry` y `expired` ya calculados; aca solo se
// traduce a lenguaje y color. Los umbrales son de negocio: una semana es el
// margen tipico para liquidar o retirar un perecible.
export const EXPIRY_HORIZONS = [
  { days: 7, label: "7 dias" },
  { days: 30, label: "30 dias" },
  { days: 90, label: "90 dias" },
];

export function expiryStatus(lot) {
  const days = lot.days_to_expiry;

  if (days === null || days === undefined) {
    return { level: "none", label: "Sin vencimiento", chipClass: "", rowClass: "" };
  }

  if (days < 0) {
    const ago = Math.abs(days);
    return {
      level: "expired",
      label: ago === 1 ? "Vencido ayer" : `Vencido hace ${ago} dias`,
      chipClass: "border-transparent bg-rose-100 text-rose-700",
      rowClass: "bg-rose-50/60",
    };
  }

  if (days === 0) {
    return {
      level: "today",
      label: "Vence hoy",
      chipClass: "border-transparent bg-rose-100 text-rose-700",
      rowClass: "bg-rose-50/40",
    };
  }

  if (days <= 7) {
    return {
      level: "critical",
      label: days === 1 ? "Vence manana" : `Vence en ${days} dias`,
      chipClass: "border-transparent bg-amber-100 text-amber-800",
      rowClass: "bg-amber-50/50",
    };
  }

  if (days <= 30) {
    return {
      level: "soon",
      label: `Vence en ${days} dias`,
      chipClass: "border-transparent bg-amber-50 text-amber-700",
      rowClass: "",
    };
  }

  return {
    level: "ok",
    label: `Vence en ${days} dias`,
    chipClass: "",
    rowClass: "",
  };
}

// Resumen para las tarjetas de cabecera.
export function summarizeLots(lots) {
  return lots.reduce(
    (acc, lot) => {
      const { level } = expiryStatus(lot);
      acc.units += lot.quantity_remaining;
      if (level === "expired") {
        acc.expired += 1;
        acc.expiredUnits += lot.quantity_remaining;
      } else if (level === "today" || level === "critical") {
        acc.critical += 1;
        acc.criticalUnits += lot.quantity_remaining;
      }
      return acc;
    },
    { units: 0, expired: 0, expiredUnits: 0, critical: 0, criticalUnits: 0 }
  );
}
