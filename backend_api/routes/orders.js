const express = require('express');
const router = express.Router();
const db = require('../config/db');
const { logNotification } = require('./notifications');

// POST /orders - retailer places an order
// US-10: checkPriorityStatus() — only priority retailers can place urgent orders
router.post('/', (req, res) => {
    const { retailer_id, delivery_date, is_urgent, items } = req.body;

    if (!retailer_id || !delivery_date || !items || items.length === 0) {
        return res.status(400).json({ message: 'Missing required fields' });
    }

    // US-10: If urgent order requested, check priority status first
    if (is_urgent) {
        db.query('SELECT PriorityStatus FROM users WHERE UserID = ?',
            [retailer_id], (err, results) => {
                if (err) return res.status(500).json({ message: 'Database error', error: err });
                if (results.length === 0) return res.status(404).json({ message: 'Retailer not found' });
                if (results[0].PriorityStatus !== 1) {
                    return res.status(403).json({
                        message: 'Urgent orders are only available to priority retailers. Contact your Nestlé representative to upgrade your account.',
                        errorCode: 'NOT_PRIORITY_RETAILER'
                    });
                }
                // Priority check passed — place urgent order
                _placeOrder(req, res, retailer_id, delivery_date, is_urgent, items);
            });
        return; // wait for priority check callback
    }

    // Standard order — no priority check needed
    _placeOrder(req, res, retailer_id, delivery_date, is_urgent, items);
});

// Internal helper to place an order after priority check
function _placeOrder(req, res, retailer_id, delivery_date, is_urgent, items) {

    const orderQuery = 'INSERT INTO orders (RetailerID, Status, IsUrgent, DeliveryDate) VALUES (?, ?, ?, ?)';
    db.query(orderQuery, [retailer_id, 'pending', is_urgent ? 1 : 0, delivery_date], (err, result) => {
        if (err) return res.status(500).json({ message: 'Database error', error: err });

        const orderID = result.insertId;
        const productIds = items.map(item => item.product_id);

        const pricingQuery = 'SELECT ProductID, Price, Weight FROM products WHERE ProductID IN (?)';
        db.query(pricingQuery, [productIds], (priceErr, productResults) => {
            if (priceErr) return res.status(500).json({ message: 'Error fetching product data', error: priceErr });

            const productMap = {};
            productResults.forEach(p => {
                productMap[p.ProductID] = { price: p.Price, weight: p.Weight };
            });

            let totalPrice = 0;
            let totalWeight = 0;

            const itemValues = items.map(item => {
                const pData = productMap[item.product_id] || { price: 0, weight: 0 };
                totalPrice += pData.price * item.qty_requested;
                totalWeight += pData.weight * item.qty_requested;
                return [orderID, item.product_id, item.qty_requested, 0, pData.price];
            });

            const itemQuery = 'INSERT INTO order_items (OrderID, ProductID, QtyRequested, QtyApproved, UnitPrice) VALUES ?';
            db.query(itemQuery, [itemValues], (err2) => {
                if (err2) return res.status(500).json({ message: 'Error saving order items', error: err2 });

                db.query('UPDATE orders SET TotalPrice = ?, TotalWeight = ? WHERE OrderID = ?',
                    [totalPrice, totalWeight, orderID], (updateErr) => {
                        if (updateErr) console.error('Totals update failed', updateErr);
                        return res.status(201).json({
                            message: 'Order placed successfully',
                            order_id: orderID,
                            total_price: totalPrice,
                            total_weight: totalWeight
                        });
                    });
            });
        });
    });
}

