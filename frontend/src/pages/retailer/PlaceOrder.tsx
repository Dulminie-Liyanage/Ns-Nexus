import { useState, useEffect } from "react";
import { useNavigate } from "react-router-dom";
import DashboardLayout from "../../components/DashboardLayout";
import { useAuth } from "../../lib/auth-context";
import API from "../../lib/utils";
import { Button } from "../../../src/components/ui/button";
import { Input } from "../../components/ui/input";
import { Card, CardContent, CardHeader, CardTitle } from "../../components/ui/card";
import { CalendarIcon, Plus, Trash2, ShoppingCart, AlertCircle, CheckCircle } from "lucide-react";
import { format, addHours, isAfter } from "date-fns";
import { DayPicker } from "react-day-picker";
import { Popover, PopoverContent, PopoverTrigger } from "../../components/ui/popover";
import { cn } from "../../lib/utils";
import "react-day-picker/dist/style.css";

interface Product {
  id: string;
  name: string;
  sku: string;
  price: number;
  weight: number;
}

interface OrderItem {
  skuId: string;
  quantity: number;
}

interface PastOrder {
  id: string;
  items: OrderItem[];
}

export default function PlaceOrder() {
  const { user } = useAuth();
  const navigate = useNavigate();

  const [products, setProducts] = useState<Product[]>([]);
  const [pastOrders, setPastOrders] = useState<PastOrder[]>([]);
  const [items, setItems] = useState<OrderItem[]>([]);

  const [deliveryDate, setDeliveryDate] = useState<Date>();
  const [calendarOpen, setCalendarOpen] = useState(false);
  const [error, setError] = useState("");
  const [success, setSuccess] = useState("");
  const [urgent, setUrgent] = useState(false);
  const [quickOrderOpen, setQuickOrderOpen] = useState(false);

  const minDate = addHours(new Date(), 48);

  // FETCH DATA
  useEffect(() => {
    API.get<{ products: Product[] }>("/inventory/products")
      .then(res => setProducts(res.data.products))
      .catch(console.error);

    if (user) {
      API.get<{ orders: PastOrder[] }>(`/orders/retailer/${user.id}`)
        .then(res => setPastOrders(res.data.orders))
        .catch(console.error);
    }
  }, [user]);

  const addItem = (skuId: string, qty = 1) => {
    if (items.find(i => i.skuId === skuId)) return;
    setItems([...items, { skuId, quantity: qty }]);
  };

  const updateQty = (skuId: string, qty: number) => {
    if (qty < 1) return;
    setItems(items.map(i => (i.skuId === skuId ? { ...i, quantity: qty } : i)));
  };

  const removeItem = (skuId: string) => {
    setItems(items.filter(i => i.skuId !== skuId));
  };

  const orderItems = items.map(i => {
    const p = products.find(pr => pr.id === i.skuId);
    return {
      skuId: i.skuId,
      skuName: p?.name,
      quantity: i.quantity,
      price: p?.price || 0,
      weight: p?.weight || 0,
    };
  });

  const totalPrice = orderItems.reduce((sum, i) => sum + i.price * i.quantity, 0);
  const totalWeight = orderItems.reduce((sum, i) => sum + i.weight * i.quantity, 0);

  // SUBMIT ORDER (UPDATED URGENT LOGIC)
  const handleSubmit = async () => {
    console.log("SUBMIT STARTED");
    setError("");

    if (!items.length) {
      setError("Add at least one item");
      return;
    }

    if (!deliveryDate) {
      setError("Select a delivery date");
      return;
    }

    if (!urgent && !isAfter(deliveryDate, minDate)) {
      setError("Delivery date must be at least 48 hours from now");
      return;
    }

    try {
      const payload = {
        retailer_id: user!.id,
        delivery_date: deliveryDate.toISOString(),
        is_urgent: urgent,
        items: orderItems.map(i => ({
          productId: Number(i.skuId),
          qty: i.quantity,
          price: i.price 
        })),
      };

      // GET TOKEN
      const token = localStorage.getItem("token");

      // STOP if no token
      if (!token) {
        setError("You are not logged in. Please login again.");
        return;
      }

      // SEND TOKEN
      const res = await API.post<{ orderId: string }>(
        "/orders",
        payload,
        {
          headers: {
            Authorization: `Bearer ${token}`,
          },
        }
      );

      console.log("ORDER RESPONSE:", res.data); 

      // SUCCESS POPUP
      setSuccess(`Order #${res.data.orderId} placed successfully!`);

      setItems([]);
      setDeliveryDate(undefined);
      setUrgent(false);

      // REDIRECT
      setTimeout(() => navigate("/dashboard/history"), 2000);

    } catch (err: any) {
      console.error("ORDER ERROR:", err);

      setError(
        err.response?.data?.message ||
        "Failed to place order"
      );
    }
  };

  if (success) {
    return (
      <DashboardLayout role="retailer">
        <div className="flex flex-col items-center justify-center py-20 space-y-4">
          <div className="h-16 w-16 rounded-full bg-green-100 flex items-center justify-center">
            <CheckCircle className="h-8 w-8 text-green-600" />
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
          <Card className="bg-blue-50 border-blue-100">
            <CardHeader>
              <CardTitle className="text-blue-900">Past Orders</CardTitle>
            </CardHeader>
            <CardContent className="space-y-2">
              {pastOrders.length === 0 ? (
                <p className="text-sm text-blue-600/70">No past orders found</p>
              ) : pastOrders.map(o => (
                <Button
                  key={o.id}
                  variant="outline"
                  size="sm"
                  className="w-full justify-between bg-white hover:bg-blue-100"
                  onClick={() => {
                    setItems(o.items.map((i: any) => ({ skuId: i.skuId, quantity: i.quantity })));
                    setDeliveryDate(undefined);
                    setQuickOrderOpen(false);
                  }}
                >
                  <span>Order #{o.id}</span>
                  <span className="text-xs text-muted-foreground">{o.items.length} items</span>
                </Button>
              ))}
            </CardContent>
          </Card>
        )}

        {error && (
          <div className="flex items-center gap-2 rounded-lg border border-destructive/30 bg-destructive/10 p-3 text-sm text-destructive">
            <AlertCircle className="h-4 w-4 shrink-0" />
            {error}
          </div>
        )}

        <div className="grid gap-6 lg:grid-cols-3">
          <div className="lg:col-span-2 space-y-4">
            <Card>
              <CardHeader>
                <CardTitle className="text-lg">Available Products</CardTitle>
              </CardHeader>
              <CardContent>
                <div className="grid gap-3 sm:grid-cols-2">
                  {products.map(p => {
                    const inCart = items.find(i => i.skuId === p.id);
                    return (
                      <div key={p.id} className={cn(
                        "rounded-lg border p-4 transition-all",
                        inCart ? "border-[#0a3c75] bg-blue-50/50 shadow-sm" : "border-border hover:border-[#0a3c75]/40"
                      )}>
                        <div className="flex justify-between items-start">
                          <div>
                            <p className="font-semibold text-sm">{p.name}</p>
                            <p className="text-xs text-muted-foreground font-mono">{p.sku}</p>
                          </div>
                          <p className="font-bold text-sm text-[#0a3c75]">LKR {Number(p.price || 0).toFixed(2)}</p>
                        </div>
                        <p className="text-xs text-muted-foreground mt-1">{p.weight} kg</p>
                        {inCart ? (
                          <div className="flex items-center gap-2 mt-3">
                            <Input
                              type="number"
                              min={1}
                              value={inCart.quantity}
                              onChange={(e) => updateQty(p.id, parseInt(e.target.value) || 1)}
                              className="w-20 h-8 text-xs border-[#0a3c75]/30 focus-visible:ring-[#0a3c75]"
                            />
                            <Button variant="ghost" size="sm" className="h-8 w-8 p-0 text-destructive hover:bg-destructive/10" onClick={() => removeItem(p.id)}>
                              <Trash2 className="h-4 w-4" />
                            </Button>
                          </div>
                        ) : (
                          <Button variant="outline" size="sm" className="mt-3 h-8 text-xs border-[#0a3c75] text-[#0a3c75] hover:bg-[#0a3c75] hover:text-white" onClick={() => addItem(p.id)}>
                            <Plus className="h-3 w-3 mr-1" /> Add to Cart
                          </Button>
                        )}
                      </div>
                    );
                  })}
                </div>
              </CardContent>
            </Card>
          </div>

          <div className="space-y-4">
            <Card className="sticky top-6">
              <CardHeader>
                <CardTitle className="text-lg flex items-center gap-2">
                  <ShoppingCart className="h-5 w-5 text-[#0a3c75]" /> Order Summary
                </CardTitle>
              </CardHeader>
              <CardContent className="space-y-6">
                {orderItems.length === 0 ? (
                  <p className="text-sm text-muted-foreground text-center py-6 border-2 border-dashed rounded-lg">No items added to your order</p>
                ) : (
                  <div className="space-y-3">
                    <div className="max-h-75 overflow-y-auto pr-2 space-y-2">
                      {orderItems.map(item => (
                        <div key={item.skuId} className="flex justify-between text-sm items-center">
                          <div className="flex flex-col">
                            <span className="font-medium">{item.skuName}</span>
                            <span className="text-xs text-muted-foreground">Qty: {item.quantity}</span>
                          </div>
                          <span className="font-semibold">LKR {(item.price * item.quantity).toFixed(2)}</span>
                        </div>
                      ))}
                    </div>
                    <div className="border-t pt-3 space-y-2">
                      <div className="flex justify-between text-base font-bold text-[#0a3c75]">
                        <span>Total Price</span>
                        <span>LKR {totalPrice.toFixed(2)}</span>
                      </div>
                      <div className="flex justify-between text-xs text-muted-foreground">
                        <span>Total Weight</span>
                        <span>{totalWeight.toFixed(2)} kg</span>
                      </div>
                    </div>
                  </div>
                )}

                <div className="space-y-2">
                  <label className="text-sm font-semibold text-gray-700">Delivery Date</label>
                  <Popover open={calendarOpen} onOpenChange={setCalendarOpen}>
                    <PopoverTrigger asChild>
                      <Button
                        variant="outline"
                        className={cn("w-full justify-start text-left font-normal h-10", !deliveryDate && "text-muted-foreground")}
                      >
                        <CalendarIcon className="mr-2 h-4 w-4" />
                        {deliveryDate ? format(deliveryDate, "PPP") : "Select preferred date"}
                      </Button>
                    </PopoverTrigger>
                    <PopoverContent className="w-auto p-0" align="end">
                      <div className="p-3">
                        <DayPicker
                          mode="single"
                          selected={deliveryDate}
                          onSelect={(date) => {
                            if (!date) return;
                            setDeliveryDate(date);
                            setCalendarOpen(false);
                          }}
                          disabled={!urgent ? { before: minDate } : { before: new Date() }}
                        />
                      </div>
                    </PopoverContent>
                  </Popover>
                  <p className="text-[10px] text-muted-foreground">
                    {!urgent ? "Standard: 48-hour notice required" : "Urgent: Next-day/Same-day processing"}
                  </p>
                </div>

                <Button 
                  className="w-full rounded-xl bg-[#0a3c75] py-6 text-white text-lg font-bold hover:bg-[#082c56] shadow-md transition-all active:scale-[0.98]"
                  onClick={() => {
                    console.log("BUTTON CLICKED");
                    handleSubmit();
                  }}
                >
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