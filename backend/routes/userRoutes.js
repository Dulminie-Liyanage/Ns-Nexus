import express from "express";
import {
  getUserById,
  loginUser,
  toggleUserStatus,
  getAllUsers,
  getDrivers,
  createDriver,
  updateDriverStatus,
  getAvailableDrivers,
  getDriverSchedule,
  updateUserStatus
} from "../controllers/userController.js";
import { createUser } from "../controllers/userController.js";

const router = express.Router();

//USERS 
router.get("/", getAllUsers); 
router.post("/", createUser);             // GET /api/users
router.get("/:id", getUserById);        // GET /api/users/:id
router.put("/:id/status", updateUserStatus); // PUT /api/users/:id/status

// AUTH
router.post("/login", loginUser);       // POST /api/users/login

//DRIVERS
router.get("/drivers", getDrivers);
router.post("/drivers", createDriver);
router.put("/drivers/:id/status", updateDriverStatus);
router.get("/drivers/available", getAvailableDrivers);
router.get("/drivers/:id/schedule", getDriverSchedule);

export default router;