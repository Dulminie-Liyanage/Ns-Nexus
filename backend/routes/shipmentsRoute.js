import express from "express";

import {
  getShipments,
  getShipmentById,
  createShipment,
  updateShipmentStatus,
} from "../controllers/shipmentController.js";

const router = express.Router();

router.get("/", getShipments); // GET all shipments
router.get("/:id", getShipmentById); // GET single shipment
router.post("/", createShipment); // CREATE shipment
router.put("/:id", updateShipmentStatus); //UPDATE shipment 

export default router;