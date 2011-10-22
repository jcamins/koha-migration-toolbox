-- MySQL dump 10.13  Distrib 5.1.49, for debian-linux-gnu (x86_64)
--
-- Host: localhost    Database: load04
-- ------------------------------------------------------
-- Server version	5.1.49-3

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

--
-- Table structure for table `athena_checkouts`
--

DROP TABLE IF EXISTS `athena_checkouts`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `athena_checkouts` (
  `checkout_oid` int(11) NOT NULL,
  `copy_oid` int(11) DEFAULT NULL,
  `patron_oid` int(11) NOT NULL,
  `due_date` datetime DEFAULT NULL,
  `trans_date` datetime DEFAULT NULL,
  PRIMARY KEY (`checkout_oid`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `athena_copies`
--

DROP TABLE IF EXISTS `athena_copies`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `athena_copies` (
  `copy_oid` int(11) NOT NULL,
  `title_oid` int(11) NOT NULL,
  `copy_id` varchar(50) NOT NULL,
  `call_number` varchar(50) DEFAULT NULL,
  `date_edited` datetime DEFAULT NULL,
  `copy_type_oid` int(11) DEFAULT NULL,
  `price` decimal(15,4) DEFAULT NULL,
  `date_acquired` datetime DEFAULT NULL,
  `private_note` varchar(255) DEFAULT NULL,
  `status` int(11) DEFAULT NULL,
  `public_note` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`copy_oid`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `athena_copy_types`
--

DROP TABLE IF EXISTS `athena_copy_types`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `athena_copy_types` (
  `copy_type_oid` int(11) NOT NULL,
  `type_name` varchar(50) NOT NULL,
  PRIMARY KEY (`copy_type_oid`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `athena_fines`
--

DROP TABLE IF EXISTS `athena_fines`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `athena_fines` (
  `fine_oid` int(11) NOT NULL,
  `patron_oid` int(11) NOT NULL,
  `copy_oid` int(11) DEFAULT NULL,
  `amount_paid` decimal(15,4) DEFAULT NULL,
  `fine_amount` decimal(15,4) DEFAULT NULL,
  `date_edited` datetime DEFAULT NULL,
  PRIMARY KEY (`fine_oid`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `athena_holds`
--

DROP TABLE IF EXISTS `athena_holds`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `athena_holds` (
  `hold_oid` int(11) NOT NULL,
  `patron_oid` int(11) NOT NULL,
  `title_oid` int(11) NOT NULL,
  `copy_oid` int(11) DEFAULT NULL,
  `hold_available_date` datetime DEFAULT NULL,
  `hold_position` int(11) DEFAULT NULL,
  `trans_date` datetime DEFAULT NULL,
  PRIMARY KEY (`hold_oid`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `athena_patron_types`
--

DROP TABLE IF EXISTS `athena_patron_types`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `athena_patron_types` (
  `patron_type_oid` int(11) NOT NULL,
  `type_name` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`patron_type_oid`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `athena_patrons`
--

DROP TABLE IF EXISTS `athena_patrons`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `athena_patrons` (
  `patron_oid` int(11) NOT NULL,
  `patron_type_oid` int(11) NOT NULL,
  `patron_id` varchar(50) DEFAULT NULL,
  `address1` varchar(255) DEFAULT NULL,
  `address2` varchar(255) DEFAULT NULL,
  `city` varchar(100) DEFAULT NULL,
  `date_added` datetime DEFAULT NULL,
  `email` varchar(100) DEFAULT NULL,
  `first_name` varchar(100) DEFAULT NULL,
  `middle_name` varchar(100) DEFAULT NULL,
  `other_phone` varchar(100) DEFAULT NULL,
  `phone` varchar(100) DEFAULT NULL,
  `postal_zip` varchar(20) DEFAULT NULL,
  `privileges_expire` datetime DEFAULT NULL,
  `province_state` varchar(10) DEFAULT NULL,
  `surname` varchar(10) DEFAULT NULL,
  `user_defined1` varchar(255) DEFAULT NULL,
  `user_defined10` varchar(255) DEFAULT NULL,
  `user_defined2` varchar(255) DEFAULT NULL,
  `user_defined3` varchar(255) DEFAULT NULL,
  `user_defined4` varchar(255) DEFAULT NULL,
  `user_defined5` varchar(255) DEFAULT NULL,
  `user_defined6` varchar(255) DEFAULT NULL,
  `user_defined7` varchar(255) DEFAULT NULL,
  `user_defined8` varchar(255) DEFAULT NULL,
  `user_defined9` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`patron_oid`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `athena_titles`
--

DROP TABLE IF EXISTS `athena_titles`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `athena_titles` (
  `title_oid` int(11) NOT NULL,
  `marc` mediumblob NOT NULL,
  PRIMARY KEY (`title_oid`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2011-02-27  7:32:38
