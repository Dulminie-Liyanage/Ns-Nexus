import { useState } from "react";
import { useNavigate } from "react-router-dom";
import DashboardLayout from "@/components/DashboardLayout";
import { useAuth } from "@/lib/auth-contex";
import { store, OrderItem } from "@/lib/store";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { CalendarIcon, Plus, Trash2, ShoppingCart, AlertCircle, CheckCircle } from "lucide-react";
import { format, addHours, isAfter } from "date-fns";
import { DayPicker } from "react-day-picker";
import { Popover, PopoverContent, PopoverTrigger } from "@/components/ui/popover";
import { cn } from "@/lib/utils";
import "react-day-picker/dist/style.css";

export default function PlaceOrder() {
  const { user } = useAuth();
  const navigate = useNavigate();
  const products = store.getAvailableProducts();
  const pastOrders = store.getOrders().filter(
    (o) => o.retailerId === user!.id
  ); 

  const [items, setItems] = useState<{ skuId: string; quantity: number }[]>([]);
  const [deliveryDate, setDeliveryDate] = useState<Date>();
  const [calendarOpen, setCalendarOpen] = useState(false);
  const [error, setError] = useState("");
  const [success, setSuccess] = useState("");
  const [urgent, setUrgent] = useState(false);
  const [quickOrderOpen, setQuickOrderOpen] = useState(false);

  const addItem = (productId: string, qty = 1) => {
    if (items.find((i) => i.skuId === productId)) return;
    setItems([...items, { skuId: productId, quantity: qty }]);
  };

  const updateQty = (skuId: string, qty: number) => {
    if (qty < 1) return;
    setItems(items.map((i) => (i.skuId === skuId ? { ...i, quantity: qty } : i)));
  };

  const removeItem = (skuId: string) => setItems(items.filter((i) => i.skuId !== skuId));

  const orderItems: OrderItem[] = items.map((i) => {
    const p = products.find((pr) => pr.id === i.skuId)!;
    return { skuId: i.skuId, skuName: p.name, quantity: i.quantity, price: p.price, weight: p.weight };
  });

  const totalPrice = orderItems.reduce((sum, i) => sum + i.price * i.quantity, 0);
  const totalWeight = orderItems.reduce((sum, i) => sum + i.weight * i.quantity, 0);
  const minDate = addHours(new Date(), 48);

  const handleSubmit = () => {
    setError("");
    if (items.length === 0) { setError("Add at least one item"); return; }
    if (!deliveryDate) { setError("Select a delivery date"); return; }
    if (!urgent && !isAfter(deliveryDate, minDate)) {
      setError("Delivery date must be at least 48 hours from now");
      return;
    }

    const order = store.createOrder({
      retailerId: user!.id,
      retailerName: user!.name,
      items: orderItems,
      deliveryDate: deliveryDate.toISOString(),
      totalPrice,
      totalWeight,
      urgent, // mark urgent orders
    });

    setSuccess(`Order ${order.id} placed successfully!`);
    setItems([]);
    setDeliveryDate(undefined);
    setUrgent(false);
    setTimeout(() => navigate("/dashboard/history"), 2000);
  };

  if (success) {
    return (
      <DashboardLayout role="retailer">
        <div className="flex flex-col items-center justify-center py-20 space-y-4">
          <div className="h-16 w-16 rounded-full bg-success/10 flex items-center justify-center">
            <CheckCircle className="h-8 w-8 text-success" />
          </div>
          <h2 className="text-xl font-bold">{success}</h2>
          <p className="text-muted-foreground text-sm">Redirecting to order history...</p>
        </div>
      </DashboardLayout>
    );
  }

  return (
    <DashboardLayout role="retailer">
      <div className="space-y-6">
        <div className="flex items-center justify-between">
          <div>
            <h1 className="text-2xl font-bold">Place Order</h1>
            <p className="text-muted-foreground text-sm mt-1">Select products and delivery date</p>
          </div>
          <div className="space-x-2">
            <Button size="sm" variant={urgent ? "destructive" : "outline"} onClick={() => setUrgent(!urgent)}>
              {urgent ? "Urgent Order Enabled" : "Enable Urgent Order"}
            </Button>
            <Button size="sm" variant="outline" onClick={() => setQuickOrderOpen(!quickOrderOpen)}>
              Quick Order
            </Button>
          </div>
        </div>

        {quickOrderOpen && (
          <Card className="bg-blue-50">
            <CardHeader>
              <CardTitle>Past Orders</CardTitle>
            </CardHeader>
            <CardContent className="space-y-2">
              {pastOrders.length === 0 ? (
                <p className="text-sm text-muted-foreground">No past orders</p>
              ) : (
                pastOrders.map((o) => (
                  <Button
                    key={o.id}
                    variant="outline"
                    size="sm"
                    className="w-full justify-between"
                    onClick={() => {
                      setItems(o.items.map((i) => ({ skuId: i.skuId, quantity: i.quantity })));
                      setDeliveryDate(undefined);
                      setQuickOrderOpen(false);
                    }}
                  >
                    Order #{o.id} - {o.items.length} items
                  </Button>
                ))
              )}
            </CardContent>
          </Card>
        )}

        {/* Error Message */}
        {error && (
          <div className="flex items-center gap-2 rounded-lg border border-destructive/30 bg-destructive/10 p-3 text-sm text-destructive">
            <AlertCircle className="h-4 w-4 shrink-0" />
            {error}
          </div>
        )}

        <div className="grid gap-6 lg:grid-cols-3">
          {/* Product Catalog */}
          <div className="lg:col-span-2 space-y-4">
            <Card>
              <CardHeader>
                <CardTitle className="text-lg">Available Products</CardTitle>
              </CardHeader>
              <CardContent>
                <div className="grid gap-3 sm:grid-cols-2">
                  {products.map((p) => {
                    const inCart = items.find((i) => i.skuId === p.id);
                    return (
                      <div
                        key={p.id}
                        className={cn(
                          "rounded-lg border p-4 transition-colors",
                          inCart ? "border-primary bg-accent" : "border-border hover:border-primary/40"
                        )}
                      >
                        <div className="flex justify-between items-start">
                          <div>
                            <p className="font-medium text-sm">{p.name}</p>
                            <p className="text-xs text-muted-foreground font-mono">{p.sku}</p>
                          </div>
                          <p className="font-bold text-sm">${p.price.toFixed(2)}</p>
                        </div>
                        <p className="text-xs text-muted-foreground mt-1">{p.weight} kg</p>
                        {inCart ? (
                          <div className="flex items-center gap-2 mt-3">
                            <Input
                              type="number"
                              min={1}
                              value={inCart.quantity}
                              onChange={(e) => updateQty(p.id, parseInt(e.target.value) || 1)}
                              className="w-20 h-8 text-xs"
                            />
                            <Button variant="ghost" size="sm" onClick={() => removeItem(p.id)}>
                              <Trash2 className="h-3 w-3" />
                            </Button>
                          </div>
                        ) : (
                          <Button variant="outline" size="sm" className="mt-3 h-8 text-xs" onClick={() => addItem(p.id)}>
                            <Plus className="h-3 w-3 mr-1" /> Add
                          </Button>
                        )}
                      </div>
                    );
                  })}
                </div>
              </CardContent>
            </Card>
          </div>

          {/* Order Summary */}
          <div className="space-y-4">
            <Card>
              <CardHeader>
                <CardTitle className="text-lg flex items-center gap-2">
                  <ShoppingCart className="h-4 w-4" /> Order Summary
                </CardTitle>
              </CardHeader>
              <CardContent className="space-y-4">
                {orderItems.length === 0 ? (
                  <p className="text-sm text-muted-foreground text-center py-4">No items added</p>
                ) : (
                  <div className="space-y-2">
                    {orderItems.map((item) => (
                      <div key={item.skuId} className="flex justify-between text-sm">
                        <span>{item.skuName} × {items.find((i) => i.skuId === item.skuId)?.quantity}</span>
                        <span className="font-medium">
                          ${(item.price * (items.find((i) => i.skuId === item.skuId)?.quantity || 0)).toFixed(2)}
                        </span>
                      </div>
                    ))}
                    <div className="border-t border-border pt-2 space-y-1">
                      <div className="flex justify-between text-sm font-bold">
                        <span>Total Price</span>
                        <span>${totalPrice.toFixed(2)}</span>
                      </div>
                      <div className="flex justify-between text-xs text-muted-foreground">
                        <span>Total Weight</span>
                        <span>{totalWeight.toFixed(2)} kg</span>
                      </div>
                    </div>
                  </div>
                )}

                {/* Delivery Date Picker */}
                <div className="space-y-2">
                  <label className="text-sm font-medium">Delivery Date</label>
                  <Popover open={calendarOpen} onOpenChange={setCalendarOpen}>
                    <PopoverTrigger asChild>
                      <Button
                        variant="outline"
                        className={cn("w-full justify-start text-left font-normal h-9 text-sm", !deliveryDate && "text-muted-foreground")}
                        onClick={() => setCalendarOpen(true)}
                      >
                        <CalendarIcon className="mr-2 h-4 w-4" />
                        {deliveryDate ? format(deliveryDate, "PPP") : "Pick a date"}
                      </Button>
                    </PopoverTrigger>
                    <PopoverContent className="w-auto p-0 z-50" align="start">
                      <div className="p-3">
                        <DayPicker
                          mode="single"
                          selected={deliveryDate}
                          onSelect={(date) => {
                            if (!date) return;
                            if (!urgent && !isAfter(date, minDate)) return;
                            setDeliveryDate(date);
                            setCalendarOpen(false); // auto-close
                          }}
                          disabled={!urgent ? { before: minDate } : undefined}
                        />
                        <p className="text-xs text-muted-foreground mt-2">
                          {!urgent ? "Minimum 48-hour lead time required" : "Urgent order: date can be today"}
                        </p>
                      </div>
                    </PopoverContent>
                  </Popover>
                </div>

                <Button className="w-full rounded-2xl bg-[#0a3c75] px-4 py-3 text-white font-semibold hover:bg-[#082c56]"
                   onClick={handleSubmit} disabled={items.length === 0}>
                  Place Order
                </Button>
              </CardContent>
            </Card>
          </div>
        </div>
      </div>
    </DashboardLayout>
  );
}