// GET /orders - warehouse manager sees all orders
// LoyaltyRank calculated from total past orders: Gold>=10, Silver>=5, Bronze<5
router.get('/', (req, res) => {
    const statusFilter = req.query.status;
    let query = `
        SELECT o.OrderID, o.Status, o.IsUrgent, o.DeliveryDate, o.RejectionReason,
               o.CreatedAt, o.CurrentStage, o.TotalPrice, o.TotalWeight,
               u.Name as RetailerName, u.ShopName, u.District, u.UserID as RetailerID,
               COALESCE(lr.approvedCount, 0) as approvedCount,
               CASE
                   WHEN COALESCE(lr.approvedCount, 0) >= 10 THEN 'Gold'
                   WHEN COALESCE(lr.approvedCount, 0) >= 5  THEN 'Silver'
                   ELSE 'Bronze'
               END as loyaltyRank
        FROM orders o
        JOIN users u ON o.RetailerID = u.UserID
        LEFT JOIN (
            SELECT RetailerID, COUNT(*) as approvedCount
            FROM orders
            WHERE Status IN ('approved', 'partially_approved', 'delivered')
            GROUP BY RetailerID
        ) lr ON lr.RetailerID = o.RetailerID
    `;
    const params = [];
    if (statusFilter) {
        query += ' WHERE o.Status = ?';
        params.push(statusFilter);
    }
    query += ' ORDER BY o.IsUrgent DESC, approvedCount DESC, o.CreatedAt DESC';

    db.query(query, params, (err, results) => {
        if (err) return res.status(500).json({ message: 'Database error', error: err });
        // Calculate loyalty rank from order count
        const orders = results.map(o => ({
            ...o,
            loyaltyRank: o.totalOrders >= 10 ? 'Gold'
                       : o.totalOrders >= 5  ? 'Silver'
                       : 'Bronze'
        }));
        res.status(200).json({ orders });
    });
});

// GET /orders/report/daily - US-15: requestReport() + generateSummary()
// Fetches both order AND delivery data then generates summary

router.get('/report/daily', (req, res) => {
    const today = new Date().toISOString().split('T')[0];

    // requestReport() — fetch order AND delivery data
    const summaryQuery = `
        SELECT
            COUNT(*) AS totalOrders,
            SUM(CASE WHEN Status IN ('approved','packing','in_3pl_transit',
                'ready_to_ship','out_for_delivery','delivered') THEN 1 ELSE 0 END) AS approvedOrders,
            SUM(CASE WHEN Status = 'rejected' THEN 1 ELSE 0 END) AS rejectedOrders,
            SUM(CASE WHEN Status = 'pending' THEN 1 ELSE 0 END) AS pendingOrders,
            SUM(CASE WHEN Status = 'delivered' THEN 1 ELSE 0 END) AS deliveredOrders,
            SUM(IFNULL(TotalPrice, 0)) AS totalValue
        FROM orders
        WHERE DATE(CreatedAt) = ?
    `;

    db.query(summaryQuery, [today], (err, summaryResults) => {
        if (err) return res.status(500).json({ message: 'Database error', error: err });

        const byRetailerQuery = `
            SELECT u.Name AS retailerName, COUNT(*) AS orderCount
            FROM orders o
            JOIN users u ON o.RetailerID = u.UserID
            WHERE DATE(o.CreatedAt) = ?
            GROUP BY o.RetailerID, u.Name
            ORDER BY orderCount DESC
        `;

        db.query(byRetailerQuery, [today], (err2, retailerResults) => {
            if (err2) return res.status(500).json({ message: 'Database error', error: err2 });

            const lowStockQuery = `
                SELECT ProductName AS name, StockLevel AS remaining
                FROM products
                WHERE StockLevel < 10
                ORDER BY StockLevel ASC
            `;

            db.query(lowStockQuery, (err3, lowStockResults) => {
                if (err3) return res.status(500).json({ message: 'Database error', error: err3 });

                // generateSummary() — calculate final report data
                const s = summaryResults[0];
                res.status(200).json({
                    totalOrders: parseInt(s.totalOrders) || 0,
                    approvedOrders: parseInt(s.approvedOrders) || 0,
                    rejectedOrders: parseInt(s.rejectedOrders) || 0,
                    pendingOrders: parseInt(s.pendingOrders) || 0,
                    deliveredOrders: parseInt(s.deliveredOrders) || 0,
                    totalValue: parseFloat(s.totalValue) || 0,
                    ordersByRetailer: retailerResults,
                    lowStockItems: lowStockResults,
                    generatedAt: new Date().toLocaleString('en-GB'),
                });
            });
        });
    });
});

