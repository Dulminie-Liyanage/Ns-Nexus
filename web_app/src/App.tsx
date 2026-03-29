import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { BrowserRouter, Route, Routes, Navigate } from "react-router-dom";
import { Toaster as Sonner } from "@/components/ui/sonner";
import { Toaster } from "@/components/ui/toaster";
import { TooltipProvider } from "@/components/ui/tooltip";
import { AuthProvider, useAuth } from "@/lib/auth-contex";
import Login from "./pages/Login";
import RetailerDashboard from "./pages/retailer/RetailerDashboard";
import PlaceOrder from "./pages/retailer/PlaceOrder";
import OrderHistory from "./pages/retailer/OrderHistory";
import AdminDashboard from "./pages/admin/AdminDashboard";
import AdminOrders from "./pages/admin/AdminOrders";
import Inventory from "./pages/admin/Inventory";
import NotFound from "./pages/NotFound";

const queryClient = new QueryClient();

function matchesRole(userRole?: string, requiredRole?: string) {
  if (!requiredRole) return true;
  if (!userRole) return false;
  if (requiredRole === "manager") {
    return userRole === "admin" || userRole === "warehouse_manager";
  }
  return userRole === requiredRole;
}

function getHomePath(userRole?: string) {
  return userRole === "retailer" ? "/dashboard" : "/admin";
}

function ProtectedRoute({ children, role }: { children: React.ReactNode; role?: string }) {
  const { user, isAuthenticated } = useAuth();
  if (!isAuthenticated) return <Navigate to="/login" replace />;
  if (!matchesRole(user?.role, role)) return <Navigate to={getHomePath(user?.role)} replace />;
  return <>{children}</>;
}

function AppRoutes() {
  const { isAuthenticated, user } = useAuth();

  return (
    <Routes>
      <Route path="/login" element={isAuthenticated ? <Navigate to={getHomePath(user?.role)} replace /> : <Login />} />
      <Route path="/" element={<Navigate to={isAuthenticated ? getHomePath(user?.role) : "/login"} replace />} />
      
      {/* Retailer routes */}
      <Route path="/dashboard" element={<ProtectedRoute role="retailer"><RetailerDashboard /></ProtectedRoute>} />
      <Route path="/dashboard/order" element={<ProtectedRoute role="retailer"><PlaceOrder /></ProtectedRoute>} />
      <Route path="/dashboard/history" element={<ProtectedRoute role="retailer"><OrderHistory /></ProtectedRoute>} />
      
      {/* Admin routes */}
      <Route path="/admin" element={<ProtectedRoute role="manager"><AdminDashboard /></ProtectedRoute>} />
      <Route path="/admin/orders" element={<ProtectedRoute role="manager"><AdminOrders /></ProtectedRoute>} />
      <Route path="/admin/inventory" element={<ProtectedRoute role="manager"><Inventory /></ProtectedRoute>} />
      
      <Route path="*" element={<NotFound />} />
    </Routes>
  );
}

const App = () => (
  <QueryClientProvider client={queryClient}>
    <TooltipProvider>
      <Toaster />
      <Sonner />
      <BrowserRouter>
        <AuthProvider>
          <AppRoutes />
        </AuthProvider>
      </BrowserRouter>
    </TooltipProvider>
  </QueryClientProvider>
);

export default App;
