const express = require('express');
const router = express.Router();
const db = require('../config/db');

// POST /orders - retailer places an order
// POST /orders - retailer places an order with Total Price & Weight calculation
router.post('/', (req, res) => {
    const { retailer_id, delivery_date, is_urgent, items } = req.body;

    if (!retailer_id || !delivery_date || !items || items.length === 0) {
        return res.status(400).json({ message: 'Missing required fields' });
    }

    // 1. Create the Order Header
    const orderQuery = 'INSERT INTO orders (RetailerID, Status, IsUrgent, DeliveryDate) VALUES (?, ?, ?, ?)';
    db.query(orderQuery, [retailer_id, 'pending', is_urgent ? 1 : 0, delivery_date], (err, result) => {
        if (err) return res.status(500).json({ message: 'Database error', error: err });

        const orderID = result.insertId;
        const productIds = items.map(item => item.product_id);
        
        // 2. Fetch Prices AND Weights from your products table
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

            // 3. Save Order Items
            const itemQuery = 'INSERT INTO order_items (OrderID, ProductID, QtyRequested, QtyApproved, UnitPrice) VALUES ?';
            db.query(itemQuery, [itemValues], (err2) => {
                if (err2) return res.status(500).json({ message: 'Error saving order items', error: err2 });

                // 4. Update the Order Header with calculated totals
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
        SELECT o.OrderID, o.Status, o.IsUrgent, o.DeliveryDate, o.RejectionReason, o.CreatedAt,
               u.Name as RetailerName, u.ShopName, u.District
        FROM orders o
        JOIN users u ON o.RetailerID = u.UserID
        ORDER BY o.CreatedAt DESC
    `;

    db.query(query, (err, results) => {
        if (err) {
            return res.status(500).json({ message: 'Database error', error: err });
        }
        return res.status(200).json({
            message: 'Orders fetched successfully',
            orders: results
        });
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
        if (err) {
            return res.status(500).json({ message: 'Database error', error: err });
        }
        return res.status(200).json({
            message: 'Orders fetched successfully',
            orders: results
        });
    });
});

// PUT /orders/:id - warehouse manager approves or rejects
router.put('/:id', (req, res) => {
    const orderID = req.params.id;
    const { status, rejection_reason, items } = req.body;

    if (!status) {
        return res.status(400).json({ message: 'Status is required' });
    }

    if (status === 'rejected' && !rejection_reason) {
        return res.status(400).json({ message: 'Rejection reason is required when rejecting an order' });
    }

    const updateOrder = 'UPDATE orders SET Status = ?, RejectionReason = ? WHERE OrderID = ?';
    db.query(updateOrder, [status, rejection_reason || null, orderID], (err) => {
        if (err) {
            return res.status(500).json({ message: 'Database error', error: err });
        }

        // If partially approved, update qty_approved for each item
        if (status === 'partially_approved' && items && items.length > 0) {
            items.forEach(item => {
                const updateItem = 'UPDATE order_items SET QtyApproved = ? WHERE OrderID = ? AND ProductID = ?';
                db.query(updateItem, [item.qty_approved, orderID, item.product_id]);
            });
        }

        return res.status(200).json({
            message: `Order ${status} successfully`,
            order_id: orderID,
            status: status
        });
    });
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
        if (err) {
            return res.status(500).json({ message: 'Database error', error: err });
        }
        return res.status(200).json({
            message: 'Order items fetched successfully',
            items: results
        });
    });
});

module.exports = router;