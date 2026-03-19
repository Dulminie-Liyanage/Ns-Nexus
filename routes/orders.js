const express = require('express');
const router = express.Router();
const db = require('../config/db');

// POST /orders - retailer places an order
router.post('/', (req, res) => {
    const { retailer_id, delivery_date, is_urgent, items } = req.body;

    if (!retailer_id || !delivery_date || !items || items.length === 0) {
        return res.status(400).json({ message: 'Missing required fields' });
    }

    // 48 hour rule check for standard orders
    if (!is_urgent) {
        const now = new Date();
        const delivery = new Date(delivery_date);
        const diffHours = (delivery - now) / (1000 * 60 * 60);

        if (diffHours < 48) {
            return res.status(400).json({ 
                message: 'Standard orders must be placed at least 48 hours before delivery date' 
            });
        }
    }

    // Save order
    const orderQuery = 'INSERT INTO orders (RetailerID, Status, IsUrgent, DeliveryDate) VALUES (?, ?, ?, ?)';
    db.query(orderQuery, [retailer_id, 'pending', is_urgent ? 1 : 0, delivery_date], (err, result) => {
        if (err) {
            return res.status(500).json({ message: 'Database error', error: err });
        }

        const orderID = result.insertId;

        // Save order items
        const itemValues = items.map(item => [orderID, item.product_id, item.qty_requested, 0]);
        const itemQuery = 'INSERT INTO order_items (OrderID, ProductID, QtyRequested, QtyApproved) VALUES ?';
        
        db.query(itemQuery, [itemValues], (err2) => {
            if (err2) {
                return res.status(500).json({ message: 'Error saving order items', error: err2 });
            }

            return res.status(201).json({
                message: 'Order placed successfully',
                order_id: orderID,
                status: 'pending'
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
        SELECT o.OrderID, o.Status, o.IsUrgent, o.DeliveryDate, o.RejectionReason, o.CreatedAt
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

module.exports = router;