const express = require('express');
const router = express.Router();
const db = require('../config/db');
// Safe import — if notifications module fails, orders still work
let logNotification = async () => {}; // default no-op
try {
    const notifModule = require('./notifications');
    if (notifModule && notifModule.logNotification) {
        logNotification = notifModule.logNotification;
    }
} catch (e) {
    console.log('Notifications module not loaded:', e.message);
}

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
// PO-01: Routes through 3PL distributor
// PO-03: Auto-approves normal orders
// PO-05: Flags anomalous orders for Sales Manager
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
            const totalQty = items.reduce((s, i) => s + (parseInt(i.qty_requested) || 0), 0);

            const itemValues = items.map(item => {
                const pData = productMap[item.product_id] || { price: 0, weight: 0 };
                totalPrice += pData.price * item.qty_requested;
                totalWeight += pData.weight * item.qty_requested;
                return [orderID, item.product_id, item.qty_requested, item.qty_requested, pData.price];
            });

            const itemQuery = 'INSERT INTO order_items (OrderID, ProductID, QtyRequested, QtyApproved, UnitPrice) VALUES ?';
            db.query(itemQuery, [itemValues], (err2) => {
                if (err2) return res.status(500).json({ message: 'Error saving order items', error: err2 });

                // PO-05: Check if this order is anomalous vs retailer's historical average
                db.query(
                    `SELECT COALESCE(AVG(o.TotalWeight), 0) AS avgWeight,
                            COALESCE(AVG(
                                (SELECT SUM(oi2.QtyRequested) FROM order_items oi2 WHERE oi2.OrderID = o.OrderID)
                            ), 0) AS avgQty
                     FROM orders o
                     WHERE o.RetailerID = ? AND o.Status NOT IN ('rejected','flagged_for_review')
                     AND o.CreatedAt >= DATE_SUB(NOW(), INTERVAL 90 DAY)`,
                    [retailer_id], (avgErr, avgRows) => {
                        const avgQty = parseFloat(avgRows?.[0]?.avgQty) || 0;
                        const isFlagged = avgQty > 0 && totalQty > avgQty * 3;
                        const newStatus = isFlagged ? 'flagged_for_review' : 'approved';
                        const flagReason = isFlagged
                            ? `Order qty (${totalQty}) is ${Math.round(totalQty/avgQty)}x above retailer avg (${Math.round(avgQty)})`
                            : null;

                        // PO-01: Find assigned 3PL distributor for this retailer
                        db.query(
                            `SELECT DistributorID FROM retailer_distributor_map WHERE RetailerID = ? LIMIT 1`,
                            [retailer_id], (mapErr, mapRows) => {
                                const distributorId = mapRows?.[0]?.DistributorID || null;

                                db.query(
                                    `UPDATE orders SET
                                        Status = ?,
                                        CurrentStage = 2,
                                        TotalPrice = ?,
                                        TotalWeight = ?,
                                        AutoApprovedAt = NOW(),
                                        IsFlagged = ?,
                                        FlagReason = ?,
                                        FlaggedAt = ?,
                                        DriverID = ?
                                     WHERE OrderID = ?`,
                                    [
                                        newStatus, totalPrice, totalWeight,
                                        isFlagged ? 1 : 0,
                                        flagReason,
                                        isFlagged ? new Date() : null,
                                        distributorId,
                                        orderID
                                    ], (updateErr) => {
                                        if (updateErr) console.error('Order update failed', updateErr);

                                        // Notify retailer
                                        if (!isFlagged) {
                                            logNotification(retailer_id, orderID, newStatus);
                                        }

                                        return res.status(201).json({
                                            message: isFlagged
                                                ? 'Order flagged for review due to unusual quantity'
                                                : 'Order placed and auto-approved',
                                            order_id: orderID,
                                            status: newStatus,
                                            isFlagged,
                                            flagReason,
                                            total_price: totalPrice,
                                            total_weight: totalWeight,
                                            distributorId,
                                        });
                                    }
                                );
                            }
                        );
                    }
                );
            });
        });
    });
}

