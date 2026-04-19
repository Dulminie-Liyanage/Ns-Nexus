import type { ReactNode } from "react";
export type UserRole = "admin" | "retailer" | "warehouse_manager" | "driver" | "3pl_manager";
import { useNavigate, useLocation, Link } from "react-router-dom";
import { Button } from "../components/ui/button";
import { useAuth } from "../lib/auth-context";
import { Box, Warehouse } from "lucide-react"; 
import { LogOut, ShoppingCart, ClipboardList, Package, LayoutDashboard, Users, ChevronRight, Truck } from "lucide-react";
import { cn } from "../lib/utils";
import { Dialog, DialogTrigger, DialogContent, DialogHeader, DialogTitle, DialogFooter, DialogClose, } from "../components/ui/dialog";

interface NavItem {
  label: string;
  href: string;
  icon: React.ElementType;
}

const retailerNav: NavItem[] = [
  { label: "Dashboard", href: "/dashboard", icon: LayoutDashboard },
  { label: "Place Order", href: "/dashboard/order", icon: ShoppingCart },
  { label: "Order History", href: "/dashboard/history", icon: ClipboardList },
];

const warehouseNav: NavItem[] = [
  { label: "Dashboard", href: "/warehouse", icon: LayoutDashboard },
  { label: "Orders", href: "/warehouse/orders", icon: ClipboardList },
  { label: "Inventory", href: "/warehouse/inventory", icon: Package },
];

const driverNav: NavItem[] = [
  { label: "Dashboard", href: "/driver", icon: LayoutDashboard },
  { label: "My Deliveries", href: "/driver", icon: Truck },
];

const logisticsNav: NavItem[] = [
  { label: "Dashboard", href: "/logistics", icon: LayoutDashboard },
  { label: "Assign Drivers", href: "/logistics/assign-drivers", icon: Truck },
  { label: "Shipments", href: "/logistics/shipments", icon: Box },
];

export default function DashboardLayout({ children, role }: { children: ReactNode; role: UserRole }) {
  const { user, logout } = useAuth();
  const navigate = useNavigate();
  const location = useLocation();
    const nav = role === "warehouse_manager" ? warehouseNav : role === "retailer" ? retailerNav  : role === "driver" ? driverNav : role === "3pl_manager" ? logisticsNav : [];


  const handleLogout = () => {
    logout();
    navigate("/login");
  };

  return (
    <div className="min-h-screen flex bg-background">
      {/* Sidebar */}
      <aside className="w-64 bg-sidebar text-sidebar-foreground flex flex-col border-r border-sidebar-border shrink-0">
        <div className="p-5 flex items-center gap-3 border-b border-sidebar-border">
          <div>
            <h2 className="font-bold text-sm">NS Nexus</h2>
            <p className="text-xs text-sidebar-foreground/60 capitalize">{role} Dashboard</p>
          </div>
        </div>

        <nav className="flex-1 p-3 space-y-1">
          {nav.map((item: NavItem) => {
            const active = location.pathname === item.href;
            return (
              <Link
                key={item.href}
                to={item.href}
                className={cn(
                  "flex items-center gap-3 px-3 py-2.5 rounded-lg text-sm font-medium transition-colors",
                  active
                    ? "bg-sidebar-accent text-sidebar-accent-foreground"
                    : "text-sidebar-foreground/70 hover:bg-sidebar-accent/50 hover:text-sidebar-accent-foreground"
                )}
              >
                <item.icon className="h-4 w-4" />
                {item.label}
                {active && <ChevronRight className="h-3 w-3 ml-auto" />}
              </Link>
            );
          })}
        </nav>

        <div className="p-3 border-t border-sidebar-border">
          <div className="flex items-center gap-3 px-3 py-2 mb-2">
            <div className="h-8 w-8 rounded-full bg-sidebar-accent flex items-center justify-center">
              <Users className="h-4 w-4 text-sidebar-accent-foreground" />
            </div>
            <div className="flex-1 min-w-0">
              <p className="text-xs font-medium truncate">{user?.name}</p>
              <p className="text-xs text-sidebar-foreground/50 truncate">{user?.email}</p>
            </div>
          </div>
          <Dialog>
            <DialogTrigger asChild>
              <Button
                variant="ghost"
                className="w-full justify-start text-sidebar-foreground/70 hover:text-sidebar-foreground hover:bg-sidebar-accent/50"
                //onClick={handleLogout}
              >
                <LogOut className="h-4 w-4 mr-2" />
                Log out
              </Button>
            </DialogTrigger>

            <DialogContent>
              <DialogHeader>
                <DialogTitle>Confrim Logout</DialogTitle>
              </DialogHeader>

              <p className="text-sm text-muted-foreground">
                Are you sure you want to log out?
              </p>

              <DialogFooter>
                <DialogClose asChild>
                  <Button variant="outline">Cancel</Button>
                </DialogClose>

                <Button 
                  variant="destructive" 
                  onClick={handleLogout} // <- add this
                >
                  Logout
                </Button>
              </DialogFooter>
            </DialogContent>
          </Dialog>
        </div>
      </aside>

      {/* Main content */}
      <main className="flex-1 overflow-auto">
        <div className="p-6 max-w-7xl mx-auto">{children}</div>
      </main>
    </div>
  );
}
