import db from "../config/db.js";

// GET ALL PRODUCTS 
export const getAllProducts = (callback) => {
  db.query(
    `SELECT 
      ProductID,
      ProductName,
      SKU,
      Weight,
      Unit,
      Price,
      IsAvailable
    FROM products`,
    
    (err, results) => {
      callback(err, results);
    }
  );
};

// GET SINGLE PRODUCT 
export const getProductById = (productId, callback) => {
  db.query(
    "SELECT ProductID, ProductName, SKU, Weight, Unit, Price, IsAvailable, CreatedAt FROM products WHERE ProductID = ?",
    [productId],
    (err, results) => {
      callback(err, results[0]);
    }
  );
};

// ADD NEW PRODUCT 
export const addProduct = async (product) => {
  const { name, sku, price, weight, unit } = product;

  const sql = `
    INSERT INTO products 
    (ProductName, SKU, Price, Weight, Unit, IsAvailable)
    VALUES (?, ?, ?, ?, ?, ?)
  `;

  const [result] = await db.query(sql, [
    name,
    sku,
    price,
    weight,
    unit,
    1,
  ]);

  return result;
};

//  UPDATE PRODUCT 
export const updateProduct = (productId, product, callback) => {
  const { name, sku, price, weight, unit } = product;
  db.query(
    "UPDATE products SET ProductName = ?, SKU = ?, Price = ?, Weight = ?, Unit = ? WHERE ProductID = ?",
    [name, sku, price, weight, unit, productId],
    (err, results) => {
      callback(err, results);
    }
  );
};

//  TOGGLE PRODUCT AVAILABILITY
export const toggleAvailability = (id, available) => {
  return db.query(
    "UPDATE products SET IsAvailable = ? WHERE ProductID = ?",
    [available, id]
  );
};