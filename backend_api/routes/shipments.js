const express = require('express');
const router = express.Router();
const db = require('../config/db');

// ── Auto-create tables on startup ─────────────────────────────────────────────
db.query(`
    CREATE TABLE IF NOT EXISTS shipments (
        ShipmentID   INT AUTO_INCREMENT PRIMARY KEY,
        DriverID     INT NULL,
        VehicleType  VARCHAR(50) DEFAULT 'Van',
        DepartureTime DATETIME,
        Status       VARCHAR(50) DEFAULT 'pending',
        TotalWeight  DECIMAL(10,2) DEFAULT 0,
        CreatedAt    TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (DriverID) REFERENCES users(UserID)
    )
`, (err) => {
    if (err) { console.error('Shipments table error:', err.message); return; }
    db.query(`
        CREATE TABLE IF NOT EXISTS shipment_items (
            ItemID     INT AUTO_INCREMENT PRIMARY KEY,
            ShipmentID INT NOT NULL,
            OrderID    INT NOT NULL,
            FOREIGN KEY (ShipmentID) REFERENCES shipments(ShipmentID),
            FOREIGN KEY (OrderID)    REFERENCES orders(OrderID)
        )
    `, (err2) => {
        if (err2) console.error('Shipment items table error:', err2.message);
        else console.log('Shipment tables ready');
    });
});

// ── POST /shipments/check-capacity ────────────────────────────────────────────
// Calculates total weight of selected orders and checks against vehicle limit
router.post('/check-capacity', (req, res) => {
    const { orderIds } = req.body;
    if (!orderIds || orderIds.length === 0) {
        return res.status(400).json({ message: 'No orders provided' });
    }
    db.query(
        'SELECT IFNULL(SUM(TotalWeight), 0) as totalWeight FROM orders WHERE OrderID IN (?)',
        [orderIds],
        (err, results) => {
            if (err) return res.status(500).json({ message: 'Database error', error: err.message });
            const totalWeight = parseFloat(results[0].totalWeight) || 0;
            const maxWeight = 1000; // kg capacity limit
            res.status(200).json({
                sufficient: totalWeight <= maxWeight,
                totalWeight,
                totalVolume: 0,
                maxWeight,
                maxVolume: 0,
            });
        }
    );
});

// ── POST /shipments — create a new shipment with driver assignment ─────────────
router.post('/', (req, res) => {
    const { orderIds, departureTime, driverId, vehicleType } = req.body;

    if (!orderIds || orderIds.length === 0 || !departureTime) {
        return res.status(400).json({ message: 'Missing required fields: orderIds and departureTime' });
    }

    // Parse driverId as integer (Flutter sends it as string)
    const driverIdInt = driverId ? parseInt(driverId) : null;

    // Step 1: Get total weight of selected orders
    db.query(
        'SELECT IFNULL(SUM(TotalWeight), 0) as totalWeight FROM orders WHERE OrderID IN (?)',
        [orderIds],
        (err, weightResult) => {
            if (err) return res.status(500).json({ message: 'Weight calculation failed', error: err.message });

            const totalWeight = parseFloat(weightResult[0].totalWeight) || 0;

            // Step 2: Insert shipment record
            db.query(
                'INSERT INTO shipments (DriverID, VehicleType, DepartureTime, Status, TotalWeight) VALUES (?, ?, ?, ?, ?)',
                [driverIdInt, vehicleType || 'Van', departureTime, 'in_transit', totalWeight],
                (err2, result) => {
                    if (err2) return res.status(500).json({ message: 'Failed to create shipment', error: err2.message });

                    const shipmentId = result.insertId;

                    // Step 3: Link each order to the shipment in shipment_items
                    const itemValues = orderIds.map(id => [shipmentId, parseInt(id)]);
                    db.query(
                        'INSERT INTO shipment_items (ShipmentID, OrderID) VALUES ?',
                        [itemValues],
                        (err3) => {
                            if (err3) return res.status(500).json({ message: 'Failed to link orders', error: err3.message });

                            // Step 4: Advance all orders to stage 5 (Ready to Ship)
                            db.query(
                                'UPDATE orders SET Status = ?, CurrentStage = 5 WHERE OrderID IN (?)',
                                ['ready_to_ship', orderIds],
                                (err4) => {
                                    if (err4) return res.status(500).json({ message: 'Order status update failed', error: err4.message });

                                    if (driverIdInt) {
                                        // Step 5a: Set driver as BUSY
                                        db.query(
                                            'UPDATE users SET CurrentStatus = ? WHERE UserID = ? AND Role = "driver"',
                                            ['BUSY', driverIdInt], () => {}
                                        );

                                        // Step 5b: Insert/update deliveries table for each order
                                        // This makes the orders visible on the driver's schedule screen
                                        const parsedIds = orderIds.map(id => parseInt(id));
                                        parsedIds.forEach(orderId => {
                                            db.query(
                                                'SELECT DeliveryID FROM deliveries WHERE OrderID = ?',
                                                [orderId],
                                                (e, existing) => {
                                                    if (e) return;
                                                    if (existing.length > 0) {
                                                        // Update existing delivery record
                                                        db.query(
                                                            'UPDATE deliveries SET DriverID = ?, Status = ?, AssignedAt = NOW() WHERE OrderID = ?',
                                                            [driverIdInt, 'assigned', orderId], () => {}
                                                        );
                                                    } else {
                                                        // Insert new delivery record
                                                        db.query(
                                                            'INSERT INTO deliveries (OrderID, DriverID, HubID, Status, AssignedAt) VALUES (?, ?, 1, "assigned", NOW())',
                                                            [orderId, driverIdInt], () => {}
                                                        );
                                                    }
                                                }
                                            );
                                        });
                                    }

                                    res.status(201).json({
                                        message: 'Shipment created successfully',
                                        shipmentId,
                                        totalWeight,
                                        orderCount: orderIds.length,
                                        driverId: driverIdInt,
                                        status: 'in_transit',
                                    });
                                }
                            );
                        }
                    );
                }
            );
        }
    );
});

