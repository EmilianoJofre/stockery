import clsx from "clsx";
import { NavLink } from "react-router-dom";
import {
  HiBars3BottomLeft,
  HiChartBarSquare,
  HiCircleStack,
  HiCube,
  HiHomeModern,
  HiShoppingCart,
  HiTruck,
  HiUserGroup,
  HiXMark,
} from "react-icons/hi2";
import BrandMark from "./BrandMark";
import { translateRole } from "../lib/translations";
import { can } from "../lib/permissions";

const CORE_MODULES = [
  { to: "/dashboard", label: "Panel",      icon: HiHomeModern     },
  { to: "/products",  label: "Productos",  icon: HiCube           },
  { to: "/inventory", label: "Inventario", icon: HiCircleStack    },
  { to: "/purchases", label: "Compras",    icon: HiTruck          },
  { to: "/sales",     label: "Ventas",     icon: HiShoppingCart   },
  { to: "/reports",   label: "Reportes",   icon: HiChartBarSquare },
];

const ADMIN_MODULES = [
  { to: "/users", label: "Usuarios", icon: HiUserGroup, permission: "users.view" },
];

function SidebarLink({ to, label, icon: Icon, onNavigate }) {
  return (
    <NavLink
      className={({ isActive }) => clsx("sidebar-link", isActive && "sidebar-link-active")}
      onClick={onNavigate}
      to={to}
    >
      <span className="flex h-9 w-9 items-center justify-center rounded-xl bg-white/70">
        <Icon className="text-lg" />
      </span>
      <span>{label}</span>
    </NavLink>
  );
}

function SidebarContent({ onClose, onNavigate, user }) {
  const adminModules = ADMIN_MODULES.filter((m) => can(user, m.permission));

  return (
    <div className="flex h-full flex-col rounded-none bg-white/95 px-4 py-5 shadow-soft backdrop-blur lg:rounded-r-[24px]">
      <div className="mb-6 flex items-center justify-between gap-3">
        <BrandMark />
        <button className="btn-ghost h-10 px-3" onClick={onClose} type="button">
          <HiXMark className="text-base" />
        </button>
      </div>

      <div className="mb-3 flex items-center justify-between">
        <p className="text-xs font-semibold uppercase tracking-[0.26em] text-muted">Modulos</p>
        <HiBars3BottomLeft className="text-muted" />
      </div>

      <nav className="space-y-2">
        {CORE_MODULES.map((m) => (
          <SidebarLink key={m.to} to={m.to} label={m.label} icon={m.icon} onNavigate={onNavigate} />
        ))}
      </nav>

      {adminModules.length > 0 && (
        <>
          <div className="mb-3 mt-6 flex items-center justify-between">
            <p className="text-xs font-semibold uppercase tracking-[0.26em] text-muted">Administracion</p>
          </div>
          <nav className="space-y-2">
            {adminModules.map((m) => (
              <SidebarLink key={m.to} to={m.to} label={m.label} icon={m.icon} onNavigate={onNavigate} />
            ))}
          </nav>
        </>
      )}

      <div className="mt-auto space-y-4">
        <div className="surface-card p-4">
          <p className="text-xs font-semibold uppercase tracking-[0.26em] text-muted">Sesion</p>
          <p className="mt-3 text-base font-semibold text-ink">{user?.name}</p>
          <p className="text-[13px] text-muted">{user?.email}</p>
          <p className="mt-1 text-xs text-muted">{user?.company?.name}</p>
          <div className="mt-3 flex items-center gap-2">
            <span className="chip">{translateRole(user?.role)}</span>
          </div>
        </div>
      </div>
    </div>
  );
}

export default function Sidebar({ desktopOpen, mobileOpen, onDesktopClose, onMobileClose, user }) {
  return (
    <>
      <aside
        className={clsx(
          "fixed inset-y-0 left-0 z-30 hidden w-[16rem] transition-transform duration-300 lg:block",
          desktopOpen ? "translate-x-0" : "-translate-x-full pointer-events-none"
        )}
      >
        <SidebarContent onClose={onDesktopClose} user={user} />
      </aside>

      <div
        className={clsx(
          "fixed inset-0 z-40 bg-ink/30 transition lg:hidden",
          mobileOpen ? "pointer-events-auto opacity-100" : "pointer-events-none opacity-0"
        )}
        onClick={onMobileClose}
      />

      <aside
        className={clsx(
          "fixed inset-y-0 left-0 z-50 w-[16rem] transition-transform duration-300 lg:hidden",
          mobileOpen ? "translate-x-0" : "-translate-x-full"
        )}
      >
        <SidebarContent onClose={onMobileClose} onNavigate={onMobileClose} user={user} />
      </aside>
    </>
  );
}
