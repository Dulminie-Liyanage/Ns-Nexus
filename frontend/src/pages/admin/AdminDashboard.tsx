import DashboardLayout from "@/components/DashboardLayout";
import { store } from "@/lib/store";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { ClipboardList, Package, CheckCircle, XCircle, Clock, ShoppingCart } from "lucide-react";

export default function AdminDashboard() {
  const orders = store.getOrders();
  const products = store.getProducts();
  const pending = orders.filter((o) => o.status === "Pending").length;
  const approved = orders.filter((o) => o.status === "Approved").length;
  const rejected = orders.filter((o) => o.status === "Rejected").length;

  const stats = [
    { label: "Total Orders", value: orders.length, icon: ClipboardList, color: "text-primary" },
    { label: "Pending Review", value: pending, icon: Clock, color: "text-warning" },
    { label: "Approved", value: approved, icon: CheckCircle, color: "text-success" },
    { label: "Rejected", value: rejected, icon: XCircle, color: "text-destructive" },
    { label: "Total SKUs", value: products.length, icon: Package, color: "text-primary" },
    { label: "In Stock", value: products.filter((p) => p.available).length, icon: ShoppingCart, color: "text-success" },
  ];

  return (
    <DashboardLayout role="admin">
      <div className="space-y-6">
        <div>
          <h1 className="text-2xl font-bold">Admin Dashboard</h1>
          <p className="text-muted-foreground text-sm mt-1">Warehouse operations overview</p>
        </div>

        <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
          {stats.map((s) => (
            <Card key={s.label}>
              <CardHeader className="flex flex-row items-center justify-between pb-2">
                <CardTitle className="text-sm font-medium text-muted-foreground">{s.label}</CardTitle>
                <s.icon className={`h-5 w-5 ${s.color}`} />
              </CardHeader>
              <CardContent>
                <div className="text-3xl font-bold">{s.value}</div>
              </CardContent>
            </Card>
          ))}
        </div>

        {orders.filter(o => o.status === "Pending").length > 0 && (
          <Card>
            <CardHeader>
              <CardTitle className="text-lg">Pending Orders</CardTitle>
            </CardHeader>
            <CardContent>
              <div className="overflow-x-auto">
                <table className="w-full text-sm">
                  <thead>
                    <tr className="border-b border-border">
                      <th className="text-left py-3 px-2 font-medium text-muted-foreground">Order ID</th>
                      <th className="text-left py-3 px-2 font-medium text-muted-foreground">Retailer</th>
                      <th className="text-left py-3 px-2 font-medium text-muted-foreground">Items</th>
                      <th className="text-right py-3 px-2 font-medium text-muted-foreground">Total</th>
                      <th className="text-left py-3 px-2 font-medium text-muted-foreground">Delivery</th>
                    </tr>
                  </thead>
                  <tbody>
                    {orders.filter(o => o.status === "Pending").map((o) => (
                      <tr key={o.id} className="border-b border-border/50">
                        <td className="py-3 px-2 font-mono text-xs">{o.id}</td>
                        <td className="py-3 px-2">{o.retailerName}</td>
                        <td className="py-3 px-2">{o.items.length}</td>
                        <td className="py-3 px-2 text-right font-medium">${o.totalPrice.toFixed(2)}</td>
                        <td className="py-3 px-2">{new Date(o.deliveryDate).toLocaleDateString()}</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            </CardContent>
          </Card>
        )}
      </div>
    </DashboardLayout>
  );
}
