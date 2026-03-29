import React, { createContext, useContext, useState, useCallback, ReactNode } from "react";

export type UserRole = "retailer" | "admin" | "warehouse_manager";

export interface User {
  id: string;
  email?: string | null;
  phone?: string | null;
  contact: string;
  role: UserRole;
  name: string;
  token?: string | null;
}

interface AuthContextType {
  user: User | null;
  login: (identifier: string, password: string) => Promise<{ success: boolean; error?: string }>;
  logout: () => void;
  isAuthenticated: boolean;
}

const AuthContext = createContext<AuthContextType | undefined>(undefined);
const API_BASE_URL = import.meta.env.VITE_API_URL || "http://localhost:5000";

export function AuthProvider({ children }: { children: ReactNode }) {
  const [user, setUser] = useState<User | null>(() => {
    const stored = localStorage.getItem("wms_user");
    return stored ? JSON.parse(stored) : null;
  });

  const login = useCallback(async (identifier: string, password: string) => {
    try {
      const response = await fetch(`${API_BASE_URL}/auth/login`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          identifier,
          password,
          email: identifier.includes("@") ? identifier : undefined,
          phone: identifier.includes("@") ? undefined : identifier,
        }),
      });

      const data = await response.json().catch(() => ({}));

      if (!response.ok) {
        return { success: false, error: data?.message || "Login failed" };
      }

      const loggedUser = data?.user;
      if (!loggedUser) {
        return { success: false, error: "Login response is missing user data" };
      }

      const userData: User = {
        id: String(loggedUser.id),
        email: loggedUser.email ?? null,
        phone: loggedUser.phone ?? null,
        contact: loggedUser.phone || loggedUser.email || identifier,
        role: loggedUser.role,
        name: loggedUser.name,
        token: data?.sessionToken ?? null,
      };

      setUser(userData);
      localStorage.setItem("wms_user", JSON.stringify(userData));
      return { success: true };
    } catch (error) {
      return {
        success: false,
        error: error instanceof Error ? error.message : "Could not reach the backend",
      };
    }
  }, []);

  const logout = useCallback(() => {
    setUser(null);
    localStorage.removeItem("wms_user");
  }, []);

  return (
    <AuthContext.Provider value={{ user, login, logout, isAuthenticated: !!user }}>
      {children}
    </AuthContext.Provider>
  );
}

export function useAuth() {
  const ctx = useContext(AuthContext);
  if (!ctx) throw new Error("useAuth must be used within AuthProvider");
  return ctx;
}
