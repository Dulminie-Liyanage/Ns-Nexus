import { DataTypes } from "sequelize";
import { sequelize } from "../db.js";

export const Product = sequelize.define("Product", {
  id: {
    type: DataTypes.INTEGER,
    primaryKey: true,
    autoIncrement: true,
  },
  name: { type: DataTypes.STRING, allowNull: false },
  sku: { type: DataTypes.STRING, allowNull: false, unique: true },
  price: { type: DataTypes.FLOAT, allowNull: false },
  weight: { type: DataTypes.FLOAT, allowNull: false },
  available: { type: DataTypes.BOOLEAN, defaultValue: true },
}, { timestamps: true });