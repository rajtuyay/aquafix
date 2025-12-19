-- phpMyAdmin SQL Dump
-- version 5.2.1
-- https://www.phpmyadmin.net/
--
-- Host: 127.0.0.1
-- Generation Time: Jul 02, 2025 at 06:35 AM
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
-- Table structure for table `tbl_clw_accounts`
--

CREATE TABLE `tbl_clw_accounts` (
  `clw_account_id` int(11) NOT NULL,
  `account_number` int(50) NOT NULL,
  `account_name` varchar(100) NOT NULL,
  `meter_no` int(50) NOT NULL,
  `customer_id` int(11) NOT NULL,
  `label` varchar(50) NOT NULL,
  `street` varchar(50) NOT NULL,
  `barangay` varchar(50) NOT NULL,
  `municipality` varchar(50) NOT NULL,
  `province` varchar(50) NOT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NULL DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `tbl_clw_accounts`
--

INSERT INTO `tbl_clw_accounts` (`clw_account_id`, `account_number`, `account_name`, `meter_no`, `customer_id`, `label`, `street`, `barangay`, `municipality`, `province`, `created_at`, `updated_at`) VALUES
(1, 2022307171, 'Raj Tuyay', 123456, 1, 'Home', '123 Ermitanyo St.', 'San Jose', 'San Simon', 'Pampanga', '2025-06-04 13:18:14', '0000-00-00 00:00:00'),
(5, 16374, 'JM Simbulan', 104123, 4, 'Home', '212 Impyerno St', 'Sta. Cruz', 'San Simon', 'Pampanga', '2025-06-05 14:19:47', '2025-07-02 03:05:12'),
(6, 0, '', 0, 1, 'Work', 'Silangan St.', 'Sta. Monica', 'San Simon', 'Pampanga', '2025-06-16 12:59:19', '0000-00-00 00:00:00');

--
-- Indexes for dumped tables
--

--
-- Indexes for table `tbl_clw_accounts`
--
ALTER TABLE `tbl_clw_accounts`
  ADD PRIMARY KEY (`clw_account_id`),
  ADD UNIQUE KEY `UNIQUE` (`account_number`),
  ADD UNIQUE KEY `UNIQUE2` (`meter_no`),
  ADD KEY `FOREIGN` (`customer_id`) USING BTREE;

--
-- AUTO_INCREMENT for dumped tables
--

--
-- AUTO_INCREMENT for table `tbl_clw_accounts`
--
ALTER TABLE `tbl_clw_accounts`
  MODIFY `clw_account_id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=7;

--
-- Constraints for dumped tables
--

--
-- Constraints for table `tbl_clw_accounts`
--
ALTER TABLE `tbl_clw_accounts`
  ADD CONSTRAINT `tbl_clw_accounts_ibfk_1` FOREIGN KEY (`customer_id`) REFERENCES `tbl_customers` (`customer_id`);
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
