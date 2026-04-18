import { useState } from "react";
import BrandMark from "../components/BrandMark";
import { useAuth } from "../context/AuthContext";

const DEMO_ACCOUNTS = [
  {
    role: "admin",
    label: "Administrador",
    description: "Acceso completo a productos, compras, ventas y reportes.",
    email: "admin@demo.stockery.app",
  },
  {
    role: "manager",
    label: "Gerente",
    description: "Control comercial e inventario con acceso a reportes operativos.",
    email: "manager@demo.stockery.app",
  },
  {
    role: "clerk",
    label: "Operador",
    description: "Ejecucion de ventas y visibilidad de inventario con permisos acotados.",
    email: "clerk@demo.stockery.app",
  },
];

export default function LoginPage() {
  const { login, loginWithDemo } = useAuth();
  const [form, setForm] = useState({
    email: "admin@demo.stockery.app",
    password: "Stockify123!",
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
            <p className="chip">SaaS listo para inversion</p>
            <h1 className="mt-8 max-w-lg font-semibold tracking-[-0.08em] text-ink">
              Control de inventario estructurado para operaciones retail modernas.
            </h1>
            <p className="mt-6 max-w-xl text-lg leading-8 text-muted">
              Stockery le da a tu equipo una capa premium de control sobre productos, compras,
              inventario en tiempo real y desempeno comercial, con acceso por roles y entrada demo instantanea.
            </p>
          </div>

          <div className="mt-12 grid gap-4 sm:grid-cols-3">
            {[
              ["Inteligencia de stock bajo", "Detecta riesgo de inventario antes de que afecte las ventas."],
              ["De compra a gondola", "Recibe mercaderia y actualiza inventario en un solo flujo."],
              ["Reportes listos para CSV", "Exporta snapshots operativos para finanzas y liderazgo."],
            ].map(([title, copy]) => (
              <div key={title} className="surface-card p-5">
                <p className="text-sm font-semibold text-ink">{title}</p>
                <p className="mt-3 text-sm leading-6 text-muted">{copy}</p>
              </div>
            ))}
          </div>
        </div>
      </div>

      <div className="flex w-full items-center justify-center border-t border-white/70 bg-white/70 px-6 py-10 backdrop-blur lg:w-[540px] lg:border-l lg:border-t-0">
        <div className="surface-card w-full max-w-md p-6 sm:p-8">
          <p className="text-xs font-semibold uppercase tracking-[0.24em] text-muted">Acceso seguro</p>
          <h2 className="mt-4 font-semibold tracking-[-0.05em]">Ingresa a Stockery</h2>
          <p className="mt-4 text-sm leading-6 text-muted">
            Usa tu correo y contrasena o entra directo con un perfil demo preparado.
          </p>

          <form className="mt-8 space-y-4" onSubmit={handleSubmit}>
            <div>
              <label className="mb-2 block text-sm font-medium text-ink" htmlFor="email">
                Email
              </label>
              <input
                id="email"
                className="input-field"
                onChange={(event) => setForm((current) => ({ ...current, email: event.target.value }))}
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
                onChange={(event) => setForm((current) => ({ ...current, password: event.target.value }))}
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
              {loading ? "Ingresando..." : "Continuar"}
            </button>
          </form>

          <div className="mt-8">
            <button
              aria-controls="demo-accounts-panel"
              aria-expanded={demoAccountsOpen}
              className="flex w-full items-center justify-between rounded-2xl border border-line bg-cloud/70 px-4 py-4 text-left transition hover:border-ink/15 hover:bg-white"
              onClick={() => setDemoAccountsOpen((current) => !current)}
              type="button"
            >
              <div>
                <p className="text-xs font-semibold uppercase tracking-[0.22em] text-muted">Ingreso demo</p>
                <p className="mt-2 text-sm font-semibold text-ink">Ver cuentas demo</p>
              </div>
              <span className="text-sm font-medium text-muted">
                {demoAccountsOpen ? "Ocultar" : "Desplegar"}
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
