-- phpMyAdmin SQL Dump
-- version 5.2.1
-- https://www.phpmyadmin.net/
--
-- Host: 127.0.0.1
-- Generation Time: Jul 21, 2025 at 04:22 PM
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
-- Table structure for table `tbl_chats`
--

CREATE TABLE `tbl_chats` (
  `chat_id` int(11) NOT NULL,
  `customer_id` int(11) NOT NULL,
  `plumber_id` int(11) NOT NULL,
  `message_id` int(11) DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` varchar(50) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `tbl_chats`
--

INSERT INTO `tbl_chats` (`chat_id`, `customer_id`, `plumber_id`, `message_id`, `created_at`, `updated_at`) VALUES
(9, 4, 1, NULL, '2025-07-18 08:03:04', '');

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
  `thumbnail_path` varchar(255) NOT NULL,
  `sent_at` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `tbl_chat_messages`
--

INSERT INTO `tbl_chat_messages` (`message_id`, `chat_id`, `customer_id`, `plumber_id`, `sender`, `message`, `media_path`, `thumbnail_path`, `sent_at`) VALUES
(62, 9, 4, 1, 'customer', 'Hi po, ask lang po where na Po kayo?', '', '', '2025-07-18 08:03:20'),
(66, 9, 4, 1, 'customer', '', 'media_687a048ac16838.34750246.mp4', 'thumb_media_687a048ac16838.34750246.jpg', '2025-07-18 08:23:41'),
(68, 9, 4, 1, 'customer', '', 'media_687a05d9189710.36111976.jpg', '', '2025-07-18 08:29:13'),
(69, 9, 4, 1, 'plumber', 'malapit na teh wait ka lang', '', '', '2025-07-18 09:40:13'),
(70, 9, 4, 1, 'plumber', 'malapit n me', '', '', '2025-07-18 09:40:37'),
(71, 9, 4, 1, 'plumber', '', 'media_687a16b08d5fe6.48531206.jpg', '', '2025-07-18 09:41:04');

-- --------------------------------------------------------

--
-- Table structure for table `tbl_clw_accounts`
--

CREATE TABLE `tbl_clw_accounts` (
  `clw_account_id` int(11) NOT NULL,
  `account_number` varchar(16) NOT NULL,
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
(1, '2022307171', 'Raj Tuyay', 12346, 1, 'Home', '123 Ermitanyo St.', 'San Jose', 'San Simon', 'Pampanga', '2025-06-04 13:18:14', '0000-00-00 00:00:00'),
(5, 'AC14-0706-1628', 'JM Simbulan', 10412, 4, 'Home', '212 Impyerno St', 'Sta. Cruz', 'San Simon', 'Pampanga', '2025-06-05 14:19:47', '2025-07-02 14:17:30'),
(6, 'AC14-0706-1629', 'Dodge Aaron Centeno', 12347, 1, 'Work', 'Silangan St.', 'Sta. Monica', 'San Simon', 'Pampanga', '2025-06-16 12:59:19', '0000-00-00 00:00:00'),
(11, 'AC12-3456-7890', 'Dodge Aaron Centeno', 10421, 3, 'Home', '132', 'San Pablo Libutad', 'San Simon', 'Pampanga', '2025-07-16 10:33:00', NULL),
(12, 'AC12-1234-1234', 'Aisha Barizo', 12345, 5, 'Home', '112', 'San Nicolas', 'San Simon', 'Pampanga', '2025-07-16 10:51:46', NULL);

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
  `profile_image` varchar(255) DEFAULT 'default.jpg',
  `fcm_token` varchar(255) DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `tbl_customers`
--

INSERT INTO `tbl_customers` (`customer_id`, `aquafix_no`, `username`, `password`, `email`, `first_name`, `last_name`, `contact_no`, `birthday`, `gender`, `profile_image`, `fcm_token`, `created_at`, `updated_at`) VALUES
(1, 'AQUA-20250604-5G8KX', 'rajtuyay', '$2y$10$9XA2qtlJlGzpc0FYZbxTfeQgh//IofCvCP4n9E1q596UrniNZckb2', 'rajtuyay24@gmail.com', 'Raj', 'Tuyay', '09352811980', '2004-08-24', 'Male', 'profile.jpg', 'c5w3oM0nSFOO_GeWtuf9Df:APA91bEgCTh_W1XrakAFmWPpWc_9UjoFRd5EOopIOL6kEGuXf-M2j5WXdgWPimeuNdolvkGmN1gvHBo_Zten_mTqM2dURF_wvZ6MejdrGcU9RN7YdiQqgwU', '2025-06-04 15:37:48', '2025-06-04 15:37:48'),
(3, 'AQUA-20250605-A31PW', 'rapidash', '$2y$10$y722kVubwosnT.wCu4yzgO/.Y4F9a5ThivcXWU59JByn6OlUzwb56', 'dodgeaaron@gmail.com', 'Aaron', 'Centeno', '+639123456789', '2025-07-13', 'Male', 'profile_3_68736fa279a3b.jpg', 'c5w3oM0nSFOO_GeWtuf9Df:APA91bEgCTh_W1XrakAFmWPpWc_9UjoFRd5EOopIOL6kEGuXf-M2j5WXdgWPimeuNdolvkGmN1gvHBo_Zten_mTqM2dURF_wvZ6MejdrGcU9RN7YdiQqgwU', '2025-06-05 02:08:37', '2025-06-05 02:08:37'),
(4, 'AQUA-20250605-3RE3W', 'jeyem', '$2y$10$p21wtoczwZ0oks43L/1OiuanHj6QelXxwqx3GnC1xwKlwO1xdoHx2', 'Simbulanjohnmichael.10@gmail.com', 'John Michael', 'Simbulan', '+639123456789', '2003-07-10', 'Male', 'jm_pfp.jpg', 'c5w3oM0nSFOO_GeWtuf9Df:APA91bEgCTh_W1XrakAFmWPpWc_9UjoFRd5EOopIOL6kEGuXf-M2j5WXdgWPimeuNdolvkGmN1gvHBo_Zten_mTqM2dURF_wvZ6MejdrGcU9RN7YdiQqgwU', '2025-06-05 02:22:25', '2025-06-05 02:22:25'),
(5, 'AQUA-20250605-4E0E0', 'aishamae', '$2y$10$0XsUYuLud/UiMDPuAL0XkOq5FAKsOrNJXC9CWFl7dRwmn3.DBko/G', 'aisha12@gmail.com', 'Aisha Mae', 'Barizo', '+639123456789', '2004-08-24', 'Female', 'aisha_pfp.jpg', 'c5w3oM0nSFOO_GeWtuf9Df:APA91bEgCTh_W1XrakAFmWPpWc_9UjoFRd5EOopIOL6kEGuXf-M2j5WXdgWPimeuNdolvkGmN1gvHBo_Zten_mTqM2dURF_wvZ6MejdrGcU9RN7YdiQqgwU', '2025-06-05 02:44:28', '2025-06-05 02:44:28'),
(6, 'AQUA-20250702-074ED', 'jm', '$2y$10$NKhRKgxSzVgLZy0Qs7pO0u5eVOrVglhU7Y405Ddg/P60zQk07HE2m', 'simbulan.jm10@gmail.com', 'John Michael', 'Simbulan', '+639929956392', '2003-07-10', 'Male', 'default.jpg', NULL, '2025-07-02 13:34:34', '2025-07-02 13:34:34');

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
(1, 'JO25-0510-0001', 1, 5, 1, 'Busted Pipe', '2025-06-05', '20:48:45', 'Pakicheck po asap', 'Cancelled', '2025-06-05 14:21:50'),
(2, 'JO25-0512-0002', 1, 1, 1, 'Change Meter', '2025-06-15', '10:31:21', 'Feel ko may sira sya teh, taas ng reading nya!', 'Cancelled', '2025-06-16 12:17:29'),
(3, 'JO25-0514-0003', 5, 1, 1, 'Busted Pipe', '2025-06-16', '12:13:49', 'ISA PAAAAA', 'Dispatched', '2025-06-16 12:24:04'),
(4, 'JO25-0516-0004', 3, 1, 1, 'Busted Mainline', '2025-06-16', '01:12:47', 'KAINIS', 'Accomplished', '2025-06-16 12:25:14'),
(5, 'JO25-0516-0005', 4, 6, 1, 'Busted Pipe', '2025-06-16', '15:02:00', 'LAST NA PO HEHE', 'Dispatched', '2025-06-16 13:02:07'),
(7, 'JO25-0702-0007', 4, 5, 1, 'Busted Pipe', '2025-07-02', '09:34:00', '', 'Dispatched', '2025-07-02 07:34:43'),
(9, 'JO25-0702-0009', 1, 5, 1, 'Busted Pipe', '2025-07-02', '16:20:00', 'TRYYYYY', 'Dispatched', '2025-07-02 14:20:55');

-- --------------------------------------------------------

--
-- Table structure for table `tbl_jo_media`
--

CREATE TABLE `tbl_jo_media` (
  `jo_media_id` int(11) NOT NULL,
  `job_order_id` int(11) NOT NULL,
  `media_type` enum('image','video') NOT NULL,
  `file_path` varchar(100) NOT NULL,
  `uploaded_at` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `tbl_jo_media`
--

INSERT INTO `tbl_jo_media` (`jo_media_id`, `job_order_id`, `media_type`, `file_path`, `uploaded_at`) VALUES
(1, 7, 'image', 'jo12_6869eeaf0bc58.jpg', '2025-07-06 03:34:07'),
(2, 7, 'video', 'jo12_6869eeaf65018.mp4', '2025-07-06 03:34:07');

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
  `profile_image` text NOT NULL DEFAULT 'logo.png',
  `address` text NOT NULL,
  `availability_status` enum('available','not available') NOT NULL,
  `created_at` datetime NOT NULL DEFAULT current_timestamp(),
  `updated_at` datetime NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `tbl_plumbers`
--

INSERT INTO `tbl_plumbers` (`plumber_id`, `aquafix_no`, `username`, `password`, `email`, `first_name`, `last_name`, `contact_no`, `birthday`, `gender`, `profile_image`, `address`, `availability_status`, `created_at`, `updated_at`) VALUES
(1, 'AQUA-20250605-3RE3H', 'rajieee', '$2y$10$JtsVaw.AgCdadROHnTQR7.9VHOabbiIAMlP3439K9BA3D2Nwm6gqW', 'rajtuyay24@gmail.com', 'Raj', 'Tuyay', '+639352811980', '2004-08-24', 'Male', 'rajie_pfp.jpg', 'San Jose, San Simon, Pampanga', 'available', '2025-06-13 15:40:33', '2025-06-13 15:40:57'),
(2, 'AQUA-20250618-A3RF6', 'erza', '$2y$10$0XsUYuLud/UiMDPuAL0XkOq5FAKsOrNJXC9CWFl7dRwmn3.DBko/G', 'aisha12@gmail.com', 'Aisha Mae', 'Barizo', '9123456789', '2004-07-09', 'Female', 'logo.png', 'San Jose, San Simon, Pampanga', 'available', '2025-06-18 16:49:16', '2025-06-18 16:49:16');

-- --------------------------------------------------------

--
-- Table structure for table `tbl_ratings`
--

CREATE TABLE `tbl_ratings` (
  `rating_id` int(11) NOT NULL,
  `job_order_id` int(11) NOT NULL,
  `customer_id` int(11) NOT NULL,
  `plumber_id` int(11) NOT NULL,
  `ratings` int(1) NOT NULL,
  `comment` text NOT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `tbl_ratings`
--

INSERT INTO `tbl_ratings` (`rating_id`, `job_order_id`, `customer_id`, `plumber_id`, `ratings`, `comment`, `created_at`) VALUES
(1, 1, 4, 1, 5, 'Mabilis gumawa at talagang magaling!', '2025-06-13 07:42:34'),
(5, 4, 4, 1, 5, '', '2025-07-02 07:46:37'),
(6, 9, 6, 1, 1, 'shonget', '2025-07-02 14:26:48'),
(7, 7, 4, 1, 5, '', '2025-07-18 06:39:05');

-- --------------------------------------------------------

--
-- Table structure for table `tbl_report`
--

CREATE TABLE `tbl_report` (
  `report_id` int(11) NOT NULL,
  `job_order_id` int(11) NOT NULL,
  `plumber_id` int(11) NOT NULL,
  `root_cause` varchar(255) DEFAULT NULL,
  `date_time_started` datetime DEFAULT NULL,
  `date_time_finished` datetime DEFAULT NULL,
  `date_time_returned` datetime DEFAULT NULL,
  `status` varchar(32) DEFAULT NULL,
  `remarks` text DEFAULT NULL,
  `created_at` datetime DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `tbl_report`
--

INSERT INTO `tbl_report` (`report_id`, `job_order_id`, `plumber_id`, `root_cause`, `date_time_started`, `date_time_finished`, `date_time_returned`, `status`, `remarks`, `created_at`) VALUES
(1, 9, 1, 'Pipe Leakage', '2025-06-26 10:31:13', '2025-06-26 10:31:13', '2025-06-26 10:31:13', 'Accomplished', 'Done', '2025-07-10 19:05:33');

-- --------------------------------------------------------

--
-- Table structure for table `tbl_report_materials`
--

CREATE TABLE `tbl_report_materials` (
  `report_material_id` int(11) NOT NULL,
  `report_id` int(11) NOT NULL,
  `material` varchar(64) DEFAULT NULL,
  `size` varchar(32) DEFAULT NULL,
  `qty` int(11) DEFAULT NULL,
  `unit_price` decimal(10,2) DEFAULT NULL,
  `total_price` decimal(10,2) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `tbl_report_materials`
--

INSERT INTO `tbl_report_materials` (`report_material_id`, `report_id`, `material`, `size`, `qty`, `unit_price`, `total_price`) VALUES
(1, 1, 'Nipple', '2 3/4', 1, 20.00, 20.00);

-- --------------------------------------------------------

--
-- Table structure for table `tbl_report_media`
--

CREATE TABLE `tbl_report_media` (
  `report_media_id` int(11) NOT NULL,
  `report_id` int(11) NOT NULL,
  `media_type` varchar(16) DEFAULT NULL,
  `file_path` varchar(255) DEFAULT NULL,
  `uploaded_at` datetime DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `tbl_report_media`
--

INSERT INTO `tbl_report_media` (`report_media_id`, `report_id`, `media_type`, `file_path`, `uploaded_at`) VALUES
(1, 1, 'video', 'report1_686f9e7dcfb8c.mp4', '2025-07-10 19:05:33');

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
(10, 5, 2025, 'Jan', 20, 34.7, 681, 'N/A', '2025-06-18 07:06:58'),
(12, 6, 2025, 'Jun', 10, 33.4, 334, 'N/A', '2025-07-02 14:28:57'),
(13, 6, 2025, 'May', 5, 33.4, 167, 'N/A', '2025-07-02 14:29:47'),
(14, 6, 2025, 'Jul', 4, 34.4, 167, '-50.0%', '2025-07-02 14:31:15');

--
-- Indexes for dumped tables
--

--
-- Indexes for table `tbl_chats`
--
ALTER TABLE `tbl_chats`
  ADD PRIMARY KEY (`chat_id`),
  ADD KEY `FOREIGN` (`customer_id`) USING BTREE,
  ADD KEY `FOREIGN3` (`plumber_id`) USING BTREE,
  ADD KEY `FOREIGN2` (`message_id`) USING BTREE;

--
-- Indexes for table `tbl_chat_messages`
--
ALTER TABLE `tbl_chat_messages`
  ADD PRIMARY KEY (`message_id`),
  ADD KEY `FOREIGN` (`chat_id`) USING BTREE,
  ADD KEY `FOREIGN2` (`customer_id`) USING BTREE,
  ADD KEY `FOREIGN3` (`plumber_id`) USING BTREE;

--
-- Indexes for table `tbl_clw_accounts`
--
ALTER TABLE `tbl_clw_accounts`
  ADD PRIMARY KEY (`clw_account_id`),
  ADD UNIQUE KEY `UNIQUE` (`account_number`),
  ADD UNIQUE KEY `UNIQUE2` (`meter_no`),
  ADD KEY `FOREIGN` (`customer_id`) USING BTREE;

--
-- Indexes for table `tbl_customers`
--
ALTER TABLE `tbl_customers`
  ADD PRIMARY KEY (`customer_id`),
  ADD UNIQUE KEY `UNIQUE` (`aquafix_no`) USING BTREE,
  ADD UNIQUE KEY `UNIQUE2` (`username`),
  ADD UNIQUE KEY `UNIQUE3` (`email`);

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
-- Indexes for table `tbl_jo_media`
--
ALTER TABLE `tbl_jo_media`
  ADD PRIMARY KEY (`jo_media_id`),
  ADD KEY `FOREIGN` (`job_order_id`);

--
-- Indexes for table `tbl_otps`
--
ALTER TABLE `tbl_otps`
  ADD PRIMARY KEY (`otp_id`);

--
-- Indexes for table `tbl_plumbers`
--
ALTER TABLE `tbl_plumbers`
  ADD PRIMARY KEY (`plumber_id`),
  ADD UNIQUE KEY `UNIQUE1` (`username`),
  ADD UNIQUE KEY `UNIQUE2` (`email`),
  ADD UNIQUE KEY `UNIQUE3` (`aquafix_no`);

--
-- Indexes for table `tbl_ratings`
--
ALTER TABLE `tbl_ratings`
  ADD PRIMARY KEY (`rating_id`),
  ADD KEY `FOREIGN` (`customer_id`) USING BTREE,
  ADD KEY `FOREIGN2` (`job_order_id`) USING BTREE,
  ADD KEY `FOREIGN3` (`plumber_id`) USING BTREE;

--
-- Indexes for table `tbl_report`
--
ALTER TABLE `tbl_report`
  ADD PRIMARY KEY (`report_id`),
  ADD KEY `job_order_id` (`job_order_id`),
  ADD KEY `plumber_id` (`plumber_id`);

--
-- Indexes for table `tbl_report_materials`
--
ALTER TABLE `tbl_report_materials`
  ADD PRIMARY KEY (`report_material_id`),
  ADD KEY `report_id` (`report_id`);

--
-- Indexes for table `tbl_report_media`
--
ALTER TABLE `tbl_report_media`
  ADD PRIMARY KEY (`report_media_id`),
  ADD KEY `report_id` (`report_id`);

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
-- AUTO_INCREMENT for table `tbl_chats`
--
ALTER TABLE `tbl_chats`
  MODIFY `chat_id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=10;

--
-- AUTO_INCREMENT for table `tbl_chat_messages`
--
ALTER TABLE `tbl_chat_messages`
  MODIFY `message_id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=72;

--
-- AUTO_INCREMENT for table `tbl_clw_accounts`
--
ALTER TABLE `tbl_clw_accounts`
  MODIFY `clw_account_id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=13;

--
-- AUTO_INCREMENT for table `tbl_customers`
--
ALTER TABLE `tbl_customers`
  MODIFY `customer_id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=8;

--
-- AUTO_INCREMENT for table `tbl_job_orders`
--
ALTER TABLE `tbl_job_orders`
  MODIFY `job_order_id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=35;

--
-- AUTO_INCREMENT for table `tbl_jo_media`
--
ALTER TABLE `tbl_jo_media`
  MODIFY `jo_media_id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=48;

--
-- AUTO_INCREMENT for table `tbl_otps`
--
ALTER TABLE `tbl_otps`
  MODIFY `otp_id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=22;

--
-- AUTO_INCREMENT for table `tbl_plumbers`
--
ALTER TABLE `tbl_plumbers`
  MODIFY `plumber_id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=3;

--
-- AUTO_INCREMENT for table `tbl_ratings`
--
ALTER TABLE `tbl_ratings`
  MODIFY `rating_id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=8;

--
-- AUTO_INCREMENT for table `tbl_report`
--
ALTER TABLE `tbl_report`
  MODIFY `report_id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=2;

--
-- AUTO_INCREMENT for table `tbl_report_materials`
--
ALTER TABLE `tbl_report_materials`
  MODIFY `report_material_id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=2;

--
-- AUTO_INCREMENT for table `tbl_report_media`
--
ALTER TABLE `tbl_report_media`
  MODIFY `report_media_id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=2;

--
-- AUTO_INCREMENT for table `tbl_water_bills`
--
ALTER TABLE `tbl_water_bills`
  MODIFY `bill_id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=15;

--
-- Constraints for dumped tables
--

--
-- Constraints for table `tbl_chats`
--
ALTER TABLE `tbl_chats`
  ADD CONSTRAINT `tbl_chats_ibfk_1` FOREIGN KEY (`customer_id`) REFERENCES `tbl_customers` (`customer_id`),
  ADD CONSTRAINT `tbl_chats_ibfk_2` FOREIGN KEY (`message_id`) REFERENCES `tbl_chat_messages` (`message_id`),
  ADD CONSTRAINT `tbl_chats_ibfk_3` FOREIGN KEY (`plumber_id`) REFERENCES `tbl_plumbers` (`plumber_id`);

--
-- Constraints for table `tbl_chat_messages`
--
ALTER TABLE `tbl_chat_messages`
  ADD CONSTRAINT `tbl_chat_messages_ibfk_1` FOREIGN KEY (`chat_id`) REFERENCES `tbl_chats` (`chat_id`),
  ADD CONSTRAINT `tbl_chat_messages_ibfk_2` FOREIGN KEY (`customer_id`) REFERENCES `tbl_customers` (`customer_id`),
  ADD CONSTRAINT `tbl_chat_messages_ibfk_3` FOREIGN KEY (`plumber_id`) REFERENCES `tbl_plumbers` (`plumber_id`);

--
-- Constraints for table `tbl_clw_accounts`
--
ALTER TABLE `tbl_clw_accounts`
  ADD CONSTRAINT `tbl_clw_accounts_ibfk_1` FOREIGN KEY (`customer_id`) REFERENCES `tbl_customers` (`customer_id`);

--
-- Constraints for table `tbl_job_orders`
--
ALTER TABLE `tbl_job_orders`
  ADD CONSTRAINT `tbl_job_orders_ibfk_1` FOREIGN KEY (`clw_account_id`) REFERENCES `tbl_clw_accounts` (`clw_account_id`),
  ADD CONSTRAINT `tbl_job_orders_ibfk_2` FOREIGN KEY (`customer_id`) REFERENCES `tbl_customers` (`customer_id`),
  ADD CONSTRAINT `tbl_job_orders_ibfk_3` FOREIGN KEY (`plumber_id`) REFERENCES `tbl_plumbers` (`plumber_id`);

--
-- Constraints for table `tbl_jo_media`
--
ALTER TABLE `tbl_jo_media`
  ADD CONSTRAINT `FOREIGN` FOREIGN KEY (`job_order_id`) REFERENCES `tbl_job_orders` (`job_order_id`);

--
-- Constraints for table `tbl_ratings`
--
ALTER TABLE `tbl_ratings`
  ADD CONSTRAINT `tbl_ratings_ibfk_1` FOREIGN KEY (`job_order_id`) REFERENCES `tbl_job_orders` (`job_order_id`),
  ADD CONSTRAINT `tbl_ratings_ibfk_2` FOREIGN KEY (`customer_id`) REFERENCES `tbl_customers` (`customer_id`),
  ADD CONSTRAINT `tbl_ratings_ibfk_3` FOREIGN KEY (`plumber_id`) REFERENCES `tbl_plumbers` (`plumber_id`);

--
-- Constraints for table `tbl_report`
--
ALTER TABLE `tbl_report`
  ADD CONSTRAINT `tbl_report_ibfk_1` FOREIGN KEY (`job_order_id`) REFERENCES `tbl_job_orders` (`job_order_id`),
  ADD CONSTRAINT `tbl_report_ibfk_2` FOREIGN KEY (`plumber_id`) REFERENCES `tbl_plumbers` (`plumber_id`);

--
-- Constraints for table `tbl_report_materials`
--
ALTER TABLE `tbl_report_materials`
  ADD CONSTRAINT `tbl_report_materials_ibfk_1` FOREIGN KEY (`report_id`) REFERENCES `tbl_report` (`report_id`);

--
-- Constraints for table `tbl_report_media`
--
ALTER TABLE `tbl_report_media`
  ADD CONSTRAINT `tbl_report_media_ibfk_1` FOREIGN KEY (`report_id`) REFERENCES `tbl_report` (`report_id`);

--
-- Constraints for table `tbl_water_bills`
--
ALTER TABLE `tbl_water_bills`
  ADD CONSTRAINT `tbl_water_bills_ibfk_1` FOREIGN KEY (`customer_id`) REFERENCES `tbl_customers` (`customer_id`);
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
