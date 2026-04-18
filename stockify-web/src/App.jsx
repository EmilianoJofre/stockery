import clsx from "clsx";
import { Navigate, Route, Routes } from "react-router-dom";
import { AuthProvider, useAuth } from "./context/AuthContext";
import HeaderBar from "./components/HeaderBar";
import BrandMark from "./components/BrandMark";
import Sidebar from "./components/Sidebar";
import DashboardPage from "./pages/DashboardPage";
import InventoryPage from "./pages/InventoryPage";
import LoginPage from "./pages/LoginPage";
import ProductsPage from "./pages/ProductsPage";
import PurchasesPage from "./pages/PurchasesPage";
import ReportsPage from "./pages/ReportsPage";
import SalesPage from "./pages/SalesPage";
import UsersPage from "./pages/UsersPage";
import { useMemo, useState } from "react";

const PAGE_META = {
  dashboard: {
    title: "Inteligencia operativa",
    eyebrow: "Panel",
    description: "Sigue el riesgo de stock, la velocidad de venta y la actividad de compra desde un solo centro de control.",
  },
  products: {
    title: "Catalogo de productos",
    eyebrow: "Productos",
    description: "Mantiene la calidad de los SKU, sus precios y umbrales desde una sola fuente de verdad.",
  },
  inventory: {
    title: "Control de inventario",
    eyebrow: "Inventario",
    description: "Visualiza stock por ubicacion, corrige diferencias y monitorea el historial de ajustes.",
  },
  purchases: {
    title: "Recepcion de compras",
    eyebrow: "Compras",
    description: "Registra ordenes entrantes y actualiza stock a medida que llegan los productos.",
  },
  sales: {
    title: "Flujo de ventas",
    eyebrow: "Ventas",
    description: "Registra ordenes salientes y refleja el impacto en inventario al instante.",
  },
  reports: {
    title: "Suite de reportes",
    eyebrow: "Reportes",
    description: "Revisa resumenes operativos y exporta snapshots limpios en CSV.",
  },
  users: {
    title: "Gestion de usuarios",
    eyebrow: "Usuarios",
    description: "Administra los miembros de tu compania, sus roles y permisos de acceso.",
  },
};

function Shell() {
  const [drawerOpen, setDrawerOpen] = useState(false);
  const [sidebarOpen, setSidebarOpen] = useState(() => {
    if (typeof window === "undefined") {
      return true;
    }

    return window.localStorage.getItem("stockery.sidebar-open") !== "false";
  });
  const { user, logout } = useAuth();

  const pageMeta = useMemo(() => PAGE_META, []);

  function updateSidebarOpen(next) {
    setSidebarOpen((current) => {
      const resolved = typeof next === "function" ? next(current) : next;

      if (typeof window !== "undefined") {
        window.localStorage.setItem("stockery.sidebar-open", String(resolved));
      }

      return resolved;
    });
  }

  function handleMenuToggle() {
    if (typeof window !== "undefined" && window.innerWidth >= 1024) {
      updateSidebarOpen((current) => !current);
      return;
    }

    setDrawerOpen(true);
  }

  return (
    <div className="min-h-screen bg-transparent">
      <Sidebar
        desktopOpen={sidebarOpen}
        mobileOpen={drawerOpen}
        onDesktopClose={() => updateSidebarOpen(false)}
        onMobileClose={() => setDrawerOpen(false)}
        user={user}
      />

      <div
        className={clsx(
          "transition-[padding] duration-300",
          sidebarOpen ? "lg:pl-[16rem]" : "lg:pl-0"
        )}
      >
        <HeaderBar pageMeta={pageMeta} onMenu={handleMenuToggle} onLogout={logout} sidebarOpen={sidebarOpen} user={user} />
        <main className="mx-auto max-w-[1440px] px-4 pb-10 pt-6 sm:px-6 lg:px-8">
          <Routes>
            <Route path="/dashboard" element={<DashboardPage />} />
            <Route path="/products" element={<ProductsPage />} />
            <Route path="/inventory" element={<InventoryPage />} />
            <Route path="/purchases" element={<PurchasesPage />} />
            <Route path="/sales" element={<SalesPage />} />
            <Route path="/reports" element={<ReportsPage />} />
            <Route path="/users" element={<UsersPage />} />
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
          <div className="shrink-0">
            <BrandMark compact />
          </div>
          <div>
            <p className="text-sm font-semibold uppercase tracking-[0.2em] text-muted">Stockery</p>
            <p className="text-lg font-medium text-ink">Inicializando centro de control...</p>
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
