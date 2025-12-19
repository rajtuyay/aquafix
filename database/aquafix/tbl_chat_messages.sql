-- phpMyAdmin SQL Dump
-- version 5.2.1
-- https://www.phpmyadmin.net/
--
-- Host: 127.0.0.1
-- Generation Time: Jul 02, 2025 at 06:32 AM
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
-- Table structure for table `tbl_chat_messages`
--

CREATE TABLE `tbl_chat_messages` (
  `message_id` int(11) NOT NULL,
  `chat_id` int(11) NOT NULL,
  `customer_id` int(11) NOT NULL,
  `plumber_id` int(11) NOT NULL,
  `sender` enum('customer','plumber') NOT NULL,
  `message` text NOT NULL,
  `media_path` varchar(100) NOT NULL,
  `sent_at` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `tbl_chat_messages`
--

INSERT INTO `tbl_chat_messages` (`message_id`, `chat_id`, `customer_id`, `plumber_id`, `sender`, `message`, `media_path`, `sent_at`) VALUES
(1, 1, 4, 1, 'customer', 'San na po kayo?', '', '2025-06-13 08:01:46'),
(2, 1, 4, 1, 'plumber', 'Wait po, malapit na.', '', '2025-06-16 11:07:49'),
(3, 1, 4, 1, 'plumber', 'Nasa labas na po ako.', '', '2025-06-16 11:14:49'),
(4, 1, 4, 1, 'plumber', 'Baka po pwede pa awat nung aso po ninyo hehehe nakakatatot po kasi T_T', '', '2025-06-16 11:16:25'),
(5, 1, 4, 1, 'customer', 'Okay po', '', '2025-06-18 04:29:31'),
(6, 1, 4, 1, 'customer', 'Wait po ito na hehe', '', '2025-06-18 04:29:47');

--
-- Indexes for dumped tables
--

--
-- Indexes for table `tbl_chat_messages`
--
ALTER TABLE `tbl_chat_messages`
  ADD PRIMARY KEY (`message_id`),
  ADD KEY `FOREIGN` (`chat_id`) USING BTREE,
  ADD KEY `FOREIGN2` (`customer_id`) USING BTREE,
  ADD KEY `FOREIGN3` (`plumber_id`) USING BTREE;

--
-- AUTO_INCREMENT for dumped tables
--

--
-- AUTO_INCREMENT for table `tbl_chat_messages`
--
ALTER TABLE `tbl_chat_messages`
  MODIFY `message_id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=7;

--
-- Constraints for dumped tables
--

--
-- Constraints for table `tbl_chat_messages`
--
ALTER TABLE `tbl_chat_messages`
  ADD CONSTRAINT `tbl_chat_messages_ibfk_1` FOREIGN KEY (`chat_id`) REFERENCES `tbl_chats` (`chat_id`),
  ADD CONSTRAINT `tbl_chat_messages_ibfk_2` FOREIGN KEY (`customer_id`) REFERENCES `tbl_customers` (`customer_id`),
  ADD CONSTRAINT `tbl_chat_messages_ibfk_3` FOREIGN KEY (`plumber_id`) REFERENCES `tbl_plumbers` (`plumber_id`);
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
