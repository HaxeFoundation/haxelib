CREATE TABLE `Developer` (
  `user` int(11) NOT NULL,
  `project` int(11) NOT NULL,
  `id` int(11) NOT NULL AUTO_INCREMENT,
  PRIMARY KEY (`user`,`project`),
  KEY `Developer_project` (`project`),
  KEY `id` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
