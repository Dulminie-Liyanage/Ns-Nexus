import { DataTypes } from "sequelize";
import { sequelize } from "../db.js";
import { User } from "./userModel.js";
import { Product } from "./productModel.js";

export const Order = sequelize.define("Order", {
  id: {
    type: DataTypes.INTEGER,
    primaryKey: true,
    autoIncrement: true,
  },
  status: {
    type: DataTypes.ENUM(
      "Pending",
      "Approved",
      "Packing",
      "Transit",
      "3PL",
      "Out for Delivery",
      "Delivered",
      "Rejected"
    ),
    defaultValue: "Pending",
  },
  totalPrice: { type: DataTypes.FLOAT, allowNull: false },
  totalWeight: { type: DataTypes.FLOAT, allowNull: false },
  deliveryDate: { type: DataTypes.DATE, allowNull: false },
  rejectionReason: { type: DataTypes.STRING, allowNull: true },
}, { timestamps: true });

// Relationships
Order.belongsTo(User, { as: "retailer", foreignKey: "retailerId" });
Order.belongsToMany(Product, { through: "OrderItems", foreignKey: "orderId" });
Product.belongsToMany(Order, { through: "OrderItems", foreignKey: "productId" });