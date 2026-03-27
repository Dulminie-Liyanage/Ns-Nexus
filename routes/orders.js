const express = require('express');
const router = express.Router();
const db = require('../config/db');

// POST /orders - retailer places an order
router.post('/', (req, res) => {
    const { retailer_id, delivery_date, is_urgent, items } = req.body;

    if (!retailer_id || !delivery_date || !items || items.length === 0) {
        return res.status(400).json({ message: 'Missing required fields' });
    }

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
                    if (updateErr) console.error("Totals update failed", updateErr);
                    
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
});

// GET /orders - warehouse manager sees all orders
router.get('/', (req, res) => {
    const query = `
        SELECT o.OrderID, o.Status, o.IsUrgent, o.DeliveryDate, o.RejectionReason, o.CreatedAt, o.CurrentStage,
               u.Name as RetailerName, u.ShopName, u.District
        FROM orders o
        JOIN users u ON o.RetailerID = u.UserID
        ORDER BY o.CreatedAt DESC
    `;
    db.query(query, (err, results) => {
        if (err) return res.status(500).json({ message: 'Database error', error: err });
        res.status(200).json({ message: 'Orders fetched successfully', orders: results });
    });
});

// GET /orders/retailer/:id - retailer sees their own orders
router.get('/retailer/:id', (req, res) => {
    const retailerID = req.params.id;
    const query = `
        SELECT o.OrderID, o.Status, o.IsUrgent, o.DeliveryDate, 
               o.RejectionReason, o.CreatedAt, o.TotalPrice, 
               o.TotalWeight, o.CurrentStage
        FROM orders o
        WHERE o.RetailerID = ?
        ORDER BY o.CreatedAt DESC
    `;
    db.query(query, [retailerID], (err, results) => {
        if (err) return res.status(500).json({ message: 'Database error', error: err });
        res.status(200).json({ message: 'Orders fetched successfully', orders: results });
    });
});

// PUT /orders/:id - Handle Approval, Rejection, and Partial Approval
router.put('/:id', (req, res) => {
    const orderID = req.params.id;
    const { status, rejection_reason, items } = req.body;

    if (!status) return res.status(400).json({ message: 'Status is required' });

    // --- CASE 1: PARTIAL APPROVAL ---
    if (status === 'partially_approved' && items && items.length > 0) {
        db.beginTransaction((err) => {
            if (err) return res.status(500).json({ message: 'Transaction Error', error: err });

            const updateOrder = 'UPDATE orders SET Status = ?, CurrentStage = 2 WHERE OrderID = ?';
            db.query(updateOrder, [status, orderID], (err1) => {
                if (err1) return db.rollback(() => res.status(500).json(err1));

                const queries = items.map(item => {
                    return new Promise((resolve, reject) => {
                        const sql = 'UPDATE order_items SET QtyApproved = ? WHERE OrderID = ? AND ProductID = ?';
                        db.query(sql, [item.qty_approved, orderID, item.product_id], (err2) => {
                            if (err2) reject(err2);
                            resolve();
                        });
                    });
                });

                Promise.all(queries)
                .then(() => {
                    const deductStockQuery = `
                        UPDATE products p
                        JOIN order_items oi ON p.ProductID = oi.ProductID
                        SET p.StockLevel = p.StockLevel - oi.QtyApproved
                        WHERE oi.OrderID = ?
                    `;
                    db.query(deductStockQuery, [orderID], (errStock) => {
                        if (errStock) return db.rollback(() => res.status(500).json({ message: 'Stock update failed', error: errStock }));

                        const recalculateQuery = `
                            UPDATE orders o
                            SET 
                                TotalPrice = (SELECT SUM(IFNULL(oi.QtyApproved, 0) * IFNULL(oi.UnitPrice, 0)) FROM order_items oi WHERE oi.OrderID = o.OrderID),
                                TotalWeight = (SELECT SUM(IFNULL(oi.QtyApproved, 0) * IFNULL(p.Weight, 0)) FROM order_items oi JOIN products p ON oi.ProductID = p.ProductID WHERE oi.OrderID = o.OrderID)
                            WHERE o.OrderID = ?
                        `;
                        db.query(recalculateQuery, [orderID], (errRecalc) => {
                            if (errRecalc) return db.rollback(() => res.status(500).json({ message: 'Recalc error', error: errRecalc }));

                            db.commit((err3) => {
                                if (err3) return db.rollback(() => res.status(500).json(err3));
                                res.status(200).json({ message: 'Order partially approved and stock deducted!' });
                            });
                        });
                    });
                })
                .catch(err4 => db.rollback(() => res.status(500).json(err4)));
            });
        });

    // --- CASE 2: FULL APPROVAL ---
    } else if (status === 'approved') {
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

    // --- CASE 3: REJECTION ---
    } else if (status === 'rejected') {
        if (!rejection_reason) return res.status(400).json({ message: 'Rejection reason is required' });
        const rejectQuery = 'UPDATE orders SET Status = ?, RejectionReason = ? WHERE OrderID = ?';
        db.query(rejectQuery, [status, rejection_reason, orderID], (err) => {
            if (err) return res.status(500).json({ message: 'Database error', error: err });
            res.status(200).json({ message: 'Order rejected successfully' });
        });
    } else {
        res.status(400).json({ message: 'Invalid status provided' });
    }
});

// GET /orders/:id/items - get items for a specific order
router.get('/:id/items', (req, res) => {
    const orderID = req.params.id;
    const query = `
        SELECT oi.ItemID, oi.QtyRequested, oi.QtyApproved,
               p.ProductName, p.Unit, p.Price
        FROM order_items oi
        JOIN products p ON oi.ProductID = p.ProductID
        WHERE oi.OrderID = ?
    `;
    db.query(query, [orderID], (err, results) => {
        if (err) return res.status(500).json({ message: 'Database error', error: err });
        res.status(200).json({ message: 'Order items fetched successfully', items: results });
    });
});

// POST /orders/:id/next-stage - Advance the order and update Status automatically
router.post('/:id/next-stage', (req, res) => {
    const orderID = req.params.id;
    
    // 1. First, see what stage the order is currently in
    const getStageQuery = 'SELECT CurrentStage, Status FROM orders WHERE OrderID = ?';
    
    db.query(getStageQuery, [orderID], (err, results) => {
        if (err || results.length === 0) return res.status(500).json({ message: 'Order not found' });
        
        const currentStage = results[0].CurrentStage;
        let nextStage = currentStage + 1;
        let newStatus = results[0].Status;

        // 2. Logic to sync Status with the Stage
        if (nextStage === 2 || nextStage === 3) {
            newStatus = 'processing'; // Moving from Approved to Packing/Processing
        } else if (nextStage >= 7) {
            nextStage = 7; // Cap it at 7
            newStatus = 'delivered'; // Final stage
        }

        const updateSql = `
            UPDATE orders 
            SET CurrentStage = ?, Status = ?
            WHERE OrderID = ?
        `;

        db.query(updateSql, [nextStage, newStatus, orderID], (updateErr) => {
            if (updateErr) return res.status(500).json({ message: 'Failed to update order status', error: updateErr });
            
            res.status(200).json({ 
                message: `Order ${orderID} moved to Stage ${nextStage}`,
                newStage: nextStage,
                newStatus: newStatus 
            });
        });
    });
});

module.exports = router;