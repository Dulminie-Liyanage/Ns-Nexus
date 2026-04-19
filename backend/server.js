import express from "express";
import dotenv from "dotenv";
import cors from "cors";
import db from "./config/db.js";

// Import routes (ALL must use export default)
import userRoutes from "./routes/userRoutes.js";
import orderRoutes from "./routes/orderRoutes.js";
import authRoutes from "./routes/authRoutes.js";
import inventoryRoutes from "./routes/inventoryRoutes.js";
import shipmentsRoute from "./routes/shipmentsRoute.js";
import driverRoutes from "./routes/driverRoutes.js";
import { startDailyReportJob } from "./jobs/dailyReportJob.js";

// Load environment variables
dotenv.config();

const app = express();
startDailyReportJob();

// Middleware
app.use(cors());
app.use(express.json());

// Test route
app.get("/test", (req, res) => {
  res.send("Backend working");
});

// API Routes
app.use("/api", userRoutes);
app.use("/api/orders", orderRoutes);
app.use("/api/auth", authRoutes);
app.use("/api/inventory", inventoryRoutes);
app.use("/api/shipments", shipmentsRoute);
app.use("/api/drivers", driverRoutes);

// Defualt route
app.get("/", (req, res) => {
  res.send("API is running...");
});

// Start server
const PORT = process.env.PORT || 5000;
app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});

console.log("JWT_SECRET:", process.env.JWT_SECRET);