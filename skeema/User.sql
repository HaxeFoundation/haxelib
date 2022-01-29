CREATE TABLE `User` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `name` mediumtext NOT NULL,
  `fullname` mediumtext NOT NULL,
  `email` mediumtext NOT NULL,
  `pass` mediumtext NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
