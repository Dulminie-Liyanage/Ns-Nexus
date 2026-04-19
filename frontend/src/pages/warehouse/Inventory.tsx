import { useState, useEffect } from "react";
import DashboardLayout from "../../components/DashboardLayout";
import API from "../../lib/utils";
import axios from "../../api/axios";
import { Card, CardContent } from "../../components/ui/card";
import { Button } from "../../components/ui/button";
import { Input } from "../../components/ui/input";
import { Label } from "../../components/ui/label";
import { Switch } from "../../components/ui/switch";
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
  DialogFooter,
} from "../../components/ui/dialog";
import { Plus, Package } from "lucide-react";

interface Product {
  id: number;
  name: string;
  sku: string;
  price: number;
  weight: number;
  available: boolean;
}

export default function Inventory() {
  const [products, setProducts] = useState<Product[]>([]);
  const [refreshKey, setRefreshKey] = useState(0);

  const [addOpen, setAddOpen] = useState(false);
  const [name, setName] = useState("");
  const [sku, setSku] = useState("");
  const [price, setPrice] = useState("");
  const [weight, setWeight] = useState("");

  // FETCH PRODUCTS
  useEffect(() => {
    async function fetchProducts() {
      try {
        const res = await API.get("/inventory/products");

        const data = res.data?.products || res.data?.data || res.data;

        // FIX: normalize DB field (IsAvailable → available)
        const normalized = (Array.isArray(data) ? data : []).map((p: any) => ({
          id: p.id || p.ProductID,
          name: p.name || p.ProductName,
          sku: p.sku || p.SKU,
          price: p.price || p.Price,
          weight: p.weight || p.Weight,
          available: p.available, 
        }));

        setProducts(normalized);
      } catch (err) {
        console.error("Failed to fetch products:", err);
        setProducts([]);
      }
    }

    fetchProducts();
  }, [refreshKey]);

  // ADD PRODUCT
  const handleAdd = async () => {
    if (!name || !sku || !price || !weight) return;

    try {
      await API.post("/products", {
        name,
        sku,
        price: parseFloat(price),
        weight: parseFloat(weight),
        unit: "Kg",
      });

      setName("");
      setSku("");
      setPrice("");
      setWeight("");
      setAddOpen(false);
      setRefreshKey((r) => r + 1);
    } catch (err: any) {
      console.error(err);
      alert(err.response?.data?.message || err.message);
    }
  };

  // TOGGLE STOCK (FIXED)
  const handleToggleStock = async (productId: number, currentStatus: boolean) => {
    try {
      await API.put(`/inventory/products/${productId}/availability`, {
        available: !currentStatus,
      });

      setProducts((prev) =>
        prev.map((p) =>
          p.id === productId
            ? { ...p, available: !currentStatus }
            : p
        )
      );
    } catch (err) {
      console.error("Failed to update stock", err);
    }
  };
  
  return (
    <DashboardLayout role="warehouse_manager">
      <div className="space-y-6">
        {/* HEADER */}
        <div className="flex items-center justify-between">
          <div>
            <h1 className="text-2xl font-bold text-[#0a3c75]">
              Inventory Management
            </h1>
            <p className="text-muted-foreground text-sm mt-1">
              Manage SKUs and product availability
            </p>
          </div>

          <Dialog open={addOpen} onOpenChange={setAddOpen}>
            <DialogTrigger asChild>
              <Button className="bg-[#0a3c75] hover:bg-[#082c56]">
                <Plus className="h-4 w-4 mr-2" />
                Add Product
              </Button>
            </DialogTrigger>

            <DialogContent>
              <DialogHeader>
                <DialogTitle>Add New Product</DialogTitle>
              </DialogHeader>

              <div className="space-y-4">
                <div>
                  <Label>Product Name</Label>
                  <Input value={name} onChange={(e) => setName(e.target.value)} />
                </div>

                <div>
                  <Label>SKU</Label>
                  <Input value={sku} onChange={(e) => setSku(e.target.value)} />
                </div>

                <div className="grid grid-cols-2 gap-4">
                  <div>
                    <Label>Price</Label>
                    <Input
                      type="number"
                      value={price}
                      onChange={(e) => setPrice(e.target.value)}
                    />
                  </div>

                  <div>
                    <Label>Weight</Label>
                    <Input
                      type="number"
                      value={weight}
                      onChange={(e) => setWeight(e.target.value)}
                      placeholder="0.0"
                    />
                  </div>
                </div>
              </div>

              <DialogFooter>
                <Button variant="outline" onClick={() => setAddOpen(false)}>
                  Cancel
                </Button>
                <Button
                  onClick={handleAdd}
                  className="bg-[#0a3c75] hover:bg-[#082c56]"
                  disabled={!name || !sku || !price || !weight}
                >
                  Add
                </Button>
              </DialogFooter>
            </DialogContent>
          </Dialog>
        </div>

        {/* TABLE */}
        <Card className="shadow-sm">
          <CardContent className="p-0">
            <table className="w-full text-sm">
              <thead>
                <tr className="border-b bg-muted/50">
                  <th className="text-left p-3">Product</th>
                  <th className="text-left p-3">SKU</th>
                  <th className="text-right p-3">Price</th>
                  <th className="text-right p-3">Weight</th>
                  <th className="text-center p-3">Available</th>
                </tr>
              </thead>

              <tbody>
                {products.map((p) => (
                  <tr key={p.id} className="border-b hover:bg-muted/30">
                    <td className="p-3 flex items-center gap-2">
                      <Package className="h-4 w-4 text-[#0a3c75]" />
                      {p.name}
                    </td>

                    <td className="p-3 font-mono text-xs">{p.sku}</td>

                    <td className="p-3 text-right">
                      LKR {Number(p.price || 0).toFixed(2)}
                    </td>

                    <td className="p-3 text-right">{p.weight} kg</td>

                    <td className="p-3 text-center">
                      <div className="flex items-center justify-center gap-2">
                        <Switch
                          checked={p.available}
                          onCheckedChange={() =>
                            handleToggleStock(p.id, p.available)
                          }
                        />

                        <span
                          className={`text-xs ${
                            p.available ? "text-green-600" : "text-red-500"
                          }`}
                        >
                          {p.available ? "In Stock" : "Out of Stock"}
                        </span>
                      </div>
                    </td>
                  </tr>
                ))}

                {products.length === 0 && (
                  <tr>
                    <td colSpan={5} className="p-8 text-center">
                      No products found
                    </td>
                  </tr>
                )}
              </tbody>
            </table>
          </CardContent>
        </Card>
      </div>
    </DashboardLayout>
  );
}