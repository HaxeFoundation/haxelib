CREATE TABLE `auth_user` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `created` datetime NOT NULL,
  `modified` datetime NOT NULL,
  `username` varchar(40) NOT NULL,
  `salt` varchar(32) NOT NULL,
  `password` varchar(64) NOT NULL,
  `forcePasswordChange` tinyint(1) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `auth_user_username` (`username`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