// GET /orders/driver/:id - delivery driver sees their assigned orders via deliveries table
router.get('/driver/:id', (req, res) => {
    const driverID = req.params.id;
    const query = `
        SELECT o.OrderID, o.Status, o.IsUrgent, o.DeliveryDate, o.CurrentStage,
               o.TotalPrice, o.TotalWeight,
               u.Name AS RetailerName, u.ShopName, u.Address, u.Phone,
               d.DeliveryID, d.Status AS DeliveryStatus, d.AssignedAt, d.DeliveredAt
        FROM deliveries d
        JOIN orders o ON d.OrderID = o.OrderID
        JOIN users u ON o.RetailerID = u.UserID
        WHERE d.DriverID = ? AND d.Status NOT IN ('delivered', 'failed')
        ORDER BY d.AssignedAt ASC, o.OrderID ASC
    `;
    db.query(query, [driverID], (err, results) => {
        if (err) return res.status(500).json({ message: 'Database error', error: err });
        res.status(200).json({ orders: results });
    });
});

// GET /orders/retailer/:id - retailer sees ONLY their own orders
router.get('/retailer/:id', (req, res) => {
    const retailerID = req.params.id;
    // Validate retailerID to prevent empty/undefined fetching all orders
    if (!retailerID || retailerID === 'undefined' || retailerID === '0') {
        return res.status(400).json({ message: 'Invalid retailer ID' });
    }
    const query = `
        SELECT o.OrderID, o.RetailerID, o.Status, o.IsUrgent, o.DeliveryDate,
               o.RejectionReason, o.CreatedAt, o.TotalPrice,
               o.TotalWeight, o.CurrentStage
        FROM orders o
        WHERE o.RetailerID = ?
        ORDER BY o.CreatedAt DESC
    `;
    db.query(query, [retailerID], (err, results) => {
        if (err) return res.status(500).json({ message: 'Database error', error: err });
        res.status(200).json({ orders: results });
    });
});

// GET /orders/:id/items - get items for a specific order
router.get('/:id/items', (req, res) => {
    const orderID = req.params.id;
    const query = `
        SELECT oi.ItemID, oi.QtyRequested, oi.QtyApproved,
               p.ProductName, p.Unit, p.Price,
               o.Status, o.RejectionReason
        FROM order_items oi
        JOIN products p ON oi.ProductID = p.ProductID
        JOIN orders o ON oi.OrderID = o.OrderID
        WHERE oi.OrderID = ?
    `;
    db.query(query, [orderID], (err, results) => {
        if (err) return res.status(500).json({ message: 'Database error', error: err });
        res.status(200).json({ items: results });
    });
});

// PUT /orders/:id - approve or reject order
router.put('/:id', (req, res) => {
    const orderID = req.params.id;
    const { status, rejection_reason, items } = req.body;

    if (!status) return res.status(400).json({ message: 'Status is required' });

    // CASE 1: FULL APPROVAL
    if (status === 'approved') {
        db.beginTransaction((err) => {
            if (err) return res.status(500).json(err);

            const approveQuery = 'UPDATE orders SET Status = ?, CurrentStage = 2 WHERE OrderID = ?';
            db.query(approveQuery, [status, orderID], (err1) => {
                if (err1) return db.rollback(() => res.status(500).json(err1));

                const syncItems = 'UPDATE order_items SET QtyApproved = QtyRequested WHERE OrderID = ?';
                db.query(syncItems, [orderID], (err2) => {
                    if (err2) return db.rollback(() => res.status(500).json(err2));

                    const deductStockQuery = `
                        UPDATE products p
                        JOIN order_items oi ON p.ProductID = oi.ProductID
                        SET p.StockLevel = p.StockLevel - oi.QtyRequested
                        WHERE oi.OrderID = ?
                    `;
                    db.query(deductStockQuery, [orderID], (err3) => {
                        if (err3) return db.rollback(() => res.status(500).json(err3));

                        db.commit((err4) => {
                            if (err4) return db.rollback(() => res.status(500).json(err4));
                            res.status(200).json({ message: 'Order fully approved and stock deducted!' });
                        });
                    });
                });
            });
        });

    // CASE 3: REJECTION
    } else if (status === 'rejected') {
        if (!rejection_reason) return res.status(400).json({ message: 'Rejection reason is required' });
        const rejectQuery = 'UPDATE orders SET Status = ?, RejectionReason = ?, CurrentStage = 2 WHERE OrderID = ?';
        db.query(rejectQuery, [status, rejection_reason, orderID], (err) => {
            if (err) return res.status(500).json({ message: 'Database error', error: err });
            res.status(200).json({ message: 'Order rejected successfully' });
        });
    } else {
        res.status(400).json({ message: 'Invalid status provided' });
    }
});

