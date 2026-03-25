const express = require('express');
const router = express.Router();
const db = require('../config/db');

// POST /auth/login
router.post('/login', (req, res) => {
    const { email, password } = req.body;

    if (!email || !password) {
        return res.status(400).json({ message: 'Email and password are required' });
    }

    // STEP 1: Fetch user by email only
    const query = 'SELECT * FROM users WHERE Email = ?';
    db.query(query, [email], (err, results) => {
        if (err) {
            return res.status(500).json({ message: 'Database error', error: err });
        }

        if (results.length === 0) {
            return res.status(401).json({ message: 'Invalid credentials' });
        }

        const user = results[0];

        // STEP 2: Check if account is locked
        if (user.IsLocked === 1) {
            return res.status(403).json({ message: 'Account is locked. Contact support.' });
        }

        // STEP 3: Check password (plain text for MVP)
        if (user.PasswordHash !== password) {
            const attempts = user.LoginAttempts + 1;

            if (attempts >= 3) {
                db.query(
                    'UPDATE users SET LoginAttempts = ?, IsLocked = 1 WHERE UserID = ?',
                    [attempts, user.UserID],
                    (err2) => {
                        if (err2) return res.status(500).json({ message: 'Database error', error: err2 });

                        return res.status(403).json({
                            message: 'Account locked after 3 failed attempts'
                        });
                    }
                );
            } else {
                db.query(
                    'UPDATE users SET LoginAttempts = ? WHERE UserID = ?',
                    [attempts, user.UserID],
                    (err2) => {
                        if (err2) return res.status(500).json({ message: 'Database error', error: err2 });

                        return res.status(401).json({
                            message: 'Invalid credentials',
                            attempts_left: 3 - attempts
                        });
                    }
                );
            }
            return;
        }

        // STEP 4: Password correct → reset attempts
        db.query(
            'UPDATE users SET LoginAttempts = 0 WHERE UserID = ?',
            [user.UserID],
            (err2) => {
                if (err2) return res.status(500).json({ message: 'Database error', error: err2 });

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
            }
        );
    });
});

module.exports = router;