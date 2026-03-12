import { createContext, startTransition, useContext, useEffect, useMemo, useState } from "react";
import { apiRequest } from "../lib/api";

const AuthContext = createContext(null);

export function AuthProvider({ children }) {
  const [user, setUser] = useState(null);
  const [booting, setBooting] = useState(true);

  useEffect(() => {
    let active = true;

    apiRequest("/api/v1/auth/me")
      .then((data) => {
        if (!active) {
          return;
        }

        startTransition(() => {
          setUser(data.user);
        });
      })
      .catch(() => {
        if (active) {
          setUser(null);
        }
      })
      .finally(() => {
        if (active) {
          setBooting(false);
        }
      });

    return () => {
      active = false;
    };
  }, []);

  const value = useMemo(
    () => ({
      user,
      booting,
      async login(credentials) {
        const data = await apiRequest("/api/v1/auth/login", {
          method: "POST",
          body: credentials,
        });

        startTransition(() => {
          setUser(data.user);
        });

        return data.user;
      },
      async loginWithDemo(role) {
        const data = await apiRequest("/api/v1/auth/demo_login", {
          method: "POST",
          body: { role },
        });

        startTransition(() => {
          setUser(data.user);
        });

        return data.user;
      },
      async refresh() {
        const data = await apiRequest("/api/v1/auth/me");
        startTransition(() => {
          setUser(data.user);
        });

        return data.user;
      },
      async logout() {
        await apiRequest("/api/v1/auth/logout", { method: "DELETE" });
        startTransition(() => {
          setUser(null);
        });
      },
    }),
    [booting, user]
  );

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

export function useAuth() {
  const context = useContext(AuthContext);

  if (!context) {
    throw new Error("useAuth debe usarse dentro de un AuthProvider");
  }

  return context;
}
