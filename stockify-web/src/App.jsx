import { Navigate, Route, Routes } from "react-router-dom";
import { AuthProvider, useAuth } from "./context/AuthContext";
import HeaderBar from "./components/HeaderBar";
import Sidebar from "./components/Sidebar";
import DashboardPage from "./pages/DashboardPage";
import InventoryPage from "./pages/InventoryPage";
import LoginPage from "./pages/LoginPage";
import ProductsPage from "./pages/ProductsPage";
import PurchasesPage from "./pages/PurchasesPage";
import ReportsPage from "./pages/ReportsPage";
import SalesPage from "./pages/SalesPage";
import { useMemo, useState } from "react";

const PAGE_META = {
  dashboard: {
    title: "Operational Intelligence",
    eyebrow: "Dashboard",
    description: "Track live stock risk, sales velocity, and purchasing activity from one control center.",
  },
  products: {
    title: "Product Catalog",
    eyebrow: "Products",
    description: "Maintain SKU quality, pricing, and thresholds from a single source of truth.",
  },
  inventory: {
    title: "Inventory Control",
    eyebrow: "Inventory",
    description: "View stock by location, correct discrepancies, and monitor adjustment history.",
  },
  purchases: {
    title: "Supplier Intake",
    eyebrow: "Purchases",
    description: "Capture inbound orders and update stock as goods are received.",
  },
  sales: {
    title: "Sales Flow",
    eyebrow: "Sales",
    description: "Record outbound orders and reflect inventory impact instantly.",
  },
  reports: {
    title: "Reporting Suite",
    eyebrow: "Reports",
    description: "Review operational summaries and export clean CSV snapshots.",
  },
};

function Shell() {
  const [drawerOpen, setDrawerOpen] = useState(false);
  const { user, logout } = useAuth();

  const pageMeta = useMemo(() => PAGE_META, []);

  return (
    <div className="min-h-screen bg-transparent">
      <Sidebar open={drawerOpen} onClose={() => setDrawerOpen(false)} user={user} />

      <div className="lg:pl-[18rem]">
        <HeaderBar pageMeta={pageMeta} onMenu={() => setDrawerOpen(true)} onLogout={logout} user={user} />
        <main className="mx-auto max-w-[1440px] px-4 pb-10 pt-6 sm:px-6 lg:px-8">
          <Routes>
            <Route path="/dashboard" element={<DashboardPage />} />
            <Route path="/products" element={<ProductsPage />} />
            <Route path="/inventory" element={<InventoryPage />} />
            <Route path="/purchases" element={<PurchasesPage />} />
            <Route path="/sales" element={<SalesPage />} />
            <Route path="/reports" element={<ReportsPage />} />
            <Route path="*" element={<Navigate to="/dashboard" replace />} />
          </Routes>
        </main>
      </div>
    </div>
  );
}

function AppRoutes() {
  const { booting, user } = useAuth();

  if (booting) {
    return (
      <div className="flex min-h-screen items-center justify-center bg-cloud">
        <div className="surface-card flex w-full max-w-md items-center gap-4 p-6">
          <div className="h-12 w-12 animate-pulse rounded-2xl bg-brand/25" />
          <div>
            <p className="text-sm font-semibold uppercase tracking-[0.2em] text-muted">Stockify</p>
            <p className="text-lg font-medium text-ink">Initializing control center...</p>
          </div>
        </div>
      </div>
    );
  }

  return user ? <Shell /> : <LoginPage />;
}

export default function App() {
  return (
    <AuthProvider>
      <AppRoutes />
    </AuthProvider>
  );
}
