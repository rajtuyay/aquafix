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
-- Table structure for table `tbl_job_orders`
--

CREATE TABLE `tbl_job_orders` (
  `job_order_id` int(11) NOT NULL,
  `jo_number` varchar(20) NOT NULL,
  `customer_id` int(11) NOT NULL,
  `clw_account_id` int(11) NOT NULL,
  `plumber_id` int(11) DEFAULT NULL,
  `category` varchar(30) NOT NULL,
  `date` varchar(30) NOT NULL,
  `time` time NOT NULL,
  `notes` varchar(255) NOT NULL,
  `status` enum('Pending','Dispatched','Accomplished','Cancelled') NOT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `tbl_job_orders`
--

INSERT INTO `tbl_job_orders` (`job_order_id`, `jo_number`, `customer_id`, `clw_account_id`, `plumber_id`, `category`, `date`, `time`, `notes`, `status`, `created_at`) VALUES
(1, 'JO25-0510-0001', 4, 5, 1, 'Busted Pipe', '2025-06-05', '20:48:45', 'Pakicheck po asap', 'Pending', '2025-06-05 14:21:50'),
(2, 'JO25-0512-0002', 4, 1, 1, 'Change Meter', '2025-06-15', '10:31:21', 'Feel ko may sira sya teh, taas ng reading nya!', 'Cancelled', '2025-06-16 12:17:29'),
(3, 'JO25-0514-0003', 5, 1, 1, 'Busted Pipe', '2025-06-16', '12:13:49', 'ISA PAAAAA', 'Pending', '2025-06-16 12:24:04'),
(4, 'JO25-0516-0004', 4, 1, 1, 'Busted Mainline', '2025-06-16', '01:12:47', 'KAINIS', 'Accomplished', '2025-06-16 12:25:14'),
(5, 'JO25-0516-0005', 4, 6, 1, 'Busted Pipe', '2025-06-16', '15:02:00', 'LAST NA PO HEHE', 'Dispatched', '2025-06-16 13:02:07'),
(6, 'JO25-0702-0006', 4, 5, NULL, 'Busted Pipe', '2025-07-02', '06:18:00', 'WAIT PO', 'Pending', '2025-07-02 04:18:09');

--
-- Indexes for dumped tables
--

--
-- Indexes for table `tbl_job_orders`
--
ALTER TABLE `tbl_job_orders`
  ADD PRIMARY KEY (`job_order_id`),
  ADD UNIQUE KEY `Job Order No` (`jo_number`),
  ADD KEY `FOREIGN2` (`clw_account_id`) USING BTREE,
  ADD KEY `FOREIGN` (`customer_id`) USING BTREE,
  ADD KEY `plumber_id` (`plumber_id`);

--
-- AUTO_INCREMENT for dumped tables
--

--
-- AUTO_INCREMENT for table `tbl_job_orders`
--
ALTER TABLE `tbl_job_orders`
  MODIFY `job_order_id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=7;

--
-- Constraints for dumped tables
--

--
-- Constraints for table `tbl_job_orders`
--
ALTER TABLE `tbl_job_orders`
  ADD CONSTRAINT `tbl_job_orders_ibfk_1` FOREIGN KEY (`clw_account_id`) REFERENCES `tbl_clw_accounts` (`clw_account_id`),
  ADD CONSTRAINT `tbl_job_orders_ibfk_2` FOREIGN KEY (`customer_id`) REFERENCES `tbl_customers` (`customer_id`),
  ADD CONSTRAINT `tbl_job_orders_ibfk_3` FOREIGN KEY (`plumber_id`) REFERENCES `tbl_plumbers` (`plumber_id`);
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
