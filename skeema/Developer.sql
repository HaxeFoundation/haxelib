CREATE TABLE `Developer` (
  `user` int(11) NOT NULL,
  `project` int(11) NOT NULL,
  PRIMARY KEY (`user`,`project`),
  KEY `Developer_project` (`project`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
