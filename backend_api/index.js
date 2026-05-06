const express = require('express');
const cors = require('cors');
require('dotenv').config();
const db = require('./config/db');

const authRoutes = require('./routes/auth');
const productRoutes = require('./routes/products');
const orderRoutes = require('./routes/orders');
const userRoutes = require('./routes/users');
const driverRoutes = require('./routes/drivers');
const shipmentRoutes = require('./routes/shipments');

const app = express();
app.use(cors());
app.use(express.json());

app.get('/', (req, res) => {
    res.json({ message: 'NS Nexus Backend is running' });
});

app.use('/auth', authRoutes);
app.use('/products', productRoutes);
app.use('/orders', orderRoutes);
app.use('/users', userRoutes);
app.use('/drivers', driverRoutes);
app.use('/shipments', shipmentRoutes);
app.use('/analytics', require('./routes/analytics'));
app.use('/notifications', require('./routes/notifications'));

const PORT = process.env.PORT || 5000;
app.listen(PORT, () => {
    console.log(`Server running on port ${PORT}`);
});