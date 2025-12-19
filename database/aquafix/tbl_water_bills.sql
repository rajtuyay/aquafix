-- phpMyAdmin SQL Dump
-- version 5.2.1
-- https://www.phpmyadmin.net/
--
-- Host: 127.0.0.1
-- Generation Time: Jul 02, 2025 at 08:17 AM
-- Server version: 10.4.32-MariaDB
-- PHP Version: 8.2.12

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
START TRANSACTION;
SET time_zone = "+00:00";


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;

--
-- Database: `aquafix`
--

-- --------------------------------------------------------

--
-- Table structure for table `tbl_water_bills`
--

CREATE TABLE `tbl_water_bills` (
  `bill_id` int(11) NOT NULL,
  `customer_id` int(11) NOT NULL,
  `year` int(11) NOT NULL,
  `month` varchar(9) NOT NULL,
  `consumption` int(10) NOT NULL,
  `price` double NOT NULL,
  `amount` double NOT NULL,
  `fluctuation` varchar(7) NOT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `tbl_water_bills`
--

INSERT INTO `tbl_water_bills` (`bill_id`, `customer_id`, `year`, `month`, `consumption`, `price`, `amount`, `fluctuation`, `created_at`) VALUES
(1, 4, 2024, 'Dec', 20, 34.7, 681, 'N/A', '2025-06-17 12:42:38'),
(2, 4, 2025, 'Jan', 20, 34.7, 681, '+0.0%', '2025-06-17 12:35:57'),
(3, 4, 2025, 'Feb', 21, 36, 717, '+5.29%', '2025-06-17 12:36:42'),
(4, 4, 2025, 'Mar', 20, 34.7, 681, '-5.02%', '2025-06-17 12:51:47'),
(5, 4, 2025, 'Apr', 29, 36, 1005, '+47.58%', '2025-06-17 12:48:49'),
(9, 5, 2025, 'May', 21, 36, 717, '-28.7%', '2025-06-17 14:10:39'),
(10, 5, 2025, 'Jan', 20, 34.7, 681, 'N/A', '2025-06-18 07:06:58');

--
-- Indexes for dumped tables
--

--
-- Indexes for table `tbl_water_bills`
--
ALTER TABLE `tbl_water_bills`
  ADD PRIMARY KEY (`bill_id`),
  ADD KEY `FOREIGN` (`customer_id`) USING BTREE;

--
-- AUTO_INCREMENT for dumped tables
--

--
-- AUTO_INCREMENT for table `tbl_water_bills`
--
ALTER TABLE `tbl_water_bills`
  MODIFY `bill_id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=12;

--
-- Constraints for dumped tables
--

--
-- Constraints for table `tbl_water_bills`
--
ALTER TABLE `tbl_water_bills`
  ADD CONSTRAINT `tbl_water_bills_ibfk_1` FOREIGN KEY (`customer_id`) REFERENCES `tbl_customers` (`customer_id`);
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
