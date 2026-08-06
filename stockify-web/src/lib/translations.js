const ROLE_LABELS = {
  owner: "Propietario",
  admin: "Administrador",
  manager: "Gerente",
  clerk: "Operador",
};

const ADJUSTMENT_REASON_LABELS = {
  audit: "Auditoria",
  purchase: "Compra",
  sale: "Venta",
  display: "Exhibicion",
  damage: "Merma",
  restock: "Reposicion",
  expiry: "Vencimiento",
};

const DOCUMENT_TYPE_LABELS = {
  boleta: "Boleta electronica",
  boleta_exenta: "Boleta exenta",
  factura: "Factura electronica",
  factura_exenta: "Factura exenta",
  nota_credito: "Nota de credito",
};

const DOCUMENT_TYPE_SHORT = {
  boleta: "Boleta",
  boleta_exenta: "Boleta ex.",
  factura: "Factura",
  factura_exenta: "Factura ex.",
  nota_credito: "N. credito",
};

const SII_STATUS_LABELS = {
  draft: "Borrador",
  queued: "En cola",
  sent: "Enviado al SII",
  accepted: "Aceptado",
  rejected: "Rechazado",
};

const REPORT_HEADING_LABELS = {
  tienda: "Tienda",
  sku: "SKU",
  producto: "Producto",
  cantidad: "Cantidad",
  umbral: "Umbral",
  stock_bajo: "Stock bajo",
  cantidad_vendida: "Cantidad vendida",
  ingresos: "Ingresos",
};

export function translateRole(role) {
  return ROLE_LABELS[role] || role;
}

export function translateAdjustmentReason(reason) {
  return ADJUSTMENT_REASON_LABELS[reason] || reason;
}

export function translateReportHeading(value) {
  return REPORT_HEADING_LABELS[value] || value.replaceAll("_", " ");
}

export function translateDocumentType(value, { short = false } = {}) {
  const labels = short ? DOCUMENT_TYPE_SHORT : DOCUMENT_TYPE_LABELS;
  return labels[value] || value;
}

export function translateSiiStatus(value) {
  return SII_STATUS_LABELS[value] || value;
}
