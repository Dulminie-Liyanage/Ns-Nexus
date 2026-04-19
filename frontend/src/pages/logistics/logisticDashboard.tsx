import { useState, useEffect } from "react";
import API from "../../lib/utils";
import DashboardLayout from "../../components/DashboardLayout";
import { StatsCard } from "../../components/StatsCard";
import { Card, CardContent, CardHeader, CardTitle } from "../../components/ui/card";
import { Button } from "../../components/ui/button";
import { Truck, MapPin, Users, Clock, Box } from "lucide-react";

import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogFooter,
} from "../../components/ui/dialog";

import { Label } from "../../components/ui/label";
import { Input } from "../../components/ui/input";
import {
  Select,
  SelectTrigger,
  SelectValue,
  SelectContent,
  SelectItem,
} from "../../components/ui/select";

const LogisticsDashboard = () => {
  const [shipments, setShipments] = useState<any[]>([]);
  const [drivers, setDrivers] = useState<any[]>([]);
  const [vehicles, setVehicles] = useState<any[]>([]);
  const [orders, setOrders] = useState<any[]>([]);

  const [newShipmentOpen, setNewShipmentOpen] = useState(false);
  const [selectedDriver, setSelectedDriver] = useState("");
  const [selectedVehicle, setSelectedVehicle] = useState("");
  const [departureTime, setDepartureTime] = useState("");

  useEffect(() => {
    const fetchData = async () => {
      try {
        const [driversRes] = await Promise.all([
          API.get("/drivers"),
        ]);

        setDrivers(
          (driversRes.data || []).map((d: any) => ({
            id: d.id,
            name: d.name,
            status: d.availability_status,
          }))
        );
      } catch (err) {
        console.error("Error loading drivers:", err);
      }
    };

    fetchData(); // run once

    const interval = setInterval(fetchData, 3000); // auto refresh

    return () => clearInterval(interval);
  }, []);

  const createShipment = async () => {
    try {
      const payload = {
        driverId: selectedDriver,
        vehicleType: selectedVehicle,
        departureTime,
      };

      await API.post("/shipments", payload);

      // refresh
      const res = await API.get("/shipments");
      setShipments(res.data);

      setNewShipmentOpen(false);
      setSelectedDriver("");
      setSelectedVehicle("");
      setDepartureTime("");
    } catch (err) {
      console.error("Failed to create shipment:", err);
    }
  };

  return (
    <DashboardLayout role="3pl_manager">
      <div className="space-y-6">

        {/* HEADER */}
        <div className="flex items-center justify-between">
          <div>
            <h1 className="text-2xl font-bold">Logistics Dashboard</h1>
            <p className="text-muted-foreground">
              Manage shipments, drivers, and routes
            </p>
          </div>

          <Button onClick={() => setNewShipmentOpen(true)}>
            <Truck className="w-4 h-4 mr-2" /> Create Shipment
          </Button>
        </div>

        {/* STATS */}
        <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
          <StatsCard
            title="Active Shipments"
            value={shipments.length}
            icon={<Truck className="w-5 h-5" />}
          />
          <StatsCard
            title="Available Drivers"
            value={drivers.length}
            icon={<Users className="w-5 h-5" />}
          />
          <StatsCard
            title="Awaiting Shipment"
            value={orders.filter(o => o.status === "approved").length}
            icon={<Clock className="w-5 h-5" />}
          />
          <StatsCard
            title="Vehicles"
            value={vehicles.length}
            icon={<MapPin className="w-5 h-5" />}
          />
        </div>

        {/* SHIPMENTS CARD*/}
        <Card>
          <CardHeader>
            <CardTitle>Shipments</CardTitle>
          </CardHeader>
          <CardContent>
            {shipments.map((s) => (
              <div key={s.id} className="flex justify-between border p-2 rounded">
                <span>Driver: {s.driver_id}</span>
                <span>{s.status}</span>
              </div>
            ))}
          </CardContent>
        </Card>

        {/* DRIVERS CARD */}
        <Card>
          <CardHeader>
            <CardTitle>Drivers</CardTitle>
          </CardHeader>

          <CardContent>
            {drivers.length === 0 ? (
              <p className="text-sm text-muted-foreground">
                No drivers found
              </p>
            ) : (
              <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
                
                {drivers.map((d) => (
                  <div
                    key={d.id}
                    className="p-4 border rounded-xl shadow-sm flex flex-col gap-2"
                  >
                    
                    {/* NAME */}
                    <div>
                      <p className="font-semibold text-lg">{d.name}</p>
                      <p className="text-xs text-muted-foreground">
                        Driver ID: {d.id}
                      </p>
                    </div>

                    {/* STATUS BADGE */}
                    <div>
                      <span
                        className={`text-xs px-3 py-1 rounded-full font-medium ${
                          d.availability_status === "AVAILABLE"
                            ? "bg-green-100 text-green-700"
                            : d.availability_status === "BUSY"
                            ? "bg-yellow-100 text-yellow-700"
                            : d.availability_status === "ON_BREAK"
                            ? "bg-blue-100 text-blue-700"
                            : "bg-gray-100 text-gray-600"
                        }`}
                      >
                        {d.availability_status}
                      </span>
                    </div>

                  </div>
                ))}

              </div>
            )}
          </CardContent>
        </Card>

        {/* CREATE SHIPMENT */}
        <Dialog open={newShipmentOpen} onOpenChange={setNewShipmentOpen}>
          <DialogContent>
            <DialogHeader>
              <DialogTitle>Create Shipment</DialogTitle>
            </DialogHeader>

            <div className="space-y-4">

              {/* DRIVER */}
              <div>
                <Label>Assign Driver</Label>
                <Select value={selectedDriver} onValueChange={setSelectedDriver}>
                  <SelectTrigger>
                    <SelectValue placeholder="Select driver" />
                  </SelectTrigger>

                  <SelectContent>
                    {drivers.length === 0 ? (
                      <SelectItem value="none" disabled>
                        No drivers available
                      </SelectItem>
                    ) : (
                      drivers.map((d) => (
                        <SelectItem key={d.id} value={String(d.id)}>
                          {d.name}
                        </SelectItem>
                      ))
                    )}
                  </SelectContent>
                </Select>
              </div>

              {/* VEHICLE */}
              <div>
                <Label>Vehicle</Label>
                <Select value={selectedVehicle} onValueChange={setSelectedVehicle}>
                  <SelectTrigger>
                    <SelectValue placeholder="Select vehicle" />
                  </SelectTrigger>

                  <SelectContent>
                    {vehicles.length === 0 ? (
                      <SelectItem value="none" disabled>
                        No vehicle found
                      </SelectItem>
                    ) : (
                      vehicles.map((v) => (
                        <SelectItem key={v.id} value={v.type}>
                          {v.type}
                        </SelectItem>
                      ))
                    )}
                  </SelectContent>
                </Select>
              </div>

              {/* TIME */}
              <div>
                <Label>Departure Time</Label>
                <Input
                  type="datetime-local"
                  value={departureTime}
                  onChange={(e) => setDepartureTime(e.target.value)}
                />
              </div>

            </div>

            <DialogFooter>
              <Button variant="outline" onClick={() => setNewShipmentOpen(false)}>
                Cancel
              </Button>

              <Button
                onClick={createShipment}
                disabled={!selectedDriver || !selectedVehicle || !departureTime}
              >
                Create
              </Button>
            </DialogFooter>
          </DialogContent>
        </Dialog>

      </div>
    </DashboardLayout>
  );
};

export default LogisticsDashboard;