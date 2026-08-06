// Desglose tributario para la vista previa del formulario de venta.
//
// Replica la formula del backend (Sale#calculate_amounts) a proposito: los
// precios son BRUTOS (IVA incluido), el neto se deriva del bruto y el IVA se
// obtiene por resta. Si aca se calculara distinto, el total mostrado al
// cajero no coincidiria con el del documento emitido.
export const DEFAULT_TAX_RATE = 0.19;

export function computeTaxBreakdown(items, productsById, rate = DEFAULT_TAX_RATE) {
  let grossTaxable = 0;
  let grossExempt = 0;

  items.forEach((item) => {
    const amount = (Number(item.unit_price) || 0) * (Number(item.quantity) || 0);
    if (!amount) return;

    const product = productsById[String(item.product_id)];
    if (product?.tax_exempt) {
      grossExempt += amount;
    } else {
      grossTaxable += amount;
    }
  });

  const net = Math.round(grossTaxable / (1 + rate));

  return {
    net,
    tax: grossTaxable - net,
    exempt: grossExempt,
    total: grossTaxable + grossExempt,
    hasExempt: grossExempt > 0,
  };
}
