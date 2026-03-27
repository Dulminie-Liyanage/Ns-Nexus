const express = require('express');
const router = express.Router();
const db = require('../config/db');

// 1. FOR RETAILERS: Only see what is currently in stock
router.get('/', (req, res) => {
    const query = 'SELECT ProductID, ProductName, Unit, Price, SKU FROM products WHERE IsAvailable = 1';
    db.query(query, (err, results) => {
        if (err) return res.status(500).json({ message: 'Database error', error: err });
        return res.status(200).json({ products: results });
    });
});

// 2. FOR WAREHOUSE MANAGER: See EVERYTHING (even sold out)
router.get('/all', (req, res) => {
    const query = 'SELECT ProductID, ProductName, Unit, Price, SKU, IsAvailable FROM products';
    db.query(query, (err, results) => {
        if (err) return res.status(500).json({ message: 'Database error', error: err });
        return res.status(200).json({ products: results });
    });
});

// 3. TOGGLE AVAILABILITY: Switch between Sold Out and Available
// TOGGLE AVAILABILITY: Switch between Sold Out and Available
router.patch('/:id/toggle', (req, res) => {
    const productId = req.params.id;
    const { isAvailable } = req.body; // Antigravity is sending {"isAvailable": 1}

    // This console.log is your best friend. 
    // Check your terminal after you click the switch to see if this appears!
    console.log(`>>> Received Toggle for Product ${productId}: New Status = ${isAvailable}`);

    const query = 'UPDATE products SET IsAvailable = ? WHERE ProductID = ?';
    
    db.query(query, [isAvailable, productId], (err, result) => {
        if (err) {
            console.error("Database Error:", err);
            return res.status(500).json({ message: 'Database error', error: err });
        }
        
        // If the ProductID doesn't exist in the DB
        if (result.affectedRows === 0) {
            return res.status(404).json({ message: 'Product not found' });
        }

        console.log(`>>> Database Updated Successfully for Product ${productId}`);
        res.status(200).json({ message: 'Status updated successfully' });
    });
});

module.exports = router;