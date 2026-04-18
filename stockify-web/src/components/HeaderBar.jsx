import { useLocation } from "react-router-dom";
import { HiArrowRightOnRectangle, HiBars3 } from "react-icons/hi2";
import { translateRole } from "../lib/translations";

const FALLBACK_META = {
  eyebrow: "Stockery",
  title: "Plataforma de inventario",
  description: "Monitorea inventario, ventas y proveedores desde un solo espacio.",
};

export default function HeaderBar({ pageMeta, onMenu, onLogout, sidebarOpen, user }) {
  const location = useLocation();
  const key = location.pathname.split("/")[1] || "dashboard";
  const current = pageMeta[key] || FALLBACK_META;

  return (
    <header className="sticky top-0 z-20 border-b border-white/70 bg-white/80 backdrop-blur">
      <div className="mx-auto flex max-w-[1440px] items-center justify-between gap-3 px-4 py-4 sm:px-6 lg:px-8">
        <div className="flex items-center gap-4">
          <button className="btn-ghost h-10 gap-2 px-3" onClick={onMenu} type="button">
            <HiBars3 className="text-lg" />
            <span className="hidden lg:inline">{sidebarOpen ? "Ocultar menu" : "Mostrar menu"}</span>
          </button>

          <div className="min-w-0">
            <p className="text-xs font-semibold uppercase tracking-[0.28em] text-muted">{current.eyebrow}</p>
            <h3 className="mt-1 text-2xl font-semibold tracking-[-0.04em] text-ink">{current.title}</h3>
            <p className="mt-1 hidden text-[13px] text-muted sm:block">{current.description}</p>
          </div>
        </div>

        <div className="flex items-center gap-3">
          <div className="hidden rounded-2xl border border-line bg-white px-4 py-2.5 md:block">
            <p className="text-xs font-semibold uppercase tracking-[0.22em] text-muted">Sesion iniciada como</p>
            <p className="text-[13px] font-semibold text-ink">
              {user?.name} <span className="text-muted">/{translateRole(user?.role)}</span>
            </p>
          </div>

          <button className="btn-primary gap-2 px-4" onClick={onLogout} type="button">
            <HiArrowRightOnRectangle className="text-lg" />
            <span className="hidden sm:inline">Salir</span>
          </button>
        </div>
      </div>
    </header>
  );
}