// POST /orders/:id/next-stage - advance order to next stage
// Also handles driver assignment when driver_id is provided in body
router.post('/:id/next-stage', (req, res) => {
    const orderID = req.params.id;
    const { vehicle_type } = req.body || {};
    const driver_id = req.body && req.body.driver_id ? parseInt(req.body.driver_id) : null;

    if (!orderID || orderID === 'undefined') {
        return res.status(400).json({ message: 'Invalid Order ID' });
    }

    db.query('SELECT CurrentStage, Status FROM orders WHERE OrderID = ?', [orderID], (err, results) => {
        if (err) return res.status(500).json({ message: 'DB Fetch Error', error: err });
        if (results.length === 0) return res.status(404).json({ message: 'Order not found' });

        let nextStage = (results[0].CurrentStage || 2) + 1;
        let newStatus = 'processing';

        if (nextStage >= 7) {
            nextStage = 7;
            newStatus = 'delivered';
        }

        // If driver_id provided — insert into deliveries table and advance to stage 4
        if (driver_id) {
            nextStage = 4;
            newStatus = 'assigned';

            // Update order stage and status
            db.query('UPDATE orders SET CurrentStage = ?, Status = ? WHERE OrderID = ?',
                [nextStage, newStatus, orderID], (updateErr) => {
                    if (updateErr) return res.status(500).json({ message: 'Order update failed', error: updateErr });

                    // Check if delivery record already exists for this order
                    db.query('SELECT DeliveryID FROM deliveries WHERE OrderID = ?', [orderID], (err2, existing) => {
                        if (err2) return res.status(500).json({ message: 'DB error', error: err2 });

                        if (existing.length > 0) {
                            // Update existing delivery record
                            db.query('UPDATE deliveries SET DriverID = ?, Status = ?, AssignedAt = NOW() WHERE OrderID = ?',
                                [driver_id, 'assigned', orderID], (err3) => {
                                    if (err3) return res.status(500).json({ message: 'Delivery update failed', error: err3 });
                                    db.query('UPDATE users SET CurrentStatus = "BUSY" WHERE UserID = ? AND Role = "driver"', [driver_id], () => {});
                                    res.status(200).json({ message: 'Driver Assigned', newStage: nextStage, newStatus });
                                });
                        } else {
                            // Insert new delivery record (HubID defaults to 1)
                            db.query('INSERT INTO deliveries (OrderID, DriverID, HubID, Status, AssignedAt) VALUES (?, ?, 1, "assigned", NOW())',
                                [orderID, driver_id], (err3) => {
                                    if (err3) return res.status(500).json({ message: 'Delivery insert failed', error: err3.message || err3 });
                                    db.query('UPDATE users SET CurrentStatus = "BUSY" WHERE UserID = ? AND Role = "driver"', [driver_id], () => {});
                                    res.status(200).json({ message: 'Driver Assigned', newStage: nextStage, newStatus });
                                });
                        }
                    });
                });
        } else {
            // US-14: New 7-stage pipeline status mapping
            // Stage 1: pending, Stage 2: approved, Stage 3: packing,
            // Stage 4: in_3pl_transit, Stage 5: ready_to_ship,
            // Stage 6: out_for_delivery, Stage 7: delivered
            const stageStatusMap = {
                1: 'pending',
                2: 'approved',
                3: 'packing',
                4: 'in_3pl_transit',
                5: 'ready_to_ship',
                6: 'out_for_delivery',
                7: 'delivered'
            };
            newStatus = stageStatusMap[nextStage] || 'processing';

            const updateSql = 'UPDATE orders SET CurrentStage = ?, Status = ? WHERE OrderID = ?';
            db.query(updateSql, [nextStage, newStatus, orderID], (updateErr) => {
                if (updateErr) return res.status(500).json({ message: 'Update failed', error: updateErr });

                // US-16: Auto-update driver status on delivery completion
                if (newStatus === 'delivered') {
                    db.query('UPDATE deliveries SET Status = "delivered", DeliveredAt = NOW() WHERE OrderID = ?',
                        [orderID], () => {});
                    // Auto-set driver back to AVAILABLE (endDelivery)
                    db.query(`UPDATE users u
                        JOIN deliveries d ON d.DriverID = u.UserID
                        SET u.CurrentStatus = 'AVAILABLE'
                        WHERE d.OrderID = ? AND u.Role = 'driver'`, [orderID], () => {});
                }
                // US-16: Auto-set driver to BUSY on out_for_delivery (startDelivery)
                if (newStatus === 'out_for_delivery') {
                    db.query(`UPDATE users u
                        JOIN deliveries d ON d.DriverID = u.UserID
                        SET u.CurrentStatus = 'BUSY'
                        WHERE d.OrderID = ? AND u.Role = 'driver'`, [orderID], () => {});
                    db.query('UPDATE deliveries SET Status = "in_transit" WHERE OrderID = ?',
                        [orderID], () => {});
                }

                // US-20: Notify retailer on every stage change
                db.query('SELECT RetailerID FROM orders WHERE OrderID = ?', [orderID], (_, retRows) => {
                    if (retRows && retRows.length > 0) {
                        logNotification(retRows[0].RetailerID, orderID, newStatus);
                    }
                });

                res.status(200).json({ message: 'Stage Advanced', newStage: nextStage, newStatus });
            });
        }
    });
});

