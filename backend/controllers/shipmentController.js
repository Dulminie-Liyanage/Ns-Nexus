import db from "../config/db.js";

//GET all shipment
export const getShipments = async (req, res) => {
  try {
    const [rows] = await db.query(`
      SELECT 
        s.ShipmentID AS id,
        s.DriverID AS driver_id,
        s.VehicleType AS vehicle_reg,
        s.DepartureTime AS departure_time,
        s.Status AS status,
        COUNT(si.ItemID) AS order_count
      FROM shipments s
      LEFT JOIN shipment_items si ON si.ShipmentID = s.ShipmentID
      GROUP BY s.ShipmentID
      ORDER BY s.DepartureTime DESC
    `);

    res.json(rows);
  } catch (err) {
    console.error("Error fetching shipments:", err);
    res.status(500).json({ error: err.message });
  }
};

// GET shipment by ID

export const getShipmentById = async (req, res) => {
  const { id } = req.params;

  try {
    const [rows] = await db.query(
      "SELECT * FROM shipments WHERE ShipmentID = ?",
      [id]
    );

    if (rows.length === 0) {
      return res.status(404).json({ message: "Shipment not found" });
    }

    res.json(rows[0]);
  } catch (err) {
    console.error("Error fetching shipment:", err);
    res.status(500).json({ error: err.message });
  }
};

// CREATE shipment
 
export const createShipment = async (req, res) => {
  const {
    driver_id,
    vehicle_type,
    departure_time,
    status,
    total_weight,
  } = req.body;

  try {
    const [result] = await db.query(
      `
      INSERT INTO shipments 
      (DriverID, VehicleType, DepartureTime, Status, TotalWeight)
      VALUES (?, ?, ?, ?, ?)
      `,
      [
        driver_id,
        vehicle_type,
        departure_time,
        status || "scheduled",
        total_weight || 0,
      ]
    );

    res.status(201).json({
      message: "Shipment created successfully",
      shipmentId: result.insertId,
    });
  } catch (err) {
    console.error("Error creating shipment:", err);
    res.status(500).json({ error: err.message });
  }
};

// UPDATE shipment status (Driver confirms delivery)
export const updateShipmentStatus = async (req, res) => {
  const { id } = req.params;
  const { status } = req.body;

  try {
    await db.query(
      `
      UPDATE shipments
      SET Status = ?
      WHERE ShipmentID = ?
      `,
      [status, id]
    );

    res.json({ message: "Shipment updated successfully" });
  } catch (err) {
    console.error("Error updating shipment:", err);
    res.status(500).json({ error: err.message });
  }
};