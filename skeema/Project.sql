CREATE TABLE `Project` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `name` mediumtext NOT NULL,
  `description` mediumtext NOT NULL,
  `website` mediumtext NOT NULL,
  `license` mediumtext NOT NULL,
  `downloads` int(11) NOT NULL,
  `owner` int(11) NOT NULL,
  `version` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `Project_owner` (`owner`),
  KEY `Project_version` (`version`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
