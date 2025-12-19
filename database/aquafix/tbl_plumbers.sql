-- phpMyAdmin SQL Dump
-- version 5.2.1
-- https://www.phpmyadmin.net/
--
-- Host: 127.0.0.1
-- Generation Time: Jul 02, 2025 at 08:16 AM
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
-- Table structure for table `tbl_plumbers`
--

CREATE TABLE `tbl_plumbers` (
  `plumber_id` int(11) NOT NULL,
  `aquafix_no` varchar(20) NOT NULL,
  `username` varchar(30) NOT NULL,
  `password` varchar(255) NOT NULL,
  `email` varchar(50) NOT NULL,
  `first_name` varchar(50) NOT NULL,
  `last_name` varchar(30) NOT NULL,
  `contact_no` varchar(13) NOT NULL,
  `birthday` date NOT NULL,
  `gender` varchar(6) NOT NULL,
  `profile_image` text NOT NULL,
  `address` text NOT NULL,
  `availability_status` enum('available','not available') NOT NULL,
  `created_at` datetime NOT NULL DEFAULT current_timestamp(),
  `updated_at` datetime NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `tbl_plumbers`
--

INSERT INTO `tbl_plumbers` (`plumber_id`, `aquafix_no`, `username`, `password`, `email`, `first_name`, `last_name`, `contact_no`, `birthday`, `gender`, `profile_image`, `address`, `availability_status`, `created_at`, `updated_at`) VALUES
(1, 'AQUA-20250605-3RE3H', 'rajieee', '$2y$10$JtsVaw.AgCdadROHnTQR7.9VHOabbiIAMlP3439K9BA3D2Nwm6gqW', 'rajtuyay24@gmail.com', 'Raj', 'Tuyay', '+639352811980', '2004-08-24', 'Male', 'logo.png', 'San Jose, San Simon, Pampanga', 'available', '2025-06-13 15:40:33', '2025-06-13 15:40:57'),
(2, 'AQUA-20250618-A3RF6', 'Erza', '$2y$10$0XsUYuLud/UiMDPuAL0XkOq5FAKsOrNJXC9CWFl7dRwmn3.DBko/G', 'aisha12@gmail.com', 'Aisha Mae', 'Barizo', '9123456789', '2004-07-09', 'Female', 'logo.png', 'San Jose, San Simon, Pampanga', 'available', '2025-06-18 16:49:16', '0000-00-00 00:00:00');

--
-- Indexes for dumped tables
--

--
-- Indexes for table `tbl_plumbers`
--
ALTER TABLE `tbl_plumbers`
  ADD PRIMARY KEY (`plumber_id`),
  ADD UNIQUE KEY `UNIQUE1` (`username`),
  ADD UNIQUE KEY `UNIQUE2` (`email`),
  ADD UNIQUE KEY `UNIQUE3` (`aquafix_no`);

--
-- AUTO_INCREMENT for dumped tables
--

--
-- AUTO_INCREMENT for table `tbl_plumbers`
--
ALTER TABLE `tbl_plumbers`
  MODIFY `plumber_id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=3;
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
