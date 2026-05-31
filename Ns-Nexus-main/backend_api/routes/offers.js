const express = require('express');
const router = express.Router();
const db = require('../config/db');

function q(sql, params) {
    return new Promise((resolve, reject) =>
        db.query(sql, params || [], (err, rows) => err ? reject(err) : resolve(rows)));
}

// Auto-create table on startup — TEXT instead of JSON for compatibility
db.query(`
    CREATE TABLE IF NOT EXISTS bulk_offers (
        OfferID INT AUTO_INCREMENT PRIMARY KEY,
        Title VARCHAR(100) NOT NULL,
        Description TEXT,
        OfferType VARCHAR(20) DEFAULT 'bulk_discount' CHECK (OfferType IN ('bulk_discount','combo')),
        ProductIDs TEXT,
        DiscountPercent DECIMAL(5,2) DEFAULT 0,
        MinOrderValue DECIMAL(10,2) DEFAULT 0,
        IsActive TINYINT DEFAULT 1,
        ExpiresAt DATETIME,
        CreatedBy INT,
        CreatedAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )
`, (err) => {
    if (err) console.log('bulk_offers table note:', err.message);
    else console.log('bulk_offers table ready');
});

// GET /offers/all — WM management view (all offers including inactive)
router.get('/all', async (req, res) => {
    try {
        const rows = await q('SELECT * FROM bulk_offers ORDER BY CreatedAt DESC');
        res.json({ offers: rows });
    } catch (err) {
        res.status(500).json({ message: 'Failed to fetch offers', error: err.message });
    }
});

// GET /offers — active offers only
router.get('/', async (req, res) => {
    try {
        const rows = await q(
            `SELECT * FROM bulk_offers
             WHERE IsActive = 1 AND (ExpiresAt IS NULL OR ExpiresAt > NOW())
             ORDER BY CreatedAt DESC`
        );
        res.json({ offers: rows });
    } catch (err) {
        res.status(500).json({ message: 'Failed to fetch offers', error: err.message });
    }
});

// GET /offers/retailer/:id — personalized offers for retailer
router.get('/retailer/:id', async (req, res) => {
    const retailerId = req.params.id;
    try {
        // Get active offers with product details for combos
        const offers = await q(
            `SELECT * FROM bulk_offers
             WHERE IsActive = 1 AND (ExpiresAt IS NULL OR ExpiresAt > NOW())
             ORDER BY CreatedAt DESC`
        );

        // Enrich combo offers with product names
        for (const offer of offers) {
            if (offer.OfferType === 'combo' && offer.ProductIDs) {
                try {
                    const ids = JSON.parse(offer.ProductIDs);
                    if (ids.length > 0) {
                        const placeholders = ids.map(() => '?').join(',');
                        const products = await q(
                            `SELECT ProductID, ProductName, Price, Unit FROM products WHERE ProductID IN (${placeholders})`,
                            ids
                        );
                        offer.comboProducts = products;
                    }
                } catch (_) {}
            }
        }

        // Get retailer's most ordered products (combo suggestions)
        const combos = await q(
            `SELECT p.ProductID, p.ProductName, p.Price, p.Unit,
                    COUNT(*) as orderCount
             FROM order_items oi
             JOIN products p ON oi.ProductID = p.ProductID
             JOIN orders o ON oi.OrderID = o.OrderID
             WHERE o.RetailerID = ? AND p.IsAvailable = 1
             GROUP BY p.ProductID, p.ProductName, p.Price, p.Unit
             ORDER BY orderCount DESC LIMIT 5`,
            [retailerId]
        );

        res.json({ offers, comboSuggestions: combos });
    } catch (err) {
        res.json({ offers: [], comboSuggestions: [], error: err.message });
    }
});

// POST /offers — WM creates offer
router.post('/', async (req, res) => {
    const { title, description, offerType, productIds, discountPercent, minOrderValue, expiresAt, createdBy } = req.body;
    if (!title) return res.status(400).json({ message: 'Title is required' });
    try {
        const result = await q(
            `INSERT INTO bulk_offers
             (Title, Description, OfferType, ProductIDs, DiscountPercent, MinOrderValue, ExpiresAt, CreatedBy)
             VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
            [
                title,
                description || '',
                offerType || 'bulk_discount',
                JSON.stringify(productIds || []),
                discountPercent || 0,
                minOrderValue || 0,
                expiresAt || null,
                createdBy || null
            ]
        );
        res.json({ message: 'Offer created', offerId: result.insertId });
    } catch (err) {
        res.status(500).json({ message: 'Failed to create offer', error: err.message });
    }
});

// PUT /offers/:id — WM updates offer
router.put('/:id', async (req, res) => {
    const { title, description, offerType, productIds, discountPercent, minOrderValue, expiresAt, isActive } = req.body;
    try {
        await q(
            `UPDATE bulk_offers
             SET Title=?, Description=?, OfferType=?, ProductIDs=?,
                 DiscountPercent=?, MinOrderValue=?, ExpiresAt=?, IsActive=?
             WHERE OfferID=?`,
            [
                title, description, offerType,
                JSON.stringify(productIds || []),
                discountPercent, minOrderValue,
                expiresAt || null,
                isActive !== undefined ? isActive : 1,
                req.params.id
            ]
        );
        res.json({ message: 'Offer updated' });
    } catch (err) {
        res.status(500).json({ message: 'Failed to update offer', error: err.message });
    }
});

// DELETE /offers/:id — deactivate offer
router.delete('/:id', async (req, res) => {
    try {
        await q('UPDATE bulk_offers SET IsActive = 0 WHERE OfferID = ?', [req.params.id]);
        res.json({ message: 'Offer deactivated' });
    } catch (err) {
        res.status(500).json({ message: 'Failed to deactivate', error: err.message });
    }
});

module.exports = router;