// ─────────────────────────────────────────────────────────────────────────────
// US-17: PUT /orders/:id/confirm-delivery
// Driver submits digital confirmation: signature + photo + GPS
// ─────────────────────────────────────────────────────────────────────────────
router.put('/:id/confirm-delivery', (req, res) => {
    const { signature, photo, lat, lng } = req.body;
    const orderId = req.params.id;

    if (!signature && !photo) {
        return res.status(400).json({ message: 'Signature or photo proof required' });
    }

    // Ensure deliveries columns exist (run once — safe to retry)
    const alterSql = `
        ALTER TABLE deliveries
        ADD COLUMN IF NOT EXISTS DeliveryPhoto LONGTEXT,
        ADD COLUMN IF NOT EXISTS DeliverySignature LONGTEXT,
        ADD COLUMN IF NOT EXISTS DeliveryLat DECIMAL(10,8),
        ADD COLUMN IF NOT EXISTS DeliveryLng DECIMAL(11,8),
        ADD COLUMN IF NOT EXISTS DeliveryTimestamp DATETIME
    `;
    db.query(alterSql, [], () => {}); // fire and forget — columns may already exist

    // Save confirmation evidence + mark delivered
    const sql = `
        UPDATE deliveries
        SET DeliveryPhoto = ?, DeliverySignature = ?,
            DeliveryLat = ?, DeliveryLng = ?,
            DeliveryTimestamp = NOW(),
            Status = 'delivered', DeliveredAt = NOW()
        WHERE OrderID = ?
    `;
    db.query(sql, [photo || null, signature || null, lat || null, lng || null, orderId], (err) => {
        if (err) return res.status(500).json({ message: 'Failed to save confirmation', error: err.message });

        // Advance order to stage 7 — delivered
        db.query(
            "UPDATE orders SET CurrentStage = 7, Status = 'delivered' WHERE OrderID = ?",
            [orderId], (err2) => {
                if (err2) return res.status(500).json({ message: 'Order update failed', error: err2.message });

                // Auto-release driver
                db.query(`UPDATE users u JOIN deliveries d ON d.DriverID = u.UserID
                          SET u.CurrentStatus = 'AVAILABLE' WHERE d.OrderID = ? AND u.Role = 'driver'`,
                    [orderId], () => {});

                // Notify retailer
                db.query('SELECT RetailerID FROM orders WHERE OrderID = ?', [orderId], (_, rows) => {
                    if (rows && rows.length > 0) {
                        logNotification(rows[0].RetailerID, orderId, 'delivered');
                    }
                });

                res.json({ message: 'Delivery confirmed', orderId });
            });
    });
});

