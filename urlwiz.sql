
--
-- Table structure for table `tag`
--

CREATE TABLE IF NOT EXISTS `tag` (
  `tagid` int(10) unsigned NOT NULL COMMENT 'TAG ID',
  `tag` varchar(100) NOT NULL COMMENT 'Tag',
  PRIMARY KEY  (`tagid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- Table structure for table `url`
--

CREATE TABLE IF NOT EXISTS `url` (
  `url_id` int(10) unsigned NOT NULL COMMENT 'URL ID',
  `url` varchar(255) NOT NULL COMMENT 'Link (duh)',
  `tinyurl` varchar(50) NOT NULL COMMENT 'TinyURL for this link (if there was one generated)',
  `nick` varchar(32) NOT NULL COMMENT 'Who mentioned it?',
  `reffed` varchar(32) defaault NULL COMMENT 'Who was reffed?',
  `channel` varchar(32) NOT NULL COMMENT 'Where was it mentioned?',
  `date` int(10) unsigned NOT NULL COMMENT 'When was it mentioned',
  PRIMARY KEY  (`url_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- Table structure for table `urltag`
--

CREATE TABLE IF NOT EXISTS `urltag` (
  `url_id` int(10) unsigned NOT NULL,
  `tag_id` int(10) unsigned NOT NULL,
  PRIMARY KEY  (`url_id`,`tag_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

ALTER TABLE `urltag`
  ADD CONSTRAINT `urltag_ibfk_2` FOREIGN KEY (`tag_id`) REFERENCES `tag` (`tagid`) ON DELETE CASCADE,
  ADD CONSTRAINT `urltag_ibfk_1` FOREIGN KEY (`url_id`) REFERENCES `url` (`url_id`) ON DELETE CASCADE;
