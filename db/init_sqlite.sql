-- 
-- Created by SQL::Translator::Producer::SQLite
-- Created on Thu Jun 28 19:10:41 2012
-- 

BEGIN TRANSACTION;

--
-- Table: post
--
CREATE TABLE post (
  id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
  text text NOT NULL,
  tags varchar(331) NOT NULL DEFAULT '',
  -- ex. | AA BB CC |
  nickname varchar(32) NOT NULL,
  user_key varchar(64) NOT NULL,
  profile_image_url varchar(128) NOT NULL,
  profile_url varchar(128) NOT NULL,
  plusplus int(10) NOT NULL DEFAULT 0,
  created_at_ms bigint(20) NOT NULL
);

--
-- Table: user
--
CREATE TABLE user (
  user_key varchar(64) NOT NULL,
  nickname varchar(32) NOT NULL,
  profile_image_url varchar(128) NOT NULL,
  profile_url varchar(128) NOT NULL,
  sns_data_cache blob NOT NULL,
  created_at datetime NOT NULL,
  updated_at datetime NOT NULL,
  PRIMARY KEY (user_key)
);

--
-- Table: session
--
CREATE TABLE session (
  token varchar(64) NOT NULL,
  user_key varchar(64) NOT NULL,
  expire_at datetime NOT NULL,
  PRIMARY KEY (token)
);

COMMIT;
