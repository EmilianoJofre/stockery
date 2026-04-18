import { HiCircleStack, HiTruck, HiUserGroup } from "react-icons/hi2";
import { useState } from "react";
import BrandMark from "../components/BrandMark";
import { useAuth } from "../context/AuthContext";

const LOGIN_HIGHLIGHTS = [
  {
    icon: HiCircleStack,
    copy: "Stock disponible por tienda y alertas de reposicion.",
  },
  {
    icon: HiTruck,
    copy: "Registro de compras y ventas con actualizacion inmediata.",
  },
  {
    icon: HiUserGroup,
    copy: "Acceso por rol para administracion, supervision y operacion.",
  },
];

const DEMO_ACCOUNTS = [
  {
    role: "admin",
    label: "Administrador",
    description: "Administra catalogo, inventario, compras, ventas, usuarios y reportes.",
    email: "admin@demo.stockery.app",
  },
  {
    role: "manager",
    label: "Gerente",
    description: "Supervisa stock, ventas, compras y reportes para seguimiento operativo.",
    email: "manager@demo.stockery.app",
  },
  {
    role: "clerk",
    label: "Operador",
    description: "Registra ventas y consulta existencias con permisos acotados para la operacion diaria.",
    email: "clerk@demo.stockery.app",
  },
];

export default function LoginPage() {
  const { login, loginWithDemo } = useAuth();
  const [form, setForm] = useState({
    email: "",
    password: "",
  });
  const [demoAccountsOpen, setDemoAccountsOpen] = useState(false);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");

  async function handleSubmit(event) {
    event.preventDefault();
    setLoading(true);
    setError("");

    try {
      await login(form);
    } catch (submitError) {
      setError(submitError.message);
    } finally {
      setLoading(false);
    }
  }

  async function handleDemo(account) {
    setForm({
      email: account.email,
      password: "Stockify123!",
    });
    setLoading(true);
    setError("");

    try {
      await loginWithDemo(account.role);
    } catch (demoError) {
      setError(demoError.message);
    } finally {
      setLoading(false);
    }
  }

  return (
    <div className="relative flex min-h-screen flex-col lg:flex-row">
      <div className="relative flex flex-1 overflow-hidden px-6 py-10 sm:px-10 lg:px-14">
        <div className="absolute inset-x-8 top-8 h-72 rounded-full bg-brand/10 blur-3xl" />
        <div className="absolute bottom-0 right-0 h-72 w-72 rounded-full bg-accent/10 blur-3xl" />

        <div className="relative mx-auto flex w-full max-w-2xl flex-col">
          <BrandMark />

          <div className="mt-16 max-w-xl">
            <p className="chip">Operacion retail con trazabilidad</p>
            <h1 className="mt-8 max-w-lg font-semibold tracking-[-0.08em] text-ink">
              Administra catalogo, inventario, compras y ventas desde un solo lugar.
            </h1>
            <p className="mt-6 max-w-xl text-base leading-7 text-muted">
              Stockery centraliza la operacion diaria de tiendas y equipos de abastecimiento:
              stock por sucursal, recepciones, ventas, ajustes y reportes listos para seguimiento.
            </p>
          </div>

          <div className="mt-10 grid gap-4 sm:grid-cols-3">
            {LOGIN_HIGHLIGHTS.map((item) => (
              <div key={item.copy} className="surface-card p-5">
                <div className="flex h-11 w-11 items-center justify-center rounded-2xl bg-brand/18 text-ink">
                  <item.icon className="text-xl" />
                </div>
                <p className="mt-4 text-sm font-medium leading-6 text-ink">{item.copy}</p>
              </div>
            ))}
          </div>
        </div>
      </div>

      <div className="flex w-full items-center justify-center border-t border-white/70 bg-white/70 px-6 py-10 backdrop-blur lg:w-[540px] lg:border-l lg:border-t-0">
        <div className="surface-card w-full max-w-md p-6 sm:p-8">
          <p className="text-xs font-semibold uppercase tracking-[0.24em] text-muted">Acceso a la plataforma</p>
          <h2 className="mt-4 font-semibold tracking-[-0.05em]">Inicia sesion en Stockery</h2>
          <p className="mt-4 text-sm leading-6 text-muted">
            Ingresa con tu correo para trabajar sobre productos, inventario, compras, ventas y reportes desde un mismo panel.
          </p>

          <form className="mt-8 space-y-4" onSubmit={handleSubmit}>
            <div>
              <label className="mb-2 block text-sm font-medium text-ink" htmlFor="email">
                Email
              </label>
              <input
                id="email"
                className="input-field"
                autoComplete="email"
                onChange={(event) => setForm((current) => ({ ...current, email: event.target.value }))}
                placeholder="correo@empresa.cl"
                type="email"
                value={form.email}
              />
            </div>

            <div>
              <label className="mb-2 block text-sm font-medium text-ink" htmlFor="password">
                Contrasena
              </label>
              <input
                id="password"
                className="input-field"
                autoComplete="current-password"
                onChange={(event) => setForm((current) => ({ ...current, password: event.target.value }))}
                placeholder="Tu contrasena"
                type="password"
                value={form.password}
              />
            </div>

            {error ? (
              <div className="rounded-2xl border border-accent/20 bg-accent/5 px-4 py-3 text-sm text-accent">
                {error}
              </div>
            ) : null}

            <button className="btn-primary w-full" disabled={loading} type="submit">
              {loading ? "Iniciando sesion..." : "Iniciar sesion"}
            </button>
          </form>

          <div className="mt-6 rounded-2xl border border-line bg-cloud/60 px-4 py-4">
            <p className="text-xs font-semibold uppercase tracking-[0.22em] text-muted">Acceso demo</p>
            <p className="mt-2 text-sm leading-6 text-muted">
              Si quieres recorrer el producto, abre las cuentas demo por rol y entra con un click, sin completar credenciales manualmente.
            </p>
          </div>

          <div className="mt-8">
            <button
              aria-controls="demo-accounts-panel"
              aria-expanded={demoAccountsOpen}
              className="flex w-full items-center justify-between rounded-2xl border border-line bg-cloud/70 px-4 py-4 text-left transition hover:border-ink/15 hover:bg-white"
              onClick={() => setDemoAccountsOpen((current) => !current)}
              type="button"
            >
              <div>
                <p className="text-xs font-semibold uppercase tracking-[0.22em] text-muted">Cuentas demo</p>
                <p className="mt-2 text-sm font-semibold text-ink">Ver accesos por rol</p>
              </div>
              <span className="text-sm font-medium text-muted">
                {demoAccountsOpen ? "Ocultar" : "Mostrar"}
              </span>
            </button>

            {demoAccountsOpen ? (
              <div id="demo-accounts-panel" className="mt-4 space-y-3">
                {DEMO_ACCOUNTS.map((account) => (
                  <button
                    key={account.role}
                    className="w-full rounded-2xl border border-line bg-white px-4 py-4 text-left transition hover:-translate-y-0.5 hover:border-ink/15 hover:shadow-panel"
                    disabled={loading}
                    onClick={() => handleDemo(account)}
                    type="button"
                  >
                    <div className="flex items-start justify-between gap-4">
                      <div>
                        <p className="text-sm font-semibold text-ink">{account.label}</p>
                        <p className="mt-1 text-sm text-muted">{account.email}</p>
                        <p className="mt-3 text-sm leading-6 text-muted">{account.description}</p>
                      </div>
                      <span className="chip">{account.label}</span>
                    </div>
                  </button>
                ))}
              </div>
            ) : null}
          </div>
        </div>
      </div>
    </div>
  );
}
