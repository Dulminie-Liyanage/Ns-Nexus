import express from "express";
import { loginUser } from "../controllers/userController.js";

const router = express.Router();

// POST /auth/login
router.post("/login", loginUser);

export default router;