const express = require('express');
const router = express.Router();
const db = require('../../config/db');
const crypto = require('crypto'); // Built-in Node tool to make tokens

// POST /auth/login
router.post('/login', (req, res) => {
    const { email, password } = req.body;

    if (!email || !password) {
        return res.status(400).json({ message: 'Email and password are required' });
    }

    // 1. Fetch user by email
    const query = 'SELECT * FROM users WHERE Email = ?';
    db.query(query, [email], (err, results) => {
        if (err) return res.status(500).json({ message: 'Database error', error: err });

        if (results.length === 0) {
            return res.status(401).json({ message: 'Invalid credentials' });
        }

        const user = results[0];

        // 2. CHECK IF LOCKED FIRST
        if (user.IsLocked === 1) {
            return res.status(403).json({ message: 'This account is locked. Contact support.' });
        }

        // 3. CHECK PASSWORD
        if (user.PasswordHash !== password) {
            const newAttempts = user.LoginAttempts + 1;

            if (newAttempts >= 3) {
                db.query(
                    'UPDATE users SET LoginAttempts = ?, IsLocked = 1 WHERE UserID = ?',
                    [newAttempts, user.UserID],
                    (err2) => {
                        if (err2) return res.status(500).json({ message: 'Database error' });
                        return res.status(403).json({ message: 'Third incorrect attempt. Your account is now locked. Please contact support.' });
                    }
                );
            } else {
                db.query(
                    'UPDATE users SET LoginAttempts = ? WHERE UserID = ?',
                    [newAttempts, user.UserID],
                    (err2) => {
                        if (err2) return res.status(500).json({ message: 'Database error' });
                        const msg = newAttempts === 1 
                            ? 'First incorrect attempt. Please try again.' 
                            : 'Second incorrect attempt. One attempt remaining before lock.';
                        return res.status(401).json({ message: msg });
                    }
                );
            }
            return;
        }

        // 4. SUCCESS -> Reset attempts AND Create Session
        db.query(
            'UPDATE users SET LoginAttempts = 0 WHERE UserID = ?',
            [user.UserID],
            (err2) => {
                if (err2) return res.status(500).json({ message: 'Database error' });

                // --- NEW SESSION CODE START ---
                const sessionToken = crypto.randomBytes(32).toString('hex');
                const expiresAt = new Date();
                expiresAt.setHours(expiresAt.getHours() + 24); // Token valid for 24 hours

                // Clear old sessions and insert new one
                db.query('DELETE FROM sessions WHERE UserID = ?', [user.UserID], () => {
                    const sessionQuery = 'INSERT INTO sessions (UserID, SessionToken, ExpiresAt, IsActive) VALUES (?, ?, ?, 1)';
                    db.query(sessionQuery, [user.UserID, sessionToken, expiresAt], (sessErr) => {
                        if (sessErr) return res.status(500).json({ message: 'Session creation failed' });

                        // Final Response with Token
                        return res.status(200).json({
                            message: 'Login successful',
                            sessionToken: sessionToken, // Send this to Flutter
                            user: {
                                id: user.UserID,
                                name: user.Name,
                                role: user.Role,
                                shopName: user.ShopName
                            }
                        });
                    });
                });
                // --- NEW SESSION CODE END ---
            }
        );
    });
});

module.exports = router;