import { useState } from "react";
import DashboardLayout from "@/components/DashboardLayout";
import { store } from "@/lib/store";
import { Card, CardContent } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Textarea } from "@/components/ui/textarea";
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogTrigger, DialogFooter } from "@/components/ui/dialog";
import { Eye, CheckCircle, XCircle, Clock } from "lucide-react";
import type { Order } from "@/lib/store";

function StatusIcon({ status }: { status: string }) {
  switch (status) {
    case "Pending": return <Clock className="h-4 w-4 text-warning" />;
    case "Approved": return <CheckCircle className="h-4 w-4 text-success" />;
    case "Rejected": return <XCircle className="h-4 w-4 text-destructive" />;
    default: return null;
  }
}

function OrderActions({ order, onUpdate }: { order: Order; onUpdate: () => void }) {
  const [rejectOpen, setRejectOpen] = useState(false);
  const [reason, setReason] = useState("");
  const [detailOpen, setDetailOpen] = useState(false);

  const handleApprove = () => {
    store.updateOrderStatus(order.id, "Approved");
    onUpdate();
  };

  const handleReject = () => {
    if (!reason.trim()) return;
    store.updateOrderStatus(order.id, "Rejected", reason);
    setRejectOpen(false);
    setReason("");
    onUpdate();
  };

  return (
    <div className="flex items-center gap-1">
      <Dialog open={detailOpen} onOpenChange={setDetailOpen}>
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

      {order.status === "Pending" && (
        <>
          <Button variant="ghost" size="sm" onClick={handleApprove} className="text-success hover:text-success">
            <CheckCircle className="h-4 w-4" />
          </Button>
          <Dialog open={rejectOpen} onOpenChange={setRejectOpen}>
            <DialogTrigger asChild>
              <Button variant="ghost" size="sm" className="text-destructive hover:text-destructive">
                <XCircle className="h-4 w-4" />
              </Button>
            </DialogTrigger>
            <DialogContent>
              <DialogHeader><DialogTitle>Reject Order {order.id}</DialogTitle></DialogHeader>
              <div className="space-y-3">
                <label className="text-sm font-medium">Rejection Reason (required)</label>
                <Textarea value={reason} onChange={(e) => setReason(e.target.value)} placeholder="Enter reason for rejection..." />
              </div>
              <DialogFooter>
                <Button variant="outline" onClick={() => setRejectOpen(false)}>Cancel</Button>
                <Button variant="destructive" onClick={handleReject} disabled={!reason.trim()}>Reject Order</Button>
              </DialogFooter>
            </DialogContent>
          </Dialog>
        </>
      )}
    </div>
  );
}

export default function AdminOrders() {
  const [, setRefresh] = useState(0);
  const orders = store.getOrders().slice().reverse();
  const triggerRefresh = () => setRefresh((r) => r + 1);

  return (
    <DashboardLayout role="admin">
      <div className="space-y-6">
        <div>
          <h1 className="text-2xl font-bold">Manage Orders</h1>
          <p className="text-muted-foreground text-sm mt-1">Review, approve, or reject retailer orders</p>
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
                        <OrderActions order={o} onUpdate={triggerRefresh} />
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
