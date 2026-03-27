import { useState } from "react";
import DashboardLayout from "@/components/DashboardLayout";
import { useAuth } from "@/lib/auth-contex";
import { store } from "@/lib/store";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Progress } from "@/components/ui/progress";
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
} from "@/components/ui/dialog";
import { Button } from "@/components/ui/button";
import { Eye, Package, Truck, CheckCircle, XCircle, Clock } from "lucide-react";
import type { Order } from "@/lib/store";

/* ✅ 7 STEP PROGRESS */
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
    default: return <Package className="h-4 w-4" />;
  }
}

/* ✅ ORDER DETAIL DIALOG */
function OrderDetailDialog({ order }: { order: Order }) {
  return (
    <Dialog>
      <DialogTrigger asChild>
        <Button variant="ghost" size="sm">
          <Eye className="h-4 w-4" />
        </Button>
      </DialogTrigger>

      <DialogContent className="max-w-lg">
        <DialogHeader>
          <DialogTitle>Order {order.id}</DialogTitle>
        </DialogHeader>

        <div className="space-y-4">

          {/* ✅ 7 STEP TRACKER */}
          <div className="space-y-2">

            {/* Numbers */}
            <div className="flex justify-between text-[10px] text-muted-foreground">
              <span>1</span><span>2</span><span>3</span>
              <span>4</span><span>5</span><span>6</span><span>7</span>
            </div>

            {/* Labels */}
            <div className="flex justify-between text-[10px] text-muted-foreground">
              <span>Pending</span>
              <span>Approved</span>
              <span>Packing</span>
              <span>Transit</span>
              <span>3PL</span>
              <span>Out</span>
              <span>Done</span>
            </div>

            <Progress
              value={getProgress(order.status)}
              className={
                order.status === "Rejected"
                  ? "[&>div]:bg-destructive"
                  : "[&>div]:bg-success"
              }
            />
          </div>

          {/* DETAILS */}
          <div className="grid grid-cols-2 gap-3 text-sm">
            <div>
              <span className="text-muted-foreground">Status:</span>{" "}
              <span className="font-medium">{order.status}</span>
            </div>
            <div>
              <span className="text-muted-foreground">Date:</span>{" "}
              <span className="font-medium">
                {new Date(order.createdAt).toLocaleDateString()}
              </span>
            </div>
            <div>
              <span className="text-muted-foreground">Delivery:</span>{" "}
              <span className="font-medium">
                {new Date(order.deliveryDate).toLocaleDateString()}
              </span>
            </div>
            <div>
              <span className="text-muted-foreground">Weight:</span>{" "}
              <span className="font-medium">
                {order.totalWeight.toFixed(2)} kg
              </span>
            </div>
          </div>

          {/* REJECTION */}
          {order.rejectionReason && (
            <div className="rounded-lg bg-destructive/10 border border-destructive/20 p-3 text-sm">
              <p className="font-medium text-destructive">
                Rejection Reason:
              </p>
              <p className="text-destructive/80 mt-1">
                {order.rejectionReason}
              </p>
            </div>
          )}

          {/* ITEMS */}
          <div>
            <h4 className="text-sm font-medium mb-2">Items</h4>
            <div className="space-y-1">
              {order.items.map((item, i) => (
                <div
                  key={i}
                  className="flex justify-between text-sm py-1 border-b border-border/50 last:border-0"
                >
                  <span>
                    {item.skuName} × {item.quantity}
                  </span>
                  <span className="font-medium">
                    ${(item.price * item.quantity).toFixed(2)}
                  </span>
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

/* ✅ MAIN PAGE */
export default function OrderHistory() {
  const { user } = useAuth();
  const [refreshKey, setRefreshKey] = useState(0);

  const orders = store
    .getOrdersByRetailer(user?.id || "")
    .slice()
    .reverse();

  return (
    <DashboardLayout role="retailer">
      <div className="space-y-6">

        {/* HEADER + REFRESH */}
        <div className="flex items-center justify-between">
          <div>
            <h1 className="text-2xl font-bold">Order History</h1>
            <p className="text-muted-foreground text-sm mt-1">
              Track and review your orders
            </p>
          </div>

          <Button
            variant="outline"
            size="sm"
            onClick={() => setRefreshKey((prev) => prev + 1)}
          >
            Refresh
          </Button>
        </div>

        {/* TABLE */}
        {orders.length === 0 ? (
          <Card>
            <CardContent className="flex flex-col items-center justify-center py-16">
              <Package className="h-12 w-12 text-muted-foreground/30 mb-3" />
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
                      <tr
                        key={o.id}
                        className="border-b border-border/50 hover:bg-muted/30"
                      >
                        <td className="px-4 py-3 font-mono text-xs">
                          {o.id}
                        </td>
                        <td className="px-4 py-3">
                          {new Date(o.createdAt).toLocaleDateString()}
                        </td>
                        <td className="px-4 py-3">
                          {new Date(o.deliveryDate).toLocaleDateString()}
                        </td>
                        <td className="px-4 py-3">
                          {o.items.length}
                        </td>
                        <td className="px-4 py-3 text-right font-medium">
                          ${o.totalPrice.toFixed(2)}
                        </td>
                        <td className="px-4 py-3">
                          <span className="inline-flex items-center gap-1.5">
                            <StatusIcon status={o.status} />
                            {o.status}
                          </span>
                        </td>
                        <td className="px-4 py-3 text-center">
                          <OrderDetailDialog order={o} />
                        </td>
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