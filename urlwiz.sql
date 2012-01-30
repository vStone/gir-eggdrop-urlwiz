--
-- Table structure for table `tag`
--

CREATE TABLE `tag` (
  `tagid` int(10) unsigned NOT NULL AUTO_INCREMENT COMMENT 'TAG ID',
  `tag` varchar(100) NOT NULL COMMENT 'Tag',
  `count` int(10) unsigned NOT NULL DEFAULT '1',
  PRIMARY KEY (`tagid`),
  UNIQUE KEY `tag` (`tag`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8


-- --------------------------------------------------------

--
-- Table structure for table `url`
--

CREATE TABLE `url` (
  `url_id` int(10) unsigned NOT NULL AUTO_INCREMENT COMMENT 'URL ID',
  `url` varchar(255) NOT NULL COMMENT 'Link (duh)',
  `title` varchar(255) NOT NULL,
  `tinyurl` varchar(50) NOT NULL COMMENT 'TinyURL for this link (if there was one generated)',
  `nick` varchar(32) NOT NULL COMMENT 'Who mentioned it?',
  `reffed` varchar(32) DEFAULT NULL,
  `channel` varchar(32) NOT NULL COMMENT 'Where was it mentioned?',
  `date` int(10) unsigned NOT NULL COMMENT 'When was it mentioned',
  PRIMARY KEY (`url_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8


-- --------------------------------------------------------

--
-- Table structure for table `urltag`
--

CREATE TABLE `urltag` (
  `url_id` int(10) unsigned NOT NULL,
  `tag_id` int(10) unsigned NOT NULL,
  PRIMARY KEY (`url_id`,`tag_id`),
  KEY `tag_id` (`tag_id`),
  CONSTRAINT `urltag_ibfk_1` FOREIGN KEY (`url_id`) REFERENCES `url` (`url_id`) ON DELETE CASCADE,
  CONSTRAINT `urltag_ibfk_2` FOREIGN KEY (`tag_id`) REFERENCES `tag` (`tagid`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8
