CREATE TABLE `Version` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `major` int(11) NOT NULL,
  `minor` int(11) NOT NULL,
  `patch` int(11) NOT NULL,
  `preview` tinyint(3) unsigned DEFAULT NULL,
  `previewNum` int(11) DEFAULT NULL,
  `date` mediumtext NOT NULL,
  `comments` mediumtext NOT NULL,
  `downloads` int(11) NOT NULL,
  `documentation` mediumtext,
  `project` int(11) NOT NULL,
  PRIMARY KEY (`id`),
  KEY `Version_project` (`project`),
  CONSTRAINT `Version_projectObj` FOREIGN KEY (`project`) REFERENCES `Project` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