// ─────────────────────────────────────────────────────────────────────────────
// US-18: PUT /orders/:id/stage-override
// Warehouse Manager manually overrides order stage
// Body: { stage: 1-7 }
// ─────────────────────────────────────────────────────────────────────────────
router.put('/:id/stage-override', (req, res) => {
    const { stage } = req.body;
    const orderId = req.params.id;

    const stageStatusMap = {
        1: 'pending', 2: 'approved', 3: 'packing',
        4: 'in_3pl_transit', 5: 'ready_to_ship',
        6: 'out_for_delivery', 7: 'delivered',
    };

    const stageNum = parseInt(stage);
    if (!stageNum || stageNum < 1 || stageNum > 7) {
        return res.status(400).json({ message: 'Stage must be between 1 and 7' });
    }

    const newStatus = stageStatusMap[stageNum];

    // First check order exists and is not rejected
    db.query('SELECT CurrentStage, Status FROM orders WHERE OrderID = ?', [orderId], (err, rows) => {
        if (err || !rows || rows.length === 0) {
            return res.status(404).json({ message: 'Order not found' });
        }
        const order = rows[0];

        // Cannot override rejected orders
        if (order.Status === 'rejected') {
            return res.status(400).json({ message: 'Cannot override a rejected order' });
        }

        db.query(
            'UPDATE orders SET CurrentStage = ?, Status = ? WHERE OrderID = ?',
            [stageNum, newStatus, orderId], (err) => {
                if (err) return res.status(500).json({ message: 'Override failed', error: err.message });

            // Notify retailer of override
            db.query('SELECT RetailerID FROM orders WHERE OrderID = ?', [orderId], (_, rows) => {
                if (rows && rows.length > 0) {
                    logNotification(rows[0].RetailerID, orderId, newStatus);
                }
            });

                res.json({ message: 'Stage overridden', orderId, newStage: stageNum, newStatus });
            });
    });
});

// ─────────────────────────────────────────────────────────────────────────────
// US-18: PUT /orders/batch-override
// Warehouse Manager updates multiple orders to same stage at once
// Body: { orderIds: [1,2,3], stage: 3 }
// ─────────────────────────────────────────────────────────────────────────────
router.put('/batch-override', (req, res) => {
    const { orderIds, stage } = req.body;

    if (!orderIds || !Array.isArray(orderIds) || orderIds.length === 0) {
        return res.status(400).json({ message: 'orderIds array required' });
    }

    const stageStatusMap = {
        1: 'pending', 2: 'approved', 3: 'packing',
        4: 'in_3pl_transit', 5: 'ready_to_ship',
        6: 'out_for_delivery', 7: 'delivered',
    };

    const stageNum = parseInt(stage);
    if (!stageNum || stageNum < 1 || stageNum > 7) {
        return res.status(400).json({ message: 'Stage must be between 1 and 7' });
    }

    const newStatus = stageStatusMap[stageNum];
    const placeholders = orderIds.map(() => '?').join(',');

    db.query(
        `UPDATE orders SET CurrentStage = ?, Status = ? WHERE OrderID IN (${placeholders})`,
        [stageNum, newStatus, ...orderIds], (err, result) => {
            if (err) return res.status(500).json({ message: 'Batch override failed', error: err.message });

            // Notify each retailer
            db.query(
                `SELECT OrderID, RetailerID FROM orders WHERE OrderID IN (${placeholders})`,
                orderIds, (_, rows) => {
                    if (rows) {
                        rows.forEach(r => logNotification(r.RetailerID, r.OrderID, newStatus));
                    }
                });

            res.json({
                message: 'Batch override complete',
                updated: result.affectedRows,
                stage: stageNum,
                status: newStatus,
            });
        });
});

module.exports = router;