import { useState, useEffect } from "react";
import DashboardLayout from "@/components/DashboardLayout";
import { useAuth } from "@/lib/auth-contex";
import { store, Order } from "@/lib/store";
import { Card, CardContent } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogTrigger } from "@/components/ui/dialog";
import { Eye, Package, CheckCircle, XCircle, Clock, Package as PackageIcon } from "lucide-react";

/* 7-step progress */
function getProgress(status: string) {
  switch (status) {
    case "Pending": return 14;
    case "Approved": return 28;
    case "Packing": return 42;
    case "Transit": return 56;
    case "3PL": return 70;
    case "Out for Delivery": return 85;
    case "Delivered": return 100;
    case "Rejected": return 100;
    default: return 0;
  }
}

function StatusIcon({ status }: { status: string }) {
  switch (status) {
    case "Pending": return <Clock className="h-4 w-4 text-warning" />;
    case "Approved": return <CheckCircle className="h-4 w-4 text-success" />;
    case "Rejected": return <XCircle className="h-4 w-4 text-destructive" />;
    default: return <PackageIcon className="h-4 w-4" />;
  }
}

function OrderDetailDialog({ order }: { order: Order }) {
  return (
    <Dialog>
      <DialogTrigger asChild>
        <Button variant="ghost" size="sm"><Eye className="h-4 w-4" /></Button>
      </DialogTrigger>
      <DialogContent className="max-w-lg">
        <DialogHeader><DialogTitle>Order {order.id}</DialogTitle></DialogHeader>
        <div className="space-y-4">
          <div className="grid grid-cols-2 gap-3 text-sm">
            <div><span className="text-muted-foreground">Status:</span> {order.status}</div>
            <div><span className="text-muted-foreground">Date:</span> {new Date(order.createdAt).toLocaleDateString()}</div>
            <div><span className="text-muted-foreground">Delivery:</span> {new Date(order.deliveryDate).toLocaleDateString()}</div>
            <div><span className="text-muted-foreground">Weight:</span> {order.totalWeight.toFixed(2)} kg</div>
          </div>
          {order.rejectionReason && (
            <div className="rounded-lg bg-destructive/10 border border-destructive/20 p-3 text-sm">
              <p className="font-medium text-destructive">Rejection Reason:</p>
              <p className="text-destructive/80 mt-1">{order.rejectionReason}</p>
            </div>
          )}
          <div>
            <h4 className="text-sm font-medium mb-2">Items</h4>
            <div className="space-y-1">
              {order.items.map((item, i) => (
                <div key={i} className="flex justify-between text-sm py-1 border-b border-border/50 last:border-0">
                  <span>{item.skuName} × {item.quantity}</span>
                  <span className="font-medium">${(item.price * item.quantity).toFixed(2)}</span>
                </div>
              ))}
            </div>
            <div className="flex justify-between font-bold text-sm mt-2 pt-2 border-t border-border">
              <span>Total</span>
              <span>${order.totalPrice.toFixed(2)}</span>
            </div>
          </div>
        </div>
      </DialogContent>
    </Dialog>
  );
}

export default function OrderHistory() {
  const { user } = useAuth();
  const [orders, setOrders] = useState<Order[]>([]);
  const [refreshKey, setRefreshKey] = useState(0);

  useEffect(() => {
    async function fetchOrders() {
      const result = await store.getOrders(user?.id || "");
      setOrders(result.slice().reverse());
    }
    fetchOrders();
  }, [user?.id, refreshKey]);

  return (
    <DashboardLayout role="retailer">
      <div className="space-y-6">
        <div className="flex items-center justify-between">
          <div>
            <h1 className="text-2xl font-bold">Order History</h1>
            <p className="text-muted-foreground text-sm mt-1">Track and review your orders</p>
          </div>
          <Button variant="outline" size="sm" onClick={() => setRefreshKey((r) => r + 1)}>Refresh</Button>
        </div>

        {orders.length === 0 ? (
          <Card>
            <CardContent className="flex flex-col items-center justify-center py-16">
              <PackageIcon className="h-12 w-12 text-muted-foreground/30 mb-3" />
              <p className="text-muted-foreground">No orders yet</p>
            </CardContent>
          </Card>
        ) : (
          <Card>
            <CardContent className="p-0">
              <div className="overflow-x-auto">
                <table className="w-full text-sm">
                  <thead>
                    <tr className="border-b border-border bg-muted/50">
                      <th className="px-4 py-3 text-left">Order ID</th>
                      <th className="px-4 py-3 text-left">Date</th>
                      <th className="px-4 py-3 text-left">Delivery</th>
                      <th className="px-4 py-3 text-left">Items</th>
                      <th className="px-4 py-3 text-right">Total</th>
                      <th className="px-4 py-3 text-left">Status</th>
                      <th className="px-4 py-3 text-center">Details</th>
                    </tr>
                  </thead>
                  <tbody>
                    {orders.map((o) => (
                      <tr key={o.id} className="border-b border-border/50 hover:bg-muted/30">
                        <td className="px-4 py-3 font-mono text-xs">{o.id}</td>
                        <td className="px-4 py-3">{new Date(o.createdAt).toLocaleDateString()}</td>
                        <td className="px-4 py-3">{new Date(o.deliveryDate).toLocaleDateString()}</td>
                        <td className="px-4 py-3">{o.items.length}</td>
                        <td className="px-4 py-3 text-right font-medium">${o.totalPrice.toFixed(2)}</td>
                        <td className="px-4 py-3"><StatusIcon status={o.status} /> {o.status}</td>
                        <td className="px-4 py-3 text-center"><OrderDetailDialog order={o} /></td>
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