import express from "express";
import { getDrivers, getAvailableDrivers, updateDriverStatus, } from "../controllers/userController.js";
import { getDriverById } from "../controllers/driverController.js";

const router = express.Router();

router.get("/", getDrivers);
router.get("/available", getAvailableDrivers);
router.get("/:id", getDriverById);
router.put("/:id/status", updateDriverStatus);

export default router;