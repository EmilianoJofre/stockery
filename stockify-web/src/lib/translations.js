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
