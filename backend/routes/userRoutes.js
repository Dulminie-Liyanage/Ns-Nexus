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
  getDriverSchedule
} from "../controllers/userController.js";
import { createUser } from "../controllers/userController.js";

const router = express.Router();

//USERS 
router.get("/", getAllUsers);              // GET /api/users
router.get("/:id", getUserById);        // GET /api/users/:id
router.put("/:id/status", toggleUserStatus); // PUT /api/users/:id/status

// AUTH
router.post("/login", loginUser);       // POST /api/users/login

//DRIVERS
router.get("/drivers", getDrivers);
router.post("/drivers", createDriver);
router.put("/drivers/:id/status", updateDriverStatus);
router.get("/drivers/available", getAvailableDrivers);
router.get("/drivers/:id/schedule", getDriverSchedule);

//ADMIN
router.post("/", getAllUsers); // POST /api/users
router.get("/:id", getUserById); // GET /api/users/:id

export default router;