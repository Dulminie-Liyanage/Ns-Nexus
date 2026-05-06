import { useEffect, useState } from "react";
import DashboardLayout from "@/components/DashboardLayout";
import { store } from "@/lib/store";
import { Card, CardContent } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogTrigger, DialogFooter } from "@/components/ui/dialog";
import { Textarea } from "@/components/ui/textarea";
import { Eye, Clock, CheckCircle, XCircle } from "lucide-react";
import type { Order } from "@/lib/store";

function StatusIcon({ status }: { status: string }) {
  switch (status) {
    case "Pending": return <Clock className="h-4 w-4 text-warning" />;
    case "Approved": return <CheckCircle className="h-4 w-4 text-success" />;
    case "Rejected": return <XCircle className="h-4 w-4 text-destructive" />;
    default: return null;
  }
}

function OrderDetails({ order }: { order: Order }) {
  const [open, setOpen] = useState(false);

  return (
    <Dialog open={open} onOpenChange={setOpen}>
      <DialogTrigger asChild>
        <Button variant="ghost" size="sm"><Eye className="h-4 w-4" /></Button>
      </DialogTrigger>
      <DialogContent className="max-w-lg">
        <DialogHeader><DialogTitle>Order {order.id}</DialogTitle></DialogHeader>
        <div className="space-y-3 text-sm">
          <div className="grid grid-cols-2 gap-2">
            <div><span className="text-muted-foreground">Retailer:</span> {order.retailerName}</div>
            <div><span className="text-muted-foreground">Status:</span> {order.status}</div>
            <div><span className="text-muted-foreground">Date:</span> {new Date(order.createdAt).toLocaleDateString()}</div>
            <div><span className="text-muted-foreground">Delivery:</span> {new Date(order.deliveryDate).toLocaleDateString()}</div>
            <div><span className="text-muted-foreground">Weight:</span> {order.totalWeight.toFixed(2)} kg</div>
            <div><span className="text-muted-foreground">Total:</span> ${order.totalPrice.toFixed(2)}</div>
          </div>
          {order.rejectionReason && (
            <div className="rounded-lg bg-destructive/10 border border-destructive/20 p-3">
              <p className="font-medium text-destructive text-xs">Rejection Reason:</p>
              <p className="text-destructive/80">{order.rejectionReason}</p>
            </div>
          )}
          <div>
            <h4 className="font-medium mb-1">Items</h4>
            {order.items.map((item, i) => (
              <div key={i} className="flex justify-between py-1 border-b border-border/50 last:border-0">
                <span>{item.skuName} × {item.quantity}</span>
                <span className="font-medium">${(item.price * item.quantity).toFixed(2)}</span>
              </div>
            ))}
          </div>
        </div>
      </DialogContent>
    </Dialog>
  );
}

export default function AdminOrders() {
  const [orders, setOrders] = useState<Order[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    async function fetchOrders() {
      const allOrders = await store.getOrders(""); // pass empty string for all retailers
      setOrders(allOrders.slice().reverse());
      setLoading(false);
    }
    fetchOrders();
  }, []);

  if (loading) return <DashboardLayout role="admin"><p className="p-6">Loading orders...</p></DashboardLayout>;

  return (
    <DashboardLayout role="admin">
      <div className="space-y-6">
        <div>
          <h1 className="text-2xl font-bold">Manage Orders</h1>
          <p className="text-muted-foreground text-sm mt-1">View all retailer orders</p>
        </div>

        <Card>
          <CardContent className="p-0">
            <div className="overflow-x-auto">
              <table className="w-full text-sm">
                <thead>
                  <tr className="border-b border-border bg-muted/50">
                    <th className="text-left py-3 px-4 font-medium text-muted-foreground">Order ID</th>
                    <th className="text-left py-3 px-4 font-medium text-muted-foreground">Retailer</th>
                    <th className="text-left py-3 px-4 font-medium text-muted-foreground">Date</th>
                    <th className="text-left py-3 px-4 font-medium text-muted-foreground">Items</th>
                    <th className="text-right py-3 px-4 font-medium text-muted-foreground">Total</th>
                    <th className="text-left py-3 px-4 font-medium text-muted-foreground">Status</th>
                    <th className="text-center py-3 px-4 font-medium text-muted-foreground">Actions</th>
                  </tr>
                </thead>
                <tbody>
                  {orders.length === 0 ? (
                    <tr><td colSpan={7} className="py-12 text-center text-muted-foreground">No orders yet</td></tr>
                  ) : orders.map((o) => (
                    <tr key={o.id} className="border-b border-border/50 hover:bg-muted/30 transition-colors">
                      <td className="py-3 px-4 font-mono text-xs">{o.id}</td>
                      <td className="py-3 px-4">{o.retailerName}</td>
                      <td className="py-3 px-4">{new Date(o.createdAt).toLocaleDateString()}</td>
                      <td className="py-3 px-4">{o.items.length}</td>
                      <td className="py-3 px-4 text-right font-medium">${o.totalPrice.toFixed(2)}</td>
                      <td className="py-3 px-4">
                        <span className="inline-flex items-center gap-1.5">
                          <StatusIcon status={o.status} />
                          {o.status}
                        </span>
                      </td>
                      <td className="py-3 px-4 text-center">
                        <OrderDetails order={o} />
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </CardContent>
        </Card>
      </div>
    </DashboardLayout>
  );
}