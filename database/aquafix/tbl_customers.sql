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
-- Table structure for table `tbl_customers`
--

CREATE TABLE `tbl_customers` (
  `customer_id` int(11) NOT NULL,
  `aquafix_no` varchar(50) NOT NULL,
  `username` varchar(25) NOT NULL,
  `password` varchar(255) NOT NULL,
  `email` varchar(50) NOT NULL,
  `first_name` varchar(25) NOT NULL,
  `last_name` varchar(25) NOT NULL,
  `contact_no` varchar(15) NOT NULL,
  `birthday` varchar(50) NOT NULL,
  `gender` varchar(6) NOT NULL,
  `profile_image` varchar(255) NOT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` varchar(50) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `tbl_customers`
--

INSERT INTO `tbl_customers` (`customer_id`, `aquafix_no`, `username`, `password`, `email`, `first_name`, `last_name`, `contact_no`, `birthday`, `gender`, `profile_image`, `created_at`, `updated_at`) VALUES
(1, 'AQUA-20250604-5G8KX', 'rajtuyay', '$2y$10$9XA2qtlJlGzpc0FYZbxTfeQgh//IofCvCP4n9E1q596UrniNZckb2', 'rajtuyay24@gmail.com', 'Raj', 'Tuyay', '09352811980', '2004-08-24', 'Male', 'profile.jpg', '2025-06-04 15:37:48', ''),
(3, '', 'rapidash', '$2y$10$977zvyDrWdoyWlzsCrjKjuMCG/6KRSxSnkoJ6oZCyVkTcvKr3OY..', 'ralphdennis04@gmail.com', 'Aaron', 'Centeno', '+639123456789', '', '', '', '2025-06-05 02:08:37', ''),
(4, 'AQUA-20250605-3RE3W', 'jeyem', '$2y$10$p21wtoczwZ0oks43L/1OiuanHj6QelXxwqx3GnC1xwKlwO1xdoHx2', 'Simbulanjohnmichael.10@gmail.com', 'John Michael', 'Simbulan', '+639123456789', '2003-07-10', 'Male', 'profile.jpg', '2025-06-05 02:22:25', ''),
(5, 'AQUA-20250605-4E0E0', 'Erza', '$2y$10$Afp2FK0KJq7.dpDDKPZdXOMr6TGg9//DVC24pIMNewO1QrP.nnqam', 'aisha12@gmail.com', 'Aisha Mae', 'Barizo', '+639123456789', '2004-08-24', 'Female', '', '2025-06-05 02:44:28', '');

--
-- Indexes for dumped tables
--

--
-- Indexes for table `tbl_customers`
--
ALTER TABLE `tbl_customers`
  ADD PRIMARY KEY (`customer_id`),
  ADD UNIQUE KEY `UNIQUE` (`aquafix_no`) USING BTREE,
  ADD UNIQUE KEY `UNIQUE2` (`username`),
  ADD UNIQUE KEY `UNIQUE3` (`email`);

--
-- AUTO_INCREMENT for dumped tables
--

--
-- AUTO_INCREMENT for table `tbl_customers`
--
ALTER TABLE `tbl_customers`
  MODIFY `customer_id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=6;
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
