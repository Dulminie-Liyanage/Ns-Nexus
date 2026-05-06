import { useState, useEffect } from "react";
import DashboardLayout from "@/components/DashboardLayout";
import { store, Product } from "@/lib/store";
import { Card, CardContent } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Switch } from "@/components/ui/switch";
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogTrigger, DialogFooter } from "@/components/ui/dialog";
import { Plus, Package } from "lucide-react";

export default function Inventory() {
  const [products, setProducts] = useState<Product[]>([]);
  const [refreshKey, setRefreshKey] = useState(0);

  const [addOpen, setAddOpen] = useState(false);
  const [name, setName] = useState("");
  const [sku, setSku] = useState("");
  const [price, setPrice] = useState("");
  const [weight, setWeight] = useState("");

  // Fetch products
  useEffect(() => {
    async function fetchProducts() {
      const prods = await store.getProducts();
      setProducts(prods);
    }
    fetchProducts();
  }, [refreshKey]);

  // Add new product
  const handleAdd = async () => {
    if (!name || !sku || !price || !weight) return;

    await store.addProduct({
      name,
      sku,
      price: parseFloat(price),
      weight: parseFloat(weight),
      available: true,
    });

    setName(""); setSku(""); setPrice(""); setWeight("");
    setAddOpen(false);
    setRefreshKey((r) => r + 1);
  };

  // Toggle availability
  const toggleAvail = async (id: string) => {
    await store.toggleAvailability(id);
    setRefreshKey((r) => r + 1);
  };

  return (
    <DashboardLayout role="admin">
      <div className="space-y-6">
        {/* HEADER + ADD */}
        <div className="flex items-center justify-between">
          <div>
            <h1 className="text-2xl font-bold">Inventory Management</h1>
            <p className="text-muted-foreground text-sm mt-1">Manage SKUs and product availability</p>
          </div>

          <Dialog open={addOpen} onOpenChange={setAddOpen}>
            <DialogTrigger asChild>
              <Button><Plus className="h-4 w-4 mr-2" /> Add SKU</Button>
            </DialogTrigger>
            <DialogContent>
              <DialogHeader><DialogTitle>Add New SKU</DialogTitle></DialogHeader>
              <div className="space-y-4">
                <div className="space-y-2">
                  <Label>Product Name</Label>
                  <Input value={name} onChange={(e) => setName(e.target.value)} placeholder="e.g. Widget F" />
                </div>
                <div className="space-y-2">
                  <Label>SKU Code</Label>
                  <Input value={sku} onChange={(e) => setSku(e.target.value)} placeholder="e.g. SKU-006" />
                </div>
                <div className="grid grid-cols-2 gap-4">
                  <div className="space-y-2">
                    <Label>Price ($)</Label>
                    <Input type="number" value={price} onChange={(e) => setPrice(e.target.value)} placeholder="0.00" />
                  </div>
                  <div className="space-y-2">
                    <Label>Weight (kg)</Label>
                    <Input type="number" value={weight} onChange={(e) => setWeight(e.target.value)} placeholder="0.0" />
                  </div>
                </div>
              </div>
              <DialogFooter>
                <Button variant="outline" onClick={() => setAddOpen(false)}>Cancel</Button>
                <Button onClick={handleAdd} disabled={!name || !sku || !price || !weight}>Add Product</Button>
              </DialogFooter>
            </DialogContent>
          </Dialog>
        </div>

        {/* PRODUCTS TABLE */}
        <Card>
          <CardContent className="p-0">
            <div className="overflow-x-auto">
              <table className="w-full text-sm">
                <thead>
                  <tr className="border-b border-border bg-muted/50">
                    <th className="text-left py-3 px-4 font-medium text-muted-foreground">Product</th>
                    <th className="text-left py-3 px-4 font-medium text-muted-foreground">SKU</th>
                    <th className="text-right py-3 px-4 font-medium text-muted-foreground">Price</th>
                    <th className="text-right py-3 px-4 font-medium text-muted-foreground">Weight</th>
                    <th className="text-center py-3 px-4 font-medium text-muted-foreground">Available</th>
                  </tr>
                </thead>
                <tbody>
                  {products.map((p) => (
                    <tr key={p.id} className="border-b border-border/50 hover:bg-muted/30 transition-colors">
                      <td className="py-3 px-4 font-medium flex items-center gap-2">
                        <Package className="h-4 w-4 text-muted-foreground" />
                        {p.name}
                      </td>
                      <td className="py-3 px-4 font-mono text-xs">{p.sku}</td>
                      <td className="py-3 px-4 text-right">${p.price.toFixed(2)}</td>
                      <td className="py-3 px-4 text-right">{p.weight} kg</td>
                      <td className="py-3 px-4 text-center">
                        <div className="flex items-center justify-center gap-2">
                          <Switch checked={p.available} onCheckedChange={() => toggleAvail(p.id)} />
                          <span className={`text-xs ${p.available ? "text-success" : "text-muted-foreground"}`}>
                            {p.available ? "In Stock" : "Sold Out"}
                          </span>
                        </div>
                      </td>
                    </tr>
                  ))}
                  {products.length === 0 && (
                    <tr><td colSpan={5} className="py-12 text-center text-muted-foreground">No products yet</td></tr>
                  )}
                </tbody>
              </table>
            </div>
          </CardContent>
        </Card>
      </div>
    </DashboardLayout>
  );
}