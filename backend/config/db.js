import mysql from "mysql2/promise";
import dotenv from "dotenv";

dotenv.config();

const pool = mysql.createPool({
  host: process.env.DB_HOST || "78.46.49.101",
  user: process.env.DB_USER || "u1066_F8vYx85FBK",
  password: process.env.DB_PASSWORD || "2UtdK8iO.1V2!YZg50@L6OaT",
  database: process.env.DB_NAME || "s1066_nexus",
  connectTimeout: 60000
});

console.log("MySQL Connected...");

export default pool;