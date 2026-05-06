-- MySQL dump 10.13  Distrib 8.0.19, for Win64 (x86_64)
--
-- Host: 78.46.49.101    Database: s1066_nexus
-- ------------------------------------------------------
-- Server version	5.5.5-10.11.13-MariaDB-0ubuntu0.24.04.1

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!50503 SET NAMES utf8mb4 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

--
-- Table structure for table `deliveries`
--

DROP TABLE IF EXISTS `deliveries`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `deliveries` (
  `DeliveryID` int(11) NOT NULL AUTO_INCREMENT,
  `OrderID` int(11) NOT NULL,
  `DriverID` int(11) NOT NULL,
  `HubID` int(11) NOT NULL,
  `Status` enum('assigned','in_transit','delivered','failed') DEFAULT 'assigned',
  `AssignedAt` timestamp NULL DEFAULT current_timestamp(),
  `DeliveredAt` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`DeliveryID`),
  UNIQUE KEY `OrderID` (`OrderID`),
  KEY `DriverID` (`DriverID`),
  KEY `HubID` (`HubID`),
  CONSTRAINT `deliveries_ibfk_1` FOREIGN KEY (`OrderID`) REFERENCES `orders` (`OrderID`),
  CONSTRAINT `deliveries_ibfk_2` FOREIGN KEY (`DriverID`) REFERENCES `users` (`UserID`),
  CONSTRAINT `deliveries_ibfk_3` FOREIGN KEY (`HubID`) REFERENCES `hubs` (`HubID`)
) ENGINE=InnoDB AUTO_INCREMENT=11 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `deliveries`
--