// GET /orders - warehouse manager sees all orders
// LoyaltyRank calculated from total past orders: Gold>=10, Silver>=5, Bronze<5
router.get('/', (req, res) => {
    const statusFilter = req.query.status;
    let query = `
        SELECT o.OrderID, o.Status, o.IsUrgent, o.DeliveryDate,
               COALESCE(o.RejectionReason, o.rejection_reason) AS RejectionReason,
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
               COALESCE(o.RejectionReason, o.rejection_reason) AS RejectionReason,
               o.CreatedAt, o.TotalPrice,
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

    console.log('[BATCH] Updating orders:', orderIds, 'to stage:', stageNum, 'status:', newStatus);
    db.query(
        `UPDATE orders SET CurrentStage = ?, Status = ? WHERE OrderID IN (${placeholders})`,
        [stageNum, newStatus, ...orderIds], (err, result) => {
            if (err) {
                console.error('[BATCH] UPDATE failed:', err.message);
                return res.status(500).json({ message: 'Batch override failed', error: err.message });
            }

            console.log('[BATCH] Updated rows:', result.affectedRows);

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
        const rejectQuery = 'UPDATE orders SET Status = ?, RejectionReason = ?, rejection_reason = ?, CurrentStage = 2 WHERE OrderID = ?';
        db.query(rejectQuery, [status, rejection_reason, rejection_reason, orderID], (err) => {
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

// ─────────────────────────────────────────────────────────────────────────────
// US-26: GET /orders/retailer/:id/heavy-check
// ─────────────────────────────────────────────────────────────────────────────
router.get('/retailer/:id/heavy-check', (req, res) => {
    const retailerId = req.params.id;
    const q = (sql, params) => new Promise((resolve, reject) =>
        db.query(sql, params, (err, rows) => err ? reject(err) : resolve(rows)));

    q(`SELECT COUNT(*) as cnt FROM orders WHERE RetailerID = ? AND Status != 'rejected'`, [retailerId])
    .then(([countRow]) => {
        if (countRow.cnt < 5) return res.json({ isHeavy: false, reason: 'insufficient_orders' });
        return Promise.all([
            q(`SELECT COUNT(*) as cnt FROM orders WHERE RetailerID = ? AND (TotalWeight >= 50 OR TotalPrice >= 10000)`, [retailerId]),
            q(`SELECT COUNT(DISTINCT oi.ProductID) as cnt FROM order_items oi JOIN orders o ON oi.OrderID = o.OrderID WHERE o.RetailerID = ?`, [retailerId]),
        ]).then(([bulkRow, productRow]) => {
            const isHeavy = bulkRow[0].cnt >= 1 && productRow[0].cnt >= 3;
            res.json({ isHeavy, orderCount: countRow.cnt });
        });
    }).catch(err => res.json({ isHeavy: false, error: err.message }));
});

// ─────────────────────────────────────────────────────────────────────────────
// US-26: GET /orders/retailer/:id/templates
// ─────────────────────────────────────────────────────────────────────────────
router.get('/retailer/:id/templates', (req, res) => {
    const retailerId = req.params.id;
    db.query(
        `SELECT o.OrderID, o.TotalPrice, o.TotalWeight, o.CreatedAt,
                oi.ProductID, oi.QtyRequested,
                p.ProductName, p.SKU, p.Unit, p.Price as CurrentPrice, p.Weight
         FROM orders o
         JOIN order_items oi ON o.OrderID = oi.OrderID
         JOIN products p ON oi.ProductID = p.ProductID
         WHERE o.RetailerID = ? AND o.Status NOT IN ('rejected','pending')
         ORDER BY o.CreatedAt DESC LIMIT 100`,
        [retailerId], (err, orders) => {
            if (err) return res.status(500).json({ message: 'Failed', error: err.message });
            if (!orders || orders.length < 3) {
                return res.json({ templates: [], reason: 'insufficient_history' });
            }

            // Group by order
            const orderMap = {};
            orders.forEach(row => {
                if (!orderMap[row.OrderID]) {
                    orderMap[row.OrderID] = {
                        orderId: row.OrderID,
                        totalPrice: parseFloat(row.TotalPrice) || 0,
                        totalWeight: parseFloat(row.TotalWeight) || 0,
                        date: row.CreatedAt,
                        items: []
                    };
                }
                orderMap[row.OrderID].items.push({
                    productId: row.ProductID,
                    productName: row.ProductName,
                    sku: row.SKU,
                    unit: row.Unit,
                    qty: row.QtyRequested,
                    currentPrice: parseFloat(row.CurrentPrice) || 0,
                });
            });

            const orderList = Object.values(orderMap);
            if (orderList.length < 2) return res.json({ templates: [], reason: 'insufficient_history' });

            const byPrice = [...orderList].sort((a, b) => b.totalPrice - a.totalPrice);
            const midIdx = Math.floor(byPrice.length / 2);
            const medianPrice = byPrice[midIdx]?.totalPrice || 0;
            const byDate = [...orderList].sort((a, b) => new Date(b.date) - new Date(a.date));

            const calcTotal = items => items.reduce((s, i) => s + (i.qty * i.currentPrice), 0);

            const templates = [
                {
                    id: 'large_bulk',
                    name: 'Large Bulk Order',
                    description: 'Based on your highest value order',
                    icon: 'inventory_2',
                    items: byPrice[0].items,
                    estimatedTotal: calcTotal(byPrice[0].items),
                },
                {
                    id: 'medium_weekly',
                    name: 'Medium Weekly Order',
                    description: 'Based on your typical weekly order',
                    icon: 'calendar_today',
                    items: byPrice[midIdx].items,
                    estimatedTotal: calcTotal(byPrice[midIdx].items),
                },
                {
                    id: 'emergency_restock',
                    name: 'Emergency Restock',
                    description: 'Essential items at reduced quantities',
                    icon: 'bolt',
                    items: (byDate.find(o => o.totalPrice < medianPrice) || byDate[0]).items.map(i => ({
                        ...i, qty: Math.max(1, Math.ceil(i.qty * 0.5))
                    })),
                    estimatedTotal: calcTotal((byDate.find(o => o.totalPrice < medianPrice) || byDate[0]).items.map(i => ({
                        ...i, qty: Math.max(1, Math.ceil(i.qty * 0.5))
                    }))),
                },
            ].filter(t => t.items && t.items.length > 0);

            res.json({ templates });
        }
    );
});


// ─────────────────────────────────────────────────────────────────────────────
// PO-05: Sales Manager flagged orders queue
// GET /orders/flagged — all orders flagged for review
// ─────────────────────────────────────────────────────────────────────────────
router.get('/flagged', (req, res) => {
    db.query(
        `SELECT o.*, u.Name as RetailerName, u.ShopName, u.District
         FROM orders o
         JOIN users u ON o.RetailerID = u.UserID
         WHERE o.IsFlagged = 1 AND o.Status = 'flagged_for_review'
         ORDER BY o.FlaggedAt DESC`,
        [], (err, rows) => {
            if (err) return res.status(500).json({ message: 'DB error', error: err.message });
            res.json({ orders: rows || [] });
        }
    );
});

// PUT /orders/:id/release — Sales Manager releases flagged order
router.put('/:id/release', (req, res) => {
    const { releasedBy } = req.body;
    db.query(
        `UPDATE orders SET Status = 'approved', CurrentStage = 2,
         IsFlagged = 0, ReleasedAt = NOW(), ReleasedBy = ?
         WHERE OrderID = ? AND Status = 'flagged_for_review'`,
        [releasedBy || null, req.params.id], (err, result) => {
            if (err) return res.status(500).json({ message: 'DB error', error: err.message });
            if (result.affectedRows === 0) return res.status(404).json({ message: 'Order not found or not flagged' });

            // Notify retailer
            db.query('SELECT RetailerID FROM orders WHERE OrderID = ?', [req.params.id], (e, r) => {
                if (!e && r?.[0]) logNotification(r[0].RetailerID, req.params.id, 'approved');
            });
            res.json({ message: 'Order released and approved' });
        }
    );
});

// PUT /orders/:id/hold — Sales Manager holds/rejects flagged order
router.put('/:id/hold', (req, res) => {
    const { reason } = req.body;
    db.query(
        `UPDATE orders SET Status = 'rejected', CurrentStage = 2,
         RejectionReason = ?, rejection_reason = ?
         WHERE OrderID = ? AND Status = 'flagged_for_review'`,
        [reason || 'Held by Sales Manager', reason || 'Held by Sales Manager', req.params.id],
        (err, result) => {
            if (err) return res.status(500).json({ message: 'DB error', error: err.message });
            res.json({ message: 'Order held' });
        }
    );
});

// ─────────────────────────────────────────────────────────────────────────────
// PO-01: 3PL Distributor order queue
// GET /orders/distributor/:distributorId — orders assigned to this 3PL
// ─────────────────────────────────────────────────────────────────────────────
router.get('/distributor/:distributorId', (req, res) => {
    db.query(
        `SELECT o.*, u.Name as RetailerName, u.ShopName, u.Address, u.District
         FROM orders o
         JOIN users u ON o.RetailerID = u.UserID
         WHERE o.DriverID = ? AND o.Status NOT IN ('rejected')
         ORDER BY o.IsUrgent DESC, o.CreatedAt DESC`,
        [req.params.distributorId], (err, rows) => {
            if (err) return res.status(500).json({ message: 'DB error', error: err.message });
            res.json({ orders: rows || [] });
        }
    );
});

// ─────────────────────────────────────────────────────────────────────────────
// PO-03: Auto stage advance — triggered by backend events
// PUT /orders/:id/auto-advance — called by system when an event happens
// ─────────────────────────────────────────────────────────────────────────────
router.put('/:id/auto-advance', (req, res) => {
    const { event } = req.body;
    // event: 'packing_started' | 'shipped' | 'out_for_delivery' | 'delivered'
    const eventStageMap = {
        'packing_started':  { status: 'packing',          stage: 3, col: 'PackingStartedAt' },
        'shipped':          { status: 'in_3pl_transit',   stage: 4, col: 'ShippedAt' },
        'out_for_delivery': { status: 'out_for_delivery', stage: 6, col: null },
        'delivered':        { status: 'delivered',        stage: 7, col: 'DeliveredAt' },
    };
    const mapping = eventStageMap[event];
    if (!mapping) return res.status(400).json({ message: 'Invalid event' });

    const colUpdate = mapping.col ? `, ${mapping.col} = NOW()` : '';
    db.query(
        `UPDATE orders SET Status = ?, CurrentStage = ? ${colUpdate} WHERE OrderID = ?`,
        [mapping.status, mapping.stage, req.params.id], (err, result) => {
            if (err) return res.status(500).json({ message: 'DB error', error: err.message });

            // Auto-notify retailer
            db.query('SELECT RetailerID FROM orders WHERE OrderID = ?', [req.params.id], (e, r) => {
                if (!e && r?.[0]) logNotification(r[0].RetailerID, req.params.id, mapping.status);
            });
            res.json({ message: 'Stage auto-advanced', status: mapping.status, stage: mapping.stage });
        }
    );
});

// ─────────────────────────────────────────────────────────────────────────────
// PO-02: Supply disruptions
// GET /orders/disruptions — active disruptions for retailer region
// ─────────────────────────────────────────────────────────────────────────────
router.get('/disruptions', (req, res) => {
    const { regionId } = req.query;
    db.query(
        `CREATE TABLE IF NOT EXISTS supply_disruptions (
            DisruptionID INT AUTO_INCREMENT PRIMARY KEY,
            Title VARCHAR(100) NOT NULL,
            Message TEXT NOT NULL,
            DisruptionType VARCHAR(20) DEFAULT 'other',
            RegionID INT NULL,
            Severity VARCHAR(10) DEFAULT 'medium',
            IsActive TINYINT DEFAULT 1,
            CreatedBy INT,
            CreatedAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            ExpiresAt DATETIME NULL
        )`, [], () => {}
    );
    db.query(
        `SELECT * FROM supply_disruptions
         WHERE IsActive = 1
         AND (ExpiresAt IS NULL OR ExpiresAt > NOW())
         AND (RegionID IS NULL OR RegionID = ?)
         ORDER BY CreatedAt DESC`,
        [regionId || null], (err, rows) => {
            if (err) return res.json({ disruptions: [] });
            res.json({ disruptions: rows || [] });
        }
    );
});

// POST /orders/disruptions — WM/Admin creates disruption alert
router.post('/disruptions', (req, res) => {
    const { title, message, disruptionType, regionId, severity, expiresAt, createdBy } = req.body;
    if (!title || !message) return res.status(400).json({ message: 'Title and message required' });
    db.query(
        `INSERT INTO supply_disruptions (Title, Message, DisruptionType, RegionID, Severity, ExpiresAt, CreatedBy)
         VALUES (?, ?, ?, ?, ?, ?, ?)`,
        [title, message, disruptionType || 'other', regionId || null,
         severity || 'medium', expiresAt || null, createdBy || null],
        (err, result) => {
            if (err) return res.status(500).json({ message: 'DB error', error: err.message });
            res.json({ message: 'Disruption alert created', id: result.insertId });
        }
    );
});

// DELETE /orders/disruptions/:id — deactivate disruption
router.delete('/disruptions/:id', (req, res) => {
    db.query('UPDATE supply_disruptions SET IsActive = 0 WHERE DisruptionID = ?',
        [req.params.id], (err) => {
            if (err) return res.status(500).json({ message: 'DB error' });
            res.json({ message: 'Disruption deactivated' });
        }
    );
});


module.exports = router;