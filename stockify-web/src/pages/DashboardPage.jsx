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
    return <EmptyState title="Dashboard unavailable" description={error} />;
  }

  return (
    <div className="space-y-6">
      <div className="grid gap-4 md:grid-cols-2 xl:grid-cols-5">
        <StatCard accent label="Monthly sales" note="Closed revenue in the current month." type="currency" value={data.metrics.sales_month} />
        <StatCard label="Products" note="Catalog entries across all active locations." value={data.metrics.total_products} />
        <StatCard label="Stores" note="Operating locations connected to Stockify." value={data.metrics.active_stores} />
        <StatCard label="Low stock" note="SKU and store combinations under threshold." value={data.metrics.low_stock_alerts} />
        <StatCard label="Monthly purchases" note="Inbound inventory value booked this month." type="currency" value={data.metrics.purchases_month} />
      </div>

      <div className="grid gap-6 xl:grid-cols-[1.3fr_0.9fr]">
        <SectionCard
          action={
            <div className="flex flex-wrap gap-3">
              <Link className="btn-secondary" to="/products">
                Add Product
              </Link>
              <Link className="btn-ghost" to="/reports">
                View Reports
              </Link>
            </div>
          }
          description="Immediate focus items requiring commercial or purchasing action."
          title="Low Stock Alerts"
        >
          {loading ? (
            <p className="text-sm text-muted">Loading dashboard cards...</p>
          ) : data.low_stock_alerts.length ? (
            <div className="grid gap-4 md:grid-cols-2">
              {data.low_stock_alerts.map((alert) => (
                <div key={alert.id} className="rounded-2xl border border-line bg-cloud/70 p-4">
                  <div className="flex items-start justify-between gap-3">
                    <div>
                      <p className="text-lg font-semibold text-ink">{alert.product_name}</p>
                      <p className="text-sm text-muted">
                        {alert.sku} · {alert.store_name}
                      </p>
                    </div>
                    <span className="chip chip-alert">Low stock</span>
                  </div>
                  <p className="mt-6 text-4xl font-semibold tracking-[-0.05em] text-ink">{alert.quantity}</p>
                  <p className="mt-2 text-sm text-muted">Threshold: {alert.threshold} units</p>
                </div>
              ))}
            </div>
          ) : (
            <EmptyState
              description="All tracked stock is currently above its configured threshold."
              title="No stock alerts"
            />
          )}
        </SectionCard>

        <SectionCard
          description="Shortcut actions for daily operations."
          title="Quick Actions"
        >
          <div className="space-y-3">
            {[
              { to: "/inventory", title: "Adjust inventory", copy: "Correct counts, losses, or receiving variances." },
              { to: "/purchases", title: "Record purchase", copy: "Receive supplier goods and refresh stock levels." },
              { to: "/sales", title: "Create sale", copy: "Process outbound orders and decrease inventory." },
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
        <SectionCard description="Recently received inventory, suppliers, and values." title="Recent Purchases">
          {loading ? (
            <p className="text-sm text-muted">Loading purchases...</p>
          ) : data.recent_purchases.length ? (
            <div className="overflow-x-auto">
              <table className="min-w-full text-left text-sm">
                <thead className="text-xs uppercase tracking-[0.22em] text-muted">
                  <tr>
                    <th className="pb-4">Reference</th>
                    <th className="pb-4">Supplier</th>
                    <th className="pb-4">Store</th>
                    <th className="pb-4">Received</th>
                    <th className="pb-4 text-right">Total</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-line">
                  {data.recent_purchases.map((purchase) => (
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
            </div>
          ) : (
            <EmptyState description="No purchases have been recorded yet." title="No purchase activity" />
          )}
        </SectionCard>

        <SectionCard description="Most recent outbound transactions and revenue impact." title="Recent Sales">
          {loading ? (
            <p className="text-sm text-muted">Loading sales...</p>
          ) : data.recent_sales.length ? (
            <div className="overflow-x-auto">
              <table className="min-w-full text-left text-sm">
                <thead className="text-xs uppercase tracking-[0.22em] text-muted">
                  <tr>
                    <th className="pb-4">Reference</th>
                    <th className="pb-4">Customer</th>
                    <th className="pb-4">Store</th>
                    <th className="pb-4">Date</th>
                    <th className="pb-4 text-right">Total</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-line">
                  {data.recent_sales.map((sale) => (
                    <tr key={sale.id}>
                      <td className="py-4 font-medium text-ink">{sale.reference}</td>
                      <td className="py-4 text-muted">{sale.customer_name || "Walk-in customer"}</td>
                      <td className="py-4 text-muted">{sale.store.name}</td>
                      <td className="py-4 text-muted">{formatDate(sale.sold_on)}</td>
                      <td className="py-4 text-right font-medium text-ink">{formatCurrency(sale.total_amount)}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          ) : (
            <EmptyState description="No sales have been recorded yet." title="No sales activity" />
          )}
        </SectionCard>
      </div>
    </div>
  );
}
