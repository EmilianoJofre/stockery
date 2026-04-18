import { Link } from "react-router-dom";
import { useEffect, useState } from "react";
import EmptyState from "../components/EmptyState";
import SectionCard from "../components/SectionCard";
import StatCard from "../components/StatCard";
import { apiRequest } from "../lib/api";
import { formatCurrency, formatDate } from "../lib/format";

const INITIAL_DATA = {
  metrics: {
    total_products: 0,
    active_stores: 0,
    low_stock_alerts: 0,
    sales_month: 0,
    purchases_month: 0,
  },
  low_stock_alerts: [],
  recent_purchases: [],
  recent_sales: [],
};

export default function DashboardPage() {
  const [data, setData] = useState(INITIAL_DATA);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");

  useEffect(() => {
    loadDashboard();
  }, []);

  async function loadDashboard() {
    setLoading(true);
    setError("");

    try {
      const response = await apiRequest("/api/v1/dashboard");
      setData(response);
    } catch (requestError) {
      setError(requestError.message);
    } finally {
      setLoading(false);
    }
  }

  if (error) {
    return <EmptyState title="Panel no disponible" description={error} />;
  }

  const singleStore = data.metrics.active_stores <= 1;

  return (
    <div className="space-y-6">
      <div className={`grid gap-4 md:grid-cols-2 ${singleStore ? "xl:grid-cols-4" : "xl:grid-cols-5"}`}>
        <StatCard accent label="Ventas del mes" note="Ingresos cerrados en el mes actual." type="currency" value={data.metrics.sales_month} />
        <StatCard label="Productos" note="Entradas del catalogo en todas las ubicaciones activas." value={data.metrics.total_products} />
        {!singleStore && <StatCard label="Tiendas" note="Ubicaciones operativas conectadas a Stockify." value={data.metrics.active_stores} />}
        <StatCard label="Stock bajo" note="Combinaciones de SKU y tienda bajo el umbral." value={data.metrics.low_stock_alerts} />
        <StatCard label="Compras del mes" note="Valor de inventario entrante registrado este mes." type="currency" value={data.metrics.purchases_month} />
      </div>

      <div className="grid gap-6 xl:grid-cols-[1.3fr_0.9fr]">
        <SectionCard
          action={
            <div className="flex flex-wrap gap-3">
              <Link className="btn-secondary" to="/products">
                Agregar producto
              </Link>
              <Link className="btn-ghost" to="/reports">
                Ver reportes
              </Link>
            </div>
          }
          description="Puntos de foco inmediato que requieren accion comercial o de abastecimiento."
          title="Alertas de stock bajo"
        >
          {loading ? (
            <p className="text-sm text-muted">Cargando tarjetas del panel...</p>
          ) : data.low_stock_alerts.length ? (
            <div className="grid gap-4 md:grid-cols-2">
              {data.low_stock_alerts.map((alert) => (
                <div key={alert.id} className="rounded-2xl border border-line bg-cloud/70 p-4">
                  <div className="flex items-start justify-between gap-3">
                    <div>
                      <p className="text-lg font-semibold text-ink">{alert.product_name}</p>
                      <p className="text-sm text-muted">
                        {singleStore ? alert.sku : `${alert.sku} · ${alert.store_name}`}
                      </p>
                    </div>
                    <span className="chip chip-alert">Stock bajo</span>
                  </div>
                  <p className="mt-6 text-4xl font-semibold tracking-[-0.05em] text-ink">{alert.quantity}</p>
                  <p className="mt-2 text-sm text-muted">Umbral: {alert.threshold} unidades</p>
                </div>
              ))}
            </div>
          ) : (
            <EmptyState
              description="Todo el stock monitoreado esta por encima de su umbral configurado."
              title="Sin alertas de stock"
            />
          )}
        </SectionCard>

        <SectionCard
          description="Acciones rapidas para la operacion diaria."
          title="Acciones rapidas"
        >
          <div className="space-y-3">
            {[
              { to: "/inventory", title: "Ajustar inventario", copy: "Corrige conteos, mermas o diferencias de recepcion." },
              { to: "/purchases", title: "Registrar compra", copy: "Recibe mercaderia de proveedores y actualiza stock." },
              { to: "/sales", title: "Crear venta", copy: "Procesa ordenes salientes y descuenta inventario." },
            ].map((item) => (
              <Link
                key={item.title}
                className="block rounded-2xl border border-line bg-white px-5 py-4 transition hover:-translate-y-0.5 hover:shadow-panel"
                to={item.to}
              >
                <p className="text-sm font-semibold text-ink">{item.title}</p>
                <p className="mt-2 text-sm leading-6 text-muted">{item.copy}</p>
              </Link>
            ))}
          </div>
        </SectionCard>
      </div>

      <div className="grid gap-6 xl:grid-cols-2">
        <SectionCard description="Inventario recibido recientemente, proveedores y montos." title="Compras recientes">
          {loading ? (
            <p className="text-sm text-muted">Cargando compras...</p>
          ) : data.recent_purchases.length ? (
            <div className="overflow-x-auto">
              <table className="min-w-full text-left text-sm">
                <thead className="text-xs uppercase tracking-[0.22em] text-muted">
                  <tr>
                    <th className="pb-4">Referencia</th>
                    <th className="pb-4">Proveedor</th>
                    {!singleStore && <th className="pb-4">Tienda</th>}
                    <th className="pb-4">Recibido</th>
                    <th className="pb-4 text-right">Total</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-line">
                  {data.recent_purchases.map((purchase) => (
                    <tr key={purchase.id}>
                      <td className="py-4 font-medium text-ink">{purchase.reference}</td>
                      <td className="py-4 text-muted">{purchase.supplier.name}</td>
                      {!singleStore && <td className="py-4 text-muted">{purchase.store.name}</td>}
                      <td className="py-4 text-muted">{formatDate(purchase.received_on)}</td>
                      <td className="py-4 text-right font-medium text-ink">{formatCurrency(purchase.total_amount)}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          ) : (
            <EmptyState description="Aun no se han registrado compras." title="Sin actividad de compras" />
          )}
        </SectionCard>

        <SectionCard description="Transacciones salientes mas recientes e impacto en ingresos." title="Ventas recientes">
          {loading ? (
            <p className="text-sm text-muted">Cargando ventas...</p>
          ) : data.recent_sales.length ? (
            <div className="overflow-x-auto">
              <table className="min-w-full text-left text-sm">
                <thead className="text-xs uppercase tracking-[0.22em] text-muted">
                  <tr>
                    <th className="pb-4">Referencia</th>
                    <th className="pb-4">Cliente</th>
                    {!singleStore && <th className="pb-4">Tienda</th>}
                    <th className="pb-4">Fecha</th>
                    <th className="pb-4 text-right">Total</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-line">
                  {data.recent_sales.map((sale) => (
                    <tr key={sale.id}>
                      <td className="py-4 font-medium text-ink">{sale.reference}</td>
                      <td className="py-4 text-muted">{sale.customer_name || "Cliente de mostrador"}</td>
                      {!singleStore && <td className="py-4 text-muted">{sale.store.name}</td>}
                      <td className="py-4 text-muted">{formatDate(sale.sold_on)}</td>
                      <td className="py-4 text-right font-medium text-ink">{formatCurrency(sale.total_amount)}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          ) : (
            <EmptyState description="Aun no se han registrado ventas." title="Sin actividad de ventas" />
          )}
        </SectionCard>
      </div>
    </div>
  );
}
