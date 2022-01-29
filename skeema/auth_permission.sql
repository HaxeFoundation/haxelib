CREATE TABLE `auth_permission` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `created` datetime NOT NULL,
  `modified` datetime NOT NULL,
  `permission` varchar(255) NOT NULL,
  `groupID` int(10) unsigned DEFAULT NULL,
  `userID` int(10) unsigned DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `auth_permission_permission_userID` (`permission`,`userID`),
  UNIQUE KEY `auth_permission_permission_groupID` (`permission`,`groupID`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
