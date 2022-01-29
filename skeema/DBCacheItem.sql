CREATE TABLE `DBCacheItem` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `created` datetime NOT NULL,
  `modified` datetime NOT NULL,
  `namespace` varchar(255) NOT NULL,
  `cacheID` varchar(255) NOT NULL,
  `data` mediumblob NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `DBCacheItem_namespace_cacheID` (`namespace`,`cacheID`),
  KEY `DBCacheItem_namespace` (`namespace`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