LOCK TABLES `deliveries` WRITE;
/*!40000 ALTER TABLE `deliveries` DISABLE KEYS */;
INSERT INTO `deliveries` VALUES (1,1,7,1,'delivered','2026-03-25 07:00:00','2026-03-30 12:00:00'),(2,6,8,2,'in_transit','2026-03-28 08:00:00',NULL),(3,9,7,1,'delivered','2026-03-23 06:00:00','2026-03-24 10:00:00'),(4,4,9,3,'assigned','2026-03-26 09:00:00',NULL),(5,2,8,1,'assigned','2026-03-27 07:00:00',NULL),(6,7,9,1,'assigned','2026-03-29 07:00:00',NULL),(7,8,8,3,'assigned','2026-04-01 06:00:00',NULL),(8,3,7,1,'failed','2026-03-24 07:00:00',NULL),(9,10,9,2,'failed','2026-03-25 08:00:00',NULL),(10,5,7,2,'assigned','2026-03-23 09:00:00',NULL);
/*!40000 ALTER TABLE `deliveries` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `hubs`
--

DROP TABLE IF EXISTS `hubs`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `hubs` (
  `HubID` int(11) NOT NULL AUTO_INCREMENT,
  `HubName` varchar(100) NOT NULL,
  `HubLocation` varchar(255) NOT NULL,
  PRIMARY KEY (`HubID`)
) ENGINE=InnoDB AUTO_INCREMENT=11 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `hubs`
--

LOCK TABLES `hubs` WRITE;
/*!40000 ALTER TABLE `hubs` DISABLE KEYS */;
INSERT INTO `hubs` VALUES (1,'Colombo Central Hub','Peliyagoda, Colombo'),(2,'Kandy Hub','Goods Shed Rd, Kandy'),(3,'Gampaha Hub','Yakkala, Gampaha'),(4,'Galle Hub','Wakwella Rd, Galle'),(5,'Kurunegala Hub','Puttalam Rd, Kurunegala'),(6,'Ratnapura Hub','Main St, Ratnapura'),(7,'Anuradhapura Hub','Rowing Club Rd, Anuradhapura'),(8,'Matara Hub','Anagarika Rd, Matara'),(9,'Badulla Hub','Bandarawela Rd, Badulla'),(10,'Trincomalee Hub','Ehamparam Rd, Trincomalee');
/*!40000 ALTER TABLE `hubs` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `notifications`
--

DROP TABLE IF EXISTS `notifications`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `notifications` (
  `NotificationID` int(11) NOT NULL AUTO_INCREMENT,
  `UserID` int(11) NOT NULL,
  `OrderID` int(11) NOT NULL,
  `Message` text NOT NULL,
  `IsRead` tinyint(1) DEFAULT 0,
  `CreatedAt` timestamp NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`NotificationID`),
  KEY `UserID` (`UserID`),
  KEY `OrderID` (`OrderID`),
  CONSTRAINT `notifications_ibfk_1` FOREIGN KEY (`UserID`) REFERENCES `users` (`UserID`),
  CONSTRAINT `notifications_ibfk_2` FOREIGN KEY (`OrderID`) REFERENCES `orders` (`OrderID`)
) ENGINE=InnoDB AUTO_INCREMENT=11 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `notifications`
--

LOCK TABLES `notifications` WRITE;
/*!40000 ALTER TABLE `notifications` DISABLE KEYS */;
INSERT INTO `notifications` VALUES (1,1,1,'Your order #1 has been approved.',1,'2026-03-24 08:54:57'),(2,2,2,'Your order #2 is pending review.',0,'2026-03-24 08:54:57'),(3,3,3,'Your order #3 has been rejected.',1,'2026-03-24 08:54:57'),(4,4,4,'Your order #4 has been partially approved.',0,'2026-03-24 08:54:57'),(5,1,5,'Your urgent order #5 is pending.',0,'2026-03-24 08:54:57'),(6,2,6,'Your order #6 has been approved.',1,'2026-03-24 08:54:57'),(7,3,7,'Your order #7 is under review.',0,'2026-03-24 08:54:57'),(8,4,8,'Your order #8 is pending.',0,'2026-03-24 08:54:57'),(9,1,9,'Your urgent order #9 has been approved.',1,'2026-03-24 08:54:57'),(10,2,10,'Your order #10 has been rejected.',0,'2026-03-24 08:54:57');
/*!40000 ALTER TABLE `notifications` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `order_items`
--

DROP TABLE IF EXISTS `order_items`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `order_items` (
  `ItemID` int(11) NOT NULL AUTO_INCREMENT,
  `OrderID` int(11) NOT NULL,
  `ProductID` int(11) NOT NULL,
  `QtyRequested` int(11) NOT NULL,
  `QtyApproved` int(11) DEFAULT 0,
  `UnitPrice` decimal(10,2) NOT NULL,
  PRIMARY KEY (`ItemID`),
  KEY `OrderID` (`OrderID`),
  KEY `ProductID` (`ProductID`),
  CONSTRAINT `order_items_ibfk_1` FOREIGN KEY (`OrderID`) REFERENCES `orders` (`OrderID`),
  CONSTRAINT `order_items_ibfk_2` FOREIGN KEY (`ProductID`) REFERENCES `products` (`ProductID`)
) ENGINE=InnoDB AUTO_INCREMENT=81 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `order_items`
--

LOCK TABLES `order_items` WRITE;
/*!40000 ALTER TABLE `order_items` DISABLE KEYS */;
INSERT INTO `order_items` VALUES (1,1,1,4,4,850.00),(2,1,3,2,2,1200.00),(3,2,2,1,0,1950.00),(4,2,5,6,0,150.00),(5,3,1,2,0,850.00),(6,4,4,5,3,320.00),(7,4,6,8,8,85.00),(8,5,3,3,0,1200.00),(9,6,9,2,2,3200.00),(10,7,7,3,2,650.00),(11,8,8,2,0,480.00),(12,9,1,4,4,850.00),(13,10,6,10,0,85.00),(14,28,1,1,0,850.00),(15,28,2,2,0,1950.00),(16,29,1,4,0,850.00),(17,29,5,4,0,150.00),(18,29,4,2,0,320.00),(19,30,1,3,0,850.00),(20,30,5,2,0,150.00),(21,31,1,4,0,850.00),(22,31,3,8,0,1200.00),(23,31,6,6,0,85.00),(24,32,3,4,0,1200.00),(25,33,2,5,0,1950.00),(26,33,7,1,0,650.00),(27,34,2,1,0,1950.00),(28,34,7,3,0,650.00),(29,34,6,7,0,85.00),(30,35,2,4,0,1950.00),(31,35,1,3,0,850.00),(32,35,6,9,0,85.00),(33,35,7,5,0,650.00),(34,35,4,4,0,320.00),(35,35,9,6,0,3200.00),(36,36,1,3,0,850.00),(37,36,2,1,0,1950.00),(38,36,4,2,0,320.00),(39,37,2,5,1,1950.00),(40,37,8,3,0,480.00),(41,37,4,1,0,320.00),(42,38,2,3,7,1950.00),(43,38,4,10,0,320.00),(44,38,5,7,0,150.00),(45,39,1,2,1,850.00),(46,39,2,2,2,1950.00),(47,39,3,2,1,1200.00),(48,39,4,2,2,320.00),(49,39,5,2,0,150.00),(50,40,1,7,4,850.00),(51,40,4,4,0,320.00),(52,40,7,14,0,650.00),(53,41,2,6,10,1950.00),(54,41,4,5,0,320.00),(55,41,7,12,0,650.00),(56,42,1,2,0,850.00),(57,42,3,2,0,1200.00),(58,42,4,1,0,320.00),(59,43,1,7,5,850.00),(60,43,3,7,0,1200.00),(61,43,6,13,0,85.00),(62,44,1,4,2,850.00),(63,44,3,5,3,1200.00),(64,44,6,7,5,85.00),(65,45,1,11,7,850.00),(66,45,4,7,5,320.00),(67,45,7,5,5,650.00),(68,45,9,4,3,3200.00),(69,46,1,5,5,850.00),(70,47,11,3,3,670.00),(71,48,1,1,1,850.00),(72,48,2,1,1,1950.00),(73,48,3,6,5,1200.00),(74,48,5,4,4,150.00),(75,48,7,4,4,650.00),(76,49,5,50,50,150.00),(77,50,11,18,18,670.00),(78,51,5,10,10,150.00),(79,51,11,7,7,670.00),(80,52,1,9,7,850.00);
/*!40000 ALTER TABLE `order_items` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `order_stages`
--

DROP TABLE IF EXISTS `order_stages`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `order_stages` (
  `StageID` int(11) NOT NULL AUTO_INCREMENT,
  `OrderID` int(11) NOT NULL,
  `StageNumber` int(11) NOT NULL,
  `StageName` varchar(100) NOT NULL,
  `IsCompleted` tinyint(1) DEFAULT 0,
  `CompletedAt` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`StageID`),
  KEY `OrderID` (`OrderID`),
  CONSTRAINT `order_stages_ibfk_1` FOREIGN KEY (`OrderID`) REFERENCES `orders` (`OrderID`)
) ENGINE=InnoDB AUTO_INCREMENT=15 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `order_stages`
--

LOCK TABLES `order_stages` WRITE;
/*!40000 ALTER TABLE `order_stages` DISABLE KEYS */;
INSERT INTO `order_stages` VALUES (1,1,1,'Order Placed',1,'2026-03-23 07:10:00'),(2,1,2,'Under Warehouse Review',1,'2026-03-23 09:00:00'),(3,1,3,'Order Approved',1,'2026-03-23 10:30:00'),(4,1,4,'Assigned to Driver',1,'2026-03-25 07:00:00'),(5,1,5,'In Transit',1,'2026-03-25 08:00:00'),(6,1,6,'Delivered',1,'2026-03-30 12:00:00'),(7,1,7,'Delivery Confirmed',0,NULL),(8,2,1,'Order Placed',1,'2026-03-23 08:20:00'),(9,2,2,'Under Warehouse Review',0,NULL),(10,2,3,'Order Approved',0,NULL),(11,2,4,'Assigned to Driver',0,NULL),(12,2,5,'In Transit',0,NULL),(13,2,6,'Delivered',0,NULL),(14,2,7,'Delivery Confirmed',0,NULL);
/*!40000 ALTER TABLE `order_stages` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `orders`
--

DROP TABLE IF EXISTS `orders`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `orders` (
  `OrderID` int(11) NOT NULL AUTO_INCREMENT,
  `RetailerID` int(11) NOT NULL,
  `Status` varchar(50) NOT NULL DEFAULT 'pending',
  `IsUrgent` tinyint(1) DEFAULT 0,
  `DeliveryDate` date NOT NULL,
  `TotalPrice` decimal(12,2) DEFAULT 0.00,
  `TotalWeight` decimal(10,3) DEFAULT 0.000,
  `RejectionReason` text DEFAULT NULL,
  `CurrentStage` int(11) DEFAULT 1,
  `CreatedAt` timestamp NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`OrderID`),
  KEY `RetailerID` (`RetailerID`),
  CONSTRAINT `orders_ibfk_1` FOREIGN KEY (`RetailerID`) REFERENCES `users` (`UserID`)
) ENGINE=InnoDB AUTO_INCREMENT=53 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `orders`
--

LOCK TABLES `orders` WRITE;
/*!40000 ALTER TABLE `orders` DISABLE KEYS */;
INSERT INTO `orders` VALUES (1,1,'approved',0,'2026-03-30',5950.00,2.800,NULL,3,'2026-03-24 08:54:56'),(2,2,'approved',0,'2026-04-02',3200.00,1.600,NULL,1,'2026-03-24 08:54:56'),(3,3,'rejected',0,'2026-03-29',1700.00,0.875,'Out of stock for Milo 1kg',1,'2026-03-24 08:54:56'),(4,4,'partially_approved',0,'2026-04-05',2400.00,1.200,NULL,2,'2026-03-24 08:54:56'),(5,1,'rejected',1,'2026-03-25',4250.00,2.000,'ba ai mona karanna da',1,'2026-03-24 08:54:56'),(6,2,'approved',0,'2026-04-10',6400.00,3.200,NULL,4,'2026-03-24 08:54:56'),(7,3,'partially_approved',0,'2026-04-08',1300.00,0.800,NULL,2,'2026-03-24 08:54:56'),(8,4,'approved',0,'2026-04-15',1700.00,0.850,NULL,1,'2026-03-24 08:54:56'),(9,1,'approved',1,'2026-03-24',3600.00,1.800,NULL,5,'2026-03-24 08:54:56'),(10,2,'rejected',0,'2026-03-28',960.00,0.540,'Delivery date too close',1,'2026-03-24 08:54:56'),(11,2,'rejected',0,'2026-03-30',0.00,0.000,'uba katai',1,'2026-03-25 14:16:31'),(12,4,'approved',0,'2026-03-31',0.00,0.000,NULL,1,'2026-03-26 14:11:26'),(13,4,'approved',1,'2026-03-27',0.00,0.000,NULL,1,'2026-03-26 14:11:47'),(14,4,'approved',1,'2026-03-27',0.00,0.000,NULL,1,'2026-03-26 14:12:49'),(15,4,'approved',0,'2026-03-31',0.00,0.000,NULL,1,'2026-03-26 14:13:37'),(16,4,'approved',1,'2026-03-26',0.00,0.000,NULL,1,'2026-03-26 14:15:35'),(17,4,'rejected',0,'2026-04-02',0.00,0.000,'ba ai moko',1,'2026-03-26 14:35:51'),(18,4,'approved',0,'2026-04-02',0.00,0.000,NULL,1,'2026-03-26 14:35:59'),(19,4,'approved',0,'2026-04-02',0.00,0.000,NULL,1,'2026-03-26 14:36:57'),(20,4,'rejected',0,'2026-04-02',0.00,0.000,'www',1,'2026-03-26 14:37:13'),(21,4,'approved',0,'2026-03-31',0.00,0.000,NULL,1,'2026-03-26 14:39:17'),(22,4,'approved',0,'2026-03-31',0.00,0.000,NULL,1,'2026-03-26 14:39:24'),(23,4,'rejected',0,'2026-03-31',0.00,0.000,'yyyy',1,'2026-03-26 14:43:30'),(24,4,'approved',0,'2026-03-31',0.00,0.000,NULL,1,'2026-03-26 14:43:38'),(25,4,'approved',0,'2026-03-31',0.00,0.000,NULL,1,'2026-03-26 15:11:41'),(26,4,'rejected',0,'2026-03-31',0.00,0.000,'cdfd',1,'2026-03-26 15:11:49'),(27,4,'approved',0,'2026-03-30',0.00,0.000,NULL,1,'2026-03-26 15:12:27'),(28,4,'rejected',0,'2026-03-31',4750.00,2.400,'uba hena kathai oi',1,'2026-03-27 06:53:29'),(29,4,'approved',1,'2026-03-27',4640.00,1.880,NULL,1,'2026-03-27 06:54:54'),(30,4,'approved',0,'2026-03-31',2850.00,1.290,NULL,1,'2026-03-27 07:03:23'),(31,4,'approved',1,'2026-03-27',13510.00,3.650,NULL,1,'2026-03-27 07:04:53'),(32,4,'rejected',0,'2026-03-31',4800.00,0.800,'ba dene na moko scean eke da inne',1,'2026-03-27 07:09:43'),(33,4,'rejected',1,'2026-03-31',10400.00,5.400,'ai moko wali da uba',1,'2026-03-27 07:35:16'),(34,4,'approved',0,'2026-04-10',4495.00,2.725,NULL,1,'2026-03-27 07:45:40'),(35,4,'approved',0,'2026-04-07',34845.00,13.475,NULL,1,'2026-03-27 07:48:42'),(36,4,'approved',0,'2026-04-18',5140.00,2.300,NULL,1,'2026-03-27 08:15:23'),(37,4,'partially_approved',0,'2026-04-04',11510.00,6.250,NULL,2,'2026-03-27 09:16:59'),(38,4,'partially_approved',0,'2026-04-01',13650.00,7.000,NULL,2,'2026-03-27 09:45:26'),(39,4,'partially_approved',0,'2026-03-31',6590.00,2.700,NULL,2,'2026-03-27 09:48:12'),(40,4,'partially_approved',0,'2026-03-31',3400.00,1.600,NULL,2,'2026-03-27 09:51:11'),(41,4,'processing',0,'2026-03-30',19500.00,10.000,NULL,3,'2026-03-27 09:53:33'),(42,4,'rejected',0,'2026-03-31',4420.00,1.250,'ghghh',1,'2026-03-27 09:58:26'),(43,4,'processing',0,'2026-04-02',4250.00,2.000,NULL,4,'2026-03-27 10:07:54'),(44,4,'processing',0,'2026-03-31',5725.00,1.775,NULL,3,'2026-03-27 10:11:20'),(45,4,'delivered',0,'2026-03-31',20400.00,7.750,NULL,7,'2026-03-27 10:12:54'),(46,4,'delivered',0,'2026-03-31',4250.00,2.000,NULL,7,'2026-03-27 11:05:15'),(47,4,'delivered',0,'2026-03-31',2010.00,2.100,NULL,7,'2026-03-27 11:35:30'),(48,4,'processing',0,'2026-04-08',12000.00,4.180,NULL,3,'2026-03-27 12:22:34'),(49,4,'approved',1,'2026-03-27',7500.00,2.250,NULL,2,'2026-03-27 12:25:33'),(50,4,'approved',0,'2026-03-31',12060.00,12.600,NULL,2,'2026-03-27 12:27:40'),(51,4,'processing',0,'2026-03-30',6190.00,5.350,NULL,3,'2026-03-27 12:27:58'),(52,4,'processing',0,'2026-03-31',5950.00,2.800,NULL,3,'2026-03-27 12:34:55');
/*!40000 ALTER TABLE `orders` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `products`
--

DROP TABLE IF EXISTS `products`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `products` (
  `ProductID` int(11) NOT NULL AUTO_INCREMENT,
  `ProductName` varchar(100) NOT NULL,
  `SKU` varchar(50) NOT NULL,
  `Unit` varchar(20) NOT NULL,
  `Price` decimal(10,2) NOT NULL,
  `Weight` decimal(8,3) NOT NULL DEFAULT 0.000,
  `IsAvailable` tinyint(1) DEFAULT 1,
  `CreatedAt` timestamp NULL DEFAULT current_timestamp(),
  `StockLevel` int(11) DEFAULT 0,
  PRIMARY KEY (`ProductID`),
  UNIQUE KEY `SKU` (`SKU`)
) ENGINE=InnoDB AUTO_INCREMENT=12 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `products`
--

LOCK TABLES `products` WRITE;
/*!40000 ALTER TABLE `products` DISABLE KEYS */;
INSERT INTO `products` VALUES (1,'Milo 400g','MLO-400','box',850.00,0.400,1,'2026-03-24 08:54:55',487),(2,'Milo 1kg','MLO-1KG','box',1950.00,1.000,1,'2026-03-24 08:54:55',499),(3,'Nescafe 200g','NCF-200','box',1200.00,0.200,1,'2026-03-24 08:54:55',495),(4,'Nescafe 50g','NCF-050','sachet',320.00,0.050,1,'2026-03-24 08:54:55',500),(5,'KitKat 4 Finger','KKT-4F','unit',150.00,0.045,1,'2026-03-24 08:54:55',436),(6,'Maggi Noodles','MGI-NOD','pack',85.00,0.075,1,'2026-03-24 08:54:55',500),(7,'Nestea 400g','NTA-400','box',650.00,0.400,1,'2026-03-24 08:54:55',494),(8,'Milkmaid 400g','MMD-400','tin',480.00,0.400,1,'2026-03-24 08:54:55',500),(9,'Nan Pro Stage 1','NAN-ST1','tin',3200.00,0.900,1,'2026-03-24 08:54:55',500),(10,'Lion Date Crunch','LDC-BAR','unit',120.00,0.035,1,'2026-03-24 08:54:55',500),(11,'sunquick','sun-qu101010','bottle',670.00,0.700,1,'2026-03-27 11:33:32',-5);
/*!40000 ALTER TABLE `products` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `sessions`
--

DROP TABLE IF EXISTS `sessions`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `sessions` (
  `SessionID` int(11) NOT NULL AUTO_INCREMENT,
  `UserID` int(11) NOT NULL,
  `SessionToken` varchar(255) NOT NULL,
  `LoginTime` timestamp NULL DEFAULT current_timestamp(),
  `ExpiresAt` timestamp NOT NULL,
  `IsActive` tinyint(1) DEFAULT 1,
  PRIMARY KEY (`SessionID`),
  UNIQUE KEY `SessionToken` (`SessionToken`),
  KEY `UserID` (`UserID`),
  CONSTRAINT `sessions_ibfk_1` FOREIGN KEY (`UserID`) REFERENCES `users` (`UserID`)
) ENGINE=InnoDB AUTO_INCREMENT=81 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `sessions`
--

LOCK TABLES `sessions` WRITE;
/*!40000 ALTER TABLE `sessions` DISABLE KEYS */;
INSERT INTO `sessions` VALUES (1,1,'tok_priya_001','2026-03-23 07:00:00','2026-03-23 19:00:00',1),(2,2,'tok_kamal_001','2026-03-23 08:15:00','2026-03-23 20:15:00',1),(5,12,'tok_admin_001','2026-03-23 05:00:00','2026-03-23 17:00:00',1),(8,7,'tok_ruwan_001','2026-03-23 07:30:00','2026-03-23 19:30:00',1),(9,10,'tok_dinesh_001','2026-03-22 08:00:00','2026-03-22 20:00:00',0),(10,11,'tok_tharuka_001','2026-03-23 09:30:00','2026-03-23 21:30:00',1),(16,5,'b7a28fad321e2e98c5d8b7f3436c7de2002654f1019c0e992c2100cb3eb77115','2026-03-27 05:19:07','2026-03-28 04:19:07',1),(21,3,'e4eba2cd0b9bfb7da3dac0f6751b74fc8255b553002b8f407adc48e6880c1efd','2026-03-27 05:28:58','2026-03-28 04:28:58',1),(79,4,'334e0ee963dce1f155a1aeeab41952926523ebae3f55fb27047af3d362fe6444','2026-03-27 12:40:38','2026-03-28 11:40:38',1),(80,6,'da3d6fca479ea5a723414969085d7cadda208f08752a117a22f985b39d871a72','2026-03-27 12:51:42','2026-03-28 11:51:42',1);
/*!40000 ALTER TABLE `sessions` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `users`
--

DROP TABLE IF EXISTS `users`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `users` (
  `UserID` int(11) NOT NULL AUTO_INCREMENT,
  `Name` varchar(100) NOT NULL,
  `Email` varchar(150) NOT NULL,
  `Phone` varchar(15) NOT NULL,
  `PasswordHash` varchar(255) NOT NULL,
  `Role` enum('retailer','warehouse_manager','driver','3pl_manager','admin') NOT NULL,
  `ShopName` varchar(100) DEFAULT NULL,
  `Address` varchar(255) DEFAULT NULL,
  `District` varchar(50) NOT NULL,
  `LoginAttempts` int(11) DEFAULT 0,
  `IsLocked` tinyint(1) DEFAULT 0,
  `CreatedAt` timestamp NULL DEFAULT current_timestamp(),
  `lock_until` datetime DEFAULT NULL,
  PRIMARY KEY (`UserID`),
  UNIQUE KEY `Email` (`Email`)
) ENGINE=InnoDB AUTO_INCREMENT=13 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `users`
--

LOCK TABLES `users` WRITE;
/*!40000 ALTER TABLE `users` DISABLE KEYS */;
INSERT INTO `users` VALUES (1,'Priya Silva','priya@gmail.com','0771234567','1234','retailer','Priya Groceries','12 Main St, Colombo 03','Colombo',3,1,'2026-03-24 08:54:55',NULL),(2,'Kamal Perera','kamal@gmail.com','0772345678','1234','retailer','Kamal Super Mart','45 Galle Rd, Colombo 06','Colombo',3,1,'2026-03-24 08:54:55',NULL),(3,'Nimal Fernando','nimal@gmail.com','0773456789','1234','retailer','Nimal Stores','78 Kandy Rd, Kurunegala','Kurunegala',0,0,'2026-03-24 08:54:55',NULL),(4,'Sasmitha Tharu','sasmitha@gmail.com','0761234567','1234','retailer','Tharu Traders','23 Peradeniya Rd, Kandy','Kandy',0,0,'2026-03-24 08:54:55',NULL),(5,'Anura Perera','anura@nestle.lk','0779876543','1234','warehouse_manager',NULL,'Nestle Warehouse, Colombo','Colombo',0,0,'2026-03-24 08:54:55',NULL),(6,'Saman Bandara','saman@nestle.lk','0778765432','1234','warehouse_manager',NULL,'Nestle Warehouse, Kandy','Kandy',0,0,'2026-03-24 08:54:55',NULL),(7,'Ruwan Jayasekara','ruwan@driver.lk','0712345678','1234','driver',NULL,'34 Driver Lane, Colombo','Colombo',0,0,'2026-03-24 08:54:55',NULL),(8,'Chamara Silva','chamara@driver.lk','0713456789','1234','driver',NULL,'56 Transport Rd, Gampaha','Gampaha',0,0,'2026-03-24 08:54:55',NULL),(9,'Lasith Mendis','lasith@driver.lk','0754321098','1234','driver',NULL,'12 Warehouse Rd, Colombo','Colombo',0,0,'2026-03-24 08:54:55',NULL),(10,'Dinesh Kumar','dinesh@3pl.lk','0765432109','1234','3pl_manager',NULL,'3PL Hub, Peliyagoda','Gampaha',0,0,'2026-03-24 08:54:55',NULL),(11,'Tharuka Wijesinghe','tharuka@3pl.lk','0766543210','1234','3pl_manager',NULL,'3PL Hub, Kandy','Kandy',0,0,'2026-03-24 08:54:55',NULL),(12,'Admin User','admin@nestle.lk','0777000000','1234','admin',NULL,'Nestle HQ, Colombo 02','Colombo',0,0,'2026-03-24 08:54:55',NULL);
/*!40000 ALTER TABLE `users` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Dumping routines for database 's1066_nexus'
--
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2026-03-27 18:47:55
