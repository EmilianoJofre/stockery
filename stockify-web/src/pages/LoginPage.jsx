import { useState } from "react";
import BrandMark from "../components/BrandMark";
import { useAuth } from "../context/AuthContext";

const DEMO_ACCOUNTS = [
  {
    role: "admin",
    label: "Admin",
    description: "Full platform access for product, purchasing, sales, and reporting workflows.",
    email: "admin@demo.stockify.app",
  },
  {
    role: "manager",
    label: "Manager",
    description: "Inventory and commercial oversight with access to operations reporting.",
    email: "manager@demo.stockify.app",
  },
  {
    role: "clerk",
    label: "Clerk",
    description: "Sales execution and inventory visibility with a narrower permissions set.",
    email: "clerk@demo.stockify.app",
  },
];

export default function LoginPage() {
  const { login, loginWithDemo } = useAuth();
  const [form, setForm] = useState({
    email: "admin@demo.stockify.app",
    password: "Stockify123!",
  });
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
            <p className="chip">Investor-grade SaaS</p>
            <h1 className="mt-8 max-w-lg font-semibold tracking-[-0.08em] text-ink">
              Structured inventory control built for modern retail operators.
            </h1>
            <p className="mt-6 max-w-xl text-lg leading-8 text-muted">
              Stockify gives teams a premium control layer across products, purchasing, live inventory,
              and sales performance with role-based access and instant demo entry.
            </p>
          </div>

          <div className="mt-12 grid gap-4 sm:grid-cols-3">
            {[
              ["Low-stock intelligence", "Track stock risk before it becomes a sales issue."],
              ["Purchase to shelf", "Receive goods and update inventory in one motion."],
              ["CSV-ready reporting", "Export operational snapshots for finance and leadership."],
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
          <p className="text-xs font-semibold uppercase tracking-[0.24em] text-muted">Secure access</p>
          <h2 className="mt-4 font-semibold tracking-[-0.05em]">Log in to Stockify</h2>
          <p className="mt-4 text-sm leading-6 text-muted">
            Use email and password or enter directly with a prepared demo role.
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
                Password
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
              {loading ? "Signing in..." : "Continue"}
            </button>
          </form>

          <div className="mt-8">
            <div className="mb-4 flex items-center justify-between">
              <p className="text-xs font-semibold uppercase tracking-[0.22em] text-muted">Demo login</p>
              <p className="text-xs text-muted">Password: Stockify123!</p>
            </div>

            <div className="space-y-3">
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
          </div>
        </div>
      </div>
    </div>
  );
}
