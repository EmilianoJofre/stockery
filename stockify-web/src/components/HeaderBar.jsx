import { useLocation } from "react-router-dom";
import { HiArrowRightOnRectangle, HiBars3 } from "react-icons/hi2";

const FALLBACK_META = {
  eyebrow: "Stockify",
  title: "Inventory Platform",
  description: "Monitor inventory, sales, and suppliers in one workspace.",
};

export default function HeaderBar({ pageMeta, onMenu, onLogout, user }) {
  const location = useLocation();
  const key = location.pathname.split("/")[1] || "dashboard";
  const current = pageMeta[key] || FALLBACK_META;

  return (
    <header className="sticky top-0 z-20 border-b border-white/70 bg-white/80 backdrop-blur">
      <div className="mx-auto flex max-w-[1440px] items-center justify-between gap-4 px-4 py-5 sm:px-6 lg:px-8">
        <div className="flex items-center gap-4">
          <button className="btn-ghost h-11 px-3 lg:hidden" onClick={onMenu} type="button">
            <HiBars3 className="text-lg" />
          </button>

          <div>
            <p className="text-xs font-semibold uppercase tracking-[0.28em] text-muted">{current.eyebrow}</p>
            <h3 className="mt-1 text-[28px] font-semibold tracking-[-0.04em] text-ink">{current.title}</h3>
            <p className="mt-1 hidden text-sm text-muted sm:block">{current.description}</p>
          </div>
        </div>

        <div className="flex items-center gap-3">
          <div className="hidden rounded-2xl border border-line bg-white px-4 py-3 md:block">
            <p className="text-xs font-semibold uppercase tracking-[0.22em] text-muted">Signed in as</p>
            <p className="text-sm font-semibold text-ink">
              {user?.name} <span className="text-muted">/{user?.role}</span>
            </p>
          </div>

          <button className="btn-primary gap-2 px-4" onClick={onLogout} type="button">
            <HiArrowRightOnRectangle className="text-lg" />
            <span className="hidden sm:inline">Logout</span>
          </button>
        </div>
      </div>
    </header>
  );
}
