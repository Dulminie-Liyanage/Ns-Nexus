import { useEffect, useState } from "react";
import { StatsCard } from "../../components/StatsCard";
import { Card, CardContent, CardHeader, CardTitle } from "../../components/ui/card";
import { Button } from "../../components/ui/button";
import { Badge } from "../../components/ui/badge";
import { getShipments, updateShipment } from "../../serv/shipmentService.ts";
import { Truck, CheckCircle2, Clock } from "lucide-react";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue, } from "../../components/ui/select";
import DashboardLayout from "../../components/DashboardLayout";
import API from "../../lib/utils";

const DriverDashboard = () => {
  const [availability, setAvailability] = useState("available");
  const [myShipments, setMyShipments] = useState<any[]>([]);

  useEffect(() => {
    const fetchShipments = async () => {
      try {
        const shipments = await getShipments();

        const user = JSON.parse(localStorage.getItem("user") || "{}");

        const filtered = shipments.filter(
          (s: any) => s.driver_id === user.id
        );

        setMyShipments(filtered);
      } catch (error) {
        console.error("Error fetching shipments:", error);
      }
    };

    fetchShipments();
  }, []);

  return (
    <DashboardLayout role="driver">
      <div className="space-y-6">
        
        {/* HEADER */}
        <div>
          <h1 className="text-2xl font-bold">Driver Dashboard</h1>
          <p className="text-muted-foreground text-sm mt-1">
            View assignments and update delivery status
          </p>
        </div>

        {/* STATUS */}
        <div className="flex items-center gap-2">
          <span className="text-sm text-muted-foreground">Status:</span>
          <Select 
            value={availability} 
            onValueChange={async (value) => {
              setAvailability(value);
            
              try {
                const user = JSON.parse(localStorage.getItem("user") || "{}");

                await fetch(`http://localhost:5000/api/drivers/${user.id}/status`, { 
                  method: "PUT",
                  headers: {
                    "Content-Type": "application/json"
                  },
                  body: JSON.stringify({ status: value })
                });
                console.log("Status updated successfully");
              } catch (err) {
                console.error("Failed to update status:", err);
              }
            }}
          >
            <SelectTrigger className="w-40">
              <SelectValue />
            </SelectTrigger>
            <SelectContent>
              <SelectItem value="AVAILABLE">Available</SelectItem>
              <SelectItem value="BUSY">Busy</SelectItem>
              <SelectItem value="ON_BREAK">On Break</SelectItem>
            </SelectContent>
          </Select>
        </div>

        {/* STATS */}
        <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
          <StatsCard
            title="Assigned Deliveries"
            value={myShipments.length}
            icon={<Truck className="w-5 h-8" />}
          />
          <StatsCard
            title="Completed"
            value={myShipments.filter((s) => s.status === "delivered").length}
            icon={<CheckCircle2 className="w-5 h-5" />}
          />
          <StatsCard
            title="Upcoming"
            value={myShipments.filter((s) => s.status === "scheduled").length}
            icon={<Clock className="w-5 h-5" />}
          />
        </div>

        {/* DELIVERY LIST */}
        <Card>
          <CardHeader>
            <CardTitle className="text-lg">My Deliveries</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="space-y-4">
              {myShipments.length === 0 ? (
                <p className="text-muted-foreground text-sm">
                  No deliveries assigned
                </p>
              ) : (
                myShipments.map((s) => (
                  <div
                    key={s.id}
                    className="p-4 rounded-lg border bg-muted/30 flex items-center justify-between"
                  >
                    <div className="space-y-1">
                      <p className="font-semibold">
                        Vehicle: {s.vehicle_reg || "-"}
                      </p>

                      <p className="text-sm text-muted-foreground">
                        Departure:{" "}
                        {s.departure_time
                          ? new Date(s.departure_time).toLocaleString()
                          : "-"}
                      </p>

                      <p className="text-sm text-muted-foreground">
                        Orders: {s.order_count || 0}
                      </p>
                    </div>

                    <div className="flex items-center gap-3">
                      <Badge
                        variant="outline"
                        className={
                          s.status === "delivered"
                            ? "bg-green-100 text-green-700"
                            : "bg-blue-100 text-blue-700"
                        }
                      >
                        {s.status}
                      </Badge>

                      {s.status === "scheduled" && (
                        <Button
                          size="sm"
                          onClick={async () => {
                            try {
                              await updateShipment(s.id, "delivered");

                              const updated = await getShipments();
                              const user = JSON.parse(
                                localStorage.getItem("user") || "{}"
                              );

                              setMyShipments(
                                updated.filter(
                                  (x: any) => x.driver_id === user.id
                                )
                              );
                            } catch (error) {
                              console.error(
                                "Error updating shipment:",
                                error
                              );
                            }
                          }}
                        >
                          Confirm Delivery
                        </Button>
                      )}
                    </div>
                  </div>
                ))
              )}
            </div>
          </CardContent>
        </Card>

      </div>
    </DashboardLayout>
  );
};

export default DriverDashboard;