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
-- Table structure for table `tbl_otps`
--

CREATE TABLE `tbl_otps` (
  `otp_id` int(11) NOT NULL,
  `email` varchar(100) NOT NULL,
  `otp` varchar(10) NOT NULL,
  `expires_at` datetime NOT NULL,
  `used` tinyint(1) NOT NULL DEFAULT 0,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `tbl_otps`
--

INSERT INTO `tbl_otps` (`otp_id`, `email`, `otp`, `expires_at`, `used`, `created_at`) VALUES
(1, 'rajtuyay24@gmail.com', '954340', '2025-06-26 10:11:09', 1, '2025-06-26 08:01:09'),
(2, 'rajtuyay24@gmail.com', '600666', '2025-06-26 10:14:03', 1, '2025-06-26 08:04:03'),
(3, 'rajtuyay24@gmail.com', '657725', '2025-06-26 10:31:13', 1, '2025-06-26 08:21:13'),
(4, 'rajtuyay24@gmail.com', '817670', '2025-06-26 10:32:47', 1, '2025-06-26 08:22:47'),
(5, 'rajtuyay24@gmail.com', '698826', '2025-06-26 10:32:54', 1, '2025-06-26 08:22:54'),
(6, 'rajtuyay24@gmail.com', '443241', '2025-06-26 10:33:06', 1, '2025-06-26 08:23:06'),
(7, 'rajtuyay24@gmail.com', '019756', '2025-06-26 10:46:11', 1, '2025-06-26 08:36:11'),
(8, 'rajtuyay24@gmail.com', '024505', '2025-06-26 10:46:20', 1, '2025-06-26 08:36:20'),
(9, 'rajtuyay24@gmail.com', '317159', '2025-06-26 10:48:34', 1, '2025-06-26 08:38:34'),
(10, 'rajtuyay24@gmail.com', '570181', '2025-06-26 11:16:44', 1, '2025-06-26 09:06:44'),
(11, 'rajtuyay24@gmail.com', '093465', '2025-06-26 11:22:48', 1, '2025-06-26 09:12:48'),
(12, 'rajtuyay24@gmail.com', '264866', '2025-06-26 17:28:19', 1, '2025-06-26 09:18:19'),
(13, 'jmsimbulan10@gmail.com', '580340', '2025-06-26 17:38:26', 0, '2025-06-26 09:28:26'),
(14, 'Simbulanjohnmichael.10@gmail.com', '734355', '2025-06-26 17:42:01', 0, '2025-06-26 09:32:01'),
(15, 'rajtuyay24@gmail.com', '785487', '2025-06-26 17:45:36', 1, '2025-06-26 09:35:36'),
(16, 'ralphdennis04@gmail.com', '032595', '2025-06-26 19:36:45', 1, '2025-06-26 11:26:45'),
(17, 'ralphdennis2004@gmail.com', '821964', '2025-06-26 19:38:41', 0, '2025-06-26 11:28:41'),
(18, 'rajtuyay24@gmail.com', '589940', '2025-06-26 19:40:31', 1, '2025-06-26 11:30:31'),
(19, 'ralphdennis04@gmail.com', '007270', '2025-06-26 19:42:55', 0, '2025-06-26 11:32:55'),
(20, 'rajtuyay24@gmail.com', '173092', '2025-06-29 20:08:26', 1, '2025-06-29 11:58:26'),
(21, 'rajtuyay24@gmail.com', '489742', '2025-07-02 12:54:46', 0, '2025-07-02 04:44:46');

--
-- Indexes for dumped tables
--

--
-- Indexes for table `tbl_otps`
--
ALTER TABLE `tbl_otps`
  ADD PRIMARY KEY (`otp_id`);

--
-- AUTO_INCREMENT for dumped tables
--

--
-- AUTO_INCREMENT for table `tbl_otps`
--
ALTER TABLE `tbl_otps`
  MODIFY `otp_id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=22;
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
