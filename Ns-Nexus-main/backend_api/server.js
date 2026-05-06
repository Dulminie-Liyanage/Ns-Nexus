const db = require('./config/db'); 
const errorHandler = require('./middleware/errorHandler'); // keep this after imports
const express = require('express');
const cors = require('cors');
require('dotenv').config();

const authController = require('./controllers/authController');
const productController = require('./controllers/productController');
const orderController = require('./controllers/orderController');

const app = express();
app.use(cors());
app.use(express.json());

app.use('/api/auth', authController);
app.use('/api/product', productController);
app.use('/api/order', orderController);

const PORT = process.env.PORT || 5000;
app.listen(PORT, () => console.log(`Server running on port ${PORT}`));

app.post("/api/login", async (req, res) => {
  const { email, password } = req.body;

  const [rows] = await db.query(
    "SELECT * FROM users WHERE email = ?",
    [email]
  );

  if (rows.length === 0) {
    return res.status(401).json({ error: "User not found" });
  }

  const user = rows[0];

  // (later you hash password)
  if (user.password !== password) {
    return res.status(401).json({ error: "Invalid password" });
  }

  res.json({
    id: user.id,
    email: user.email,
    role: user.role,
    name: user.name,
  });
});