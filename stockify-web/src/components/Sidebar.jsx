import clsx from "clsx";
import { NavLink } from "react-router-dom";
import {
  HiBars3BottomLeft,
  HiChartBarSquare,
  HiDocumentText,
  HiCircleStack,
  HiCube,
  HiHomeModern,
  HiShoppingCart,
  HiIdentification,
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
  { to: "/customers", label: "Clientes",   icon: HiIdentification },
  { to: "/reports",   label: "Reportes",   icon: HiChartBarSquare },
];

const ADMIN_MODULES = [
  { to: "/users", label: "Usuarios", icon: HiUserGroup, permission: "users.view" },
  { to: "/billing", label: "Facturacion", icon: HiDocumentText, permission: "billing.manage" },
];

function getUserInitials(user) {
  const tokens = user?.name?.trim().split(/\s+/).filter(Boolean) || [];

  if (tokens.length === 0) {
    return "ST";
  }

  return tokens
    .slice(0, 2)
    .map((token) => token[0]?.toUpperCase())
    .join("");
}

function SidebarLink({ to, label, icon: Icon, onNavigate, collapsed = false }) {
  return (
    <NavLink
      aria-label={label}
      className={({ isActive }) =>
        clsx(
          "sidebar-link",
          collapsed && "justify-center gap-0 px-2",
          isActive && "sidebar-link-active"
        )
      }
      onClick={onNavigate}
      title={collapsed ? label : undefined}
      to={to}
    >
      <span className={clsx("flex h-9 w-9 items-center justify-center rounded-xl bg-white/70", collapsed && "h-10 w-10")}>
        <Icon className="text-lg" />
      </span>
      {!collapsed ? <span>{label}</span> : null}
    </NavLink>
  );
}

function SidebarContent({ desktopOpen = true, isDesktop = false, onClose, onDesktopToggle, onNavigate, user }) {
  const adminModules = ADMIN_MODULES.filter((m) => can(user, m.permission));
  const collapsed = isDesktop && !desktopOpen;
  const userSummary = [user?.name, user?.email].filter(Boolean).join(" | ");

  return (
    <div
      className={clsx(
        "relative flex h-full flex-col rounded-none bg-white/95 py-5 shadow-soft backdrop-blur lg:rounded-r-[24px]",
        collapsed ? "px-3" : "px-4"
      )}
    >
      <div className={clsx("mb-6 flex items-center", collapsed ? "justify-center" : "justify-between gap-3")}>
        <BrandMark compact={collapsed} />

        {!isDesktop ? (
          <button aria-label="Cerrar menu" className="btn-ghost h-10 w-10 px-0" onClick={onClose} type="button">
            <HiXMark className="text-base" />
          </button>
        ) : null}
      </div>

      <div className={clsx("mb-3 flex items-center", collapsed ? "justify-center" : "justify-between")}>
        {!collapsed ? <p className="text-xs font-semibold uppercase tracking-[0.26em] text-muted">Modulos</p> : null}
        {isDesktop ? (
          <button
            aria-label={collapsed ? "Expandir menu" : "Contraer menu"}
            className="inline-flex h-9 w-9 items-center justify-center rounded-xl text-muted transition hover:bg-cloud hover:text-ink"
            onClick={onDesktopToggle}
            title={collapsed ? "Expandir menu" : "Contraer menu"}
            type="button"
          >
            <HiBars3BottomLeft className="text-base" />
          </button>
        ) : (
          <HiBars3BottomLeft className="text-muted" />
        )}
      </div>

      <nav className="space-y-2">
        {CORE_MODULES.map((m) => (
          <SidebarLink collapsed={collapsed} key={m.to} to={m.to} label={m.label} icon={m.icon} onNavigate={onNavigate} />
        ))}
      </nav>

      {adminModules.length > 0 && (
        <>
          <div className={clsx("mb-3 mt-6 flex items-center", collapsed ? "justify-center" : "justify-between")}>
            {!collapsed ? <p className="text-xs font-semibold uppercase tracking-[0.26em] text-muted">Administracion</p> : null}
          </div>
          <nav className="space-y-2">
            {adminModules.map((m) => (
              <SidebarLink collapsed={collapsed} key={m.to} to={m.to} label={m.label} icon={m.icon} onNavigate={onNavigate} />
            ))}
          </nav>
        </>
      )}

      <div className="mt-auto space-y-4">
        {collapsed ? (
          <div className="surface-card flex items-center justify-center p-3" title={userSummary}>
            <div className="flex h-10 w-10 items-center justify-center rounded-2xl bg-brand/10 text-sm font-semibold text-ink">
              {getUserInitials(user)}
            </div>
          </div>
        ) : (
          <div className="surface-card p-4">
            <p className="text-xs font-semibold uppercase tracking-[0.26em] text-muted">Sesion</p>
            <p className="mt-3 text-base font-semibold text-ink">{user?.name}</p>
            <p className="text-[13px] text-muted">{user?.email}</p>
            <p className="mt-1 text-xs text-muted">{user?.company?.name}</p>
            <div className="mt-3 flex items-center gap-2">
              <span className="chip">{translateRole(user?.role)}</span>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}

export default function Sidebar({ desktopOpen, mobileOpen, onDesktopToggle, onMobileClose, user }) {
  return (
    <>
      <aside
        className={clsx(
          "fixed inset-y-0 left-0 z-30 hidden transition-[width] duration-300 lg:block",
          desktopOpen ? "w-[16rem]" : "w-[5.5rem]"
        )}
      >
        <SidebarContent desktopOpen={desktopOpen} isDesktop onDesktopToggle={onDesktopToggle} user={user} />
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
