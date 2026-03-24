const express = require('express');
const router = express.Router();
const db = require('../config/db');

// POST /auth/login
router.post('/login', (req, res) => {
    const { email, password } = req.body;

    if (!email || !password) {
        return res.status(400).json({ message: 'Email and password are required' });
    }

    const query = 'SELECT * FROM users WHERE Email = ? AND PasswordHash = ?';
    db.query(query, [email, password], (err, results) => {
        if (err) {
            return res.status(500).json({ message: 'Database error', error: err });
        }

        if (results.length === 0) {
            return res.status(401).json({ message: 'Invalid email or password' });
        }

        const user = results[0];

        if (user.IsLocked) {
            return res.status(403).json({ message: 'Account is locked. Please contact support.' });
        }

        return res.status(200).json({
            message: 'Login successful',
            user: {
                id: user.UserID,
                name: user.Name,
                email: user.Email,
                role: user.Role,
                district: user.District,
                shopName: user.ShopName
            }
        });
    });
});

module.exports = router;