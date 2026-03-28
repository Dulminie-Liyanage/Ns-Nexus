const db = require('../config/db');

const authMiddleware = (req, res, next) => {
  const token = req.headers['authorization'];
  if (!token) return res.status(401).json({ message: 'No token provided' });

  const query = 'SELECT * FROM sessions WHERE SessionToken=? AND IsActive=1';
  db.query(query, [token], (err, results) => {
    if (err) return res.status(500).json({ message: 'DB error', error: err });
    if (!results.length) return res.status(401).json({ message: 'Invalid or expired token' });

    req.user = { id: results[0].UserID };
    next();
  });
};

module.exports = authMiddleware;