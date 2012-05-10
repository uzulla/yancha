DROP TABLE IF EXISTS `post`;
CREATE TABLE IF NOT EXISTS `post` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `text` text NOT NULL,
  `tags` varchar(331) NOT NULL DEFAULT '', -- ex. | AA BB CC |
  `nickname` varchar(32) NOT NULL,
  `user_key` varchar(64) NOT NULL,
  `profile_image_url` varchar(128) NOT NULL,
  `created_at_ms` bigint(20) unsigned NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB  DEFAULT CHARSET=utf8 AUTO_INCREMENT=1 ;

DROP TABLE IF EXISTS `user`;
CREATE TABLE IF NOT EXISTS `user` (
  `user_key` varchar(64) NOT NULL,
  `token` varchar(64) NOT NULL,
  `nickname` varchar(32) NOT NULL,
  `profile_image_url` varchar(128) NOT NULL,
  `sns_data_cache` blob NOT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  PRIMARY KEY (`user_key`),
  UNIQUE KEY `token` (`token`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

