CREATE TABLE `Developer` (
  `user` int(11) NOT NULL,
  `project` int(11) NOT NULL,
  PRIMARY KEY (`user`,`project`),
  KEY `Developer_project` (`project`),
  CONSTRAINT `Developer_projectObj` FOREIGN KEY (`project`) REFERENCES `Project` (`id`) ON DELETE CASCADE,
  CONSTRAINT `Developer_userObj` FOREIGN KEY (`user`) REFERENCES `User` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
