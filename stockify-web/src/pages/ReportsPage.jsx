import { useEffect, useMemo, useState } from "react";
import AccessNotice from "../components/AccessNotice";
import EmptyState from "../components/EmptyState";
import SectionCard from "../components/SectionCard";
import { useAuth } from "../context/AuthContext";
import { apiRequest, buildApiUrl } from "../lib/api";

const REPORTS = [
  {
    key: "stock_levels",
    title: "Stock Levels",
    description: "Inventory status by store, product, threshold, and low-stock flag.",
  },
  {
    key: "top_selling_products",
    title: "Top Selling Products",
    description: "Revenue and quantity sold across completed orders.",
  },
  {
    key: "low_stock",
    title: "Low Stock",
    description: "Products currently at or below their configured threshold.",
  },
];

function prettifyHeading(value) {
  return value.replaceAll("_", " ");
}

export default function ReportsPage() {
  const { user } = useAuth();
  const canView = user?.capabilities?.can_view_reports;
  const [activeKey, setActiveKey] = useState(REPORTS[0].key);
  const [rows, setRows] = useState([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");

  const activeReport = useMemo(
    () => REPORTS.find((report) => report.key === activeKey) || REPORTS[0],
    [activeKey]
  );

  useEffect(() => {
    if (canView) {
      loadReport(activeKey);
    }
  }, [activeKey, canView]);

  async function loadReport(key) {
    setLoading(true);
    setError("");

    try {
      const response = await apiRequest(`/api/v1/reports/${key}`);
      setRows(response.rows);
    } catch (requestError) {
      setError(requestError.message);
    } finally {
      setLoading(false);
    }
  }

  if (!canView) {
    return (
      <AccessNotice description="Reports are available to Admin and Manager roles. Clerk accounts can continue working in sales and inventory modules." />
    );
  }

  return (
    <div className="space-y-6">
      <div className="grid gap-4 xl:grid-cols-3">
        {REPORTS.map((report) => (
          <button
            key={report.key}
            className={`surface-card p-5 text-left transition ${
              report.key === activeKey ? "border-brand bg-brand/5" : "hover:-translate-y-0.5"
            }`}
            onClick={() => setActiveKey(report.key)}
            type="button"
          >
            <span className="chip">{report.title}</span>
            <p className="mt-5 text-xl font-semibold tracking-[-0.04em] text-ink">{report.title}</p>
            <p className="mt-3 text-sm leading-6 text-muted">{report.description}</p>
          </button>
        ))}
      </div>

      <SectionCard
        action={
          <a className="btn-secondary" href={buildApiUrl(`/api/v1/reports/${activeKey}.csv`)}>
            Export CSV
          </a>
        }
        description={activeReport.description}
        title={`${activeReport.title} Preview`}
      >
        {error ? <div className="mb-4 rounded-2xl bg-accent/5 px-4 py-3 text-sm text-accent">{error}</div> : null}

        {loading ? (
          <p className="text-sm text-muted">Loading report preview...</p>
        ) : rows.length ? (
          <div className="overflow-x-auto">
            <table className="min-w-full text-left text-sm">
              <thead className="text-xs uppercase tracking-[0.22em] text-muted">
                <tr>
                  {Object.keys(rows[0]).map((key) => (
                    <th key={key} className="pb-4 capitalize">
                      {prettifyHeading(key)}
                    </th>
                  ))}
                </tr>
              </thead>
              <tbody className="divide-y divide-line">
                {rows.map((row, index) => (
                  <tr key={`${activeKey}-${index}`}>
                    {Object.values(row).map((value, valueIndex) => (
                      <td key={`${activeKey}-${index}-${valueIndex}`} className="py-4 text-muted">
                        {String(value)}
                      </td>
                    ))}
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        ) : (
          <EmptyState description="This report has no rows for the current dataset." title="No report rows" />
        )}
      </SectionCard>
    </div>
  );
}
