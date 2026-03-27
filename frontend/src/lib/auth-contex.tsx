import React, { createContext, useContext, useState, useCallback, ReactNode } from "react";

export type UserRole = "retailer" | "admin";

export interface User {
  id: string;
  email: string;
  role: UserRole;
  name: string;
}

interface AuthContextType {
  user: User | null;
  login: (email: string, password: string) => Promise<{ success: boolean; error?: string }>;
  logout: () => void;
  isAuthenticated: boolean;
}

const AuthContext = createContext<AuthContextType | undefined>(undefined);

// Mock users for demo (will be replaced with Lovable Cloud)
const MOCK_USERS = [
  { id: "1", email: "retailer@demo.com", password: "password123", role: "retailer" as UserRole, name: "Demo Retailer", failedAttempts: 0, locked: false },
  { id: "2", email: "admin@demo.com", password: "password123", role: "admin" as UserRole, name: "Warehouse Manager", failedAttempts: 0, locked: false },
];

const loginAttempts: Record<string, { count: number; locked: boolean }> = {};

export function AuthProvider({ children }: { children: ReactNode }) {
  const [user, setUser] = useState<User | null>(() => {
    const stored = localStorage.getItem("wms_user");
    return stored ? JSON.parse(stored) : null;
  });

  const login = useCallback(async (email: string, password: string) => {
    const attempts = loginAttempts[email] || { count: 0, locked: false };

    if (attempts.locked) {
      return { success: false, error: "Account is locked after 3 failed attempts. Contact admin." };
    }

    const found = MOCK_USERS.find((u) => u.email === email && u.password === password);

    if (!found) {
      attempts.count += 1;
      if (attempts.count >= 3) {
        attempts.locked = true;
        loginAttempts[email] = attempts;
        return { success: false, error: "Account locked after 3 failed attempts. Contact admin." };
      }
      loginAttempts[email] = attempts;
      return { success: false, error: `Invalid credentials. ${3 - attempts.count} attempt(s) remaining.` };
    }

    // Reset attempts on success
    loginAttempts[email] = { count: 0, locked: false };
    const userData: User = { id: found.id, email: found.email, role: found.role, name: found.name };
    setUser(userData);
    localStorage.setItem("wms_user", JSON.stringify(userData));
    return { success: true };
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