// ── GET /shipments/:id/orders — get all orders in a specific shipment ──────────
router.get('/:id/orders', (req, res) => {
    const query = `
        SELECT
            o.OrderID,
            o.Status,
            o.CurrentStage,
            o.TotalPrice,
            o.TotalWeight,
            o.DeliveryDate,
            u.Name      AS RetailerName,
            u.ShopName,
            u.Address,
            u.Phone
        FROM shipment_items si
        JOIN orders o ON si.OrderID = o.OrderID
        JOIN users  u ON o.RetailerID = u.UserID
        WHERE si.ShipmentID = ?
        ORDER BY o.OrderID ASC
    `;
    db.query(query, [req.params.id], (err, results) => {
        if (err) return res.status(500).json({ message: 'Database error', error: err.message });
        res.status(200).json({ orders: results });
    });
});

// ── PATCH /shipments/:id/status — update shipment status ──────────────────────
router.patch('/:id/status', (req, res) => {
    const { status } = req.body;
    const validStatuses = ['pending', 'in_transit', 'delivered', 'cancelled'];
    if (!validStatuses.includes(status)) {
        return res.status(400).json({ message: 'Invalid status' });
    }
    db.query(
        'UPDATE shipments SET Status = ? WHERE ShipmentID = ?',
        [status, req.params.id],
        (err) => {
            if (err) return res.status(500).json({ message: 'Database error', error: err.message });
            res.status(200).json({ message: 'Shipment status updated', status });
        }
    );
});

// ── GET /shipments — get all shipments with driver info and order list ─────────
// Used by 3PL manager to view and track shipment status
router.get('/', (req, res) => {
    const query = `
        SELECT
            s.ShipmentID,
            s.Status,
            s.DepartureTime,
            s.TotalWeight,
            s.VehicleType,
            s.CreatedAt,
            u.Name      AS DriverName,
            u.Phone     AS DriverPhone,
            u.CurrentStatus AS DriverStatus,
            COUNT(si.OrderID) AS orderCount
        FROM shipments s
        LEFT JOIN users u          ON s.DriverID = u.UserID
        LEFT JOIN shipment_items si ON s.ShipmentID = si.ShipmentID
        GROUP BY s.ShipmentID
        ORDER BY s.CreatedAt DESC
    `;
    db.query(query, (err, results) => {
        if (err) return res.status(500).json({ message: 'Database error', error: err.message });
        res.status(200).json({ shipments: results });
    });
});

module.exports = router;