CREATE TABLE `Tag` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `tag` mediumtext NOT NULL,
  `project` int(11) NOT NULL,
  PRIMARY KEY (`id`),
  KEY `Tag_project` (`project`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
