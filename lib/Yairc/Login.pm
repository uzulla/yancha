package Yairc::Login;

use strict;
use warnings;

use Plack::Builder;
use FindBin;
use lib ("$FindBin::Bin/lib");

use Yairc::Login::Twitter;

my $dbh = Yairc::DB->new('yairc');

my $user_insert_or_update = $dbh->prepare('INSERT INTO `user` (`user_key`,`nickname`,`profile_image_url`,`sns_data_cache`,`token`,`created_at`,`updated_at`) VALUES (?, ?, ?, ?, ?, now(), now()) ON DUPLICATE KEY UPDATE `sns_data_cache`=values(`sns_data_cache`),`nickname`=values(`nickname`),`profile_image_url`=values(`profile_image_url`),`updated_at`=now();');
my $user_select_by_user_key  = $dbh->prepare('SELECT * FROM `user` WHERE `user_key`=? ');

sub user_info_set {
  my ($self, $user_key,$nickname,$profile_image_url,$sns_data_cache) = @_;
  my $ug = new Data::UUID;
  my $token = $ug->create_str();
  $user_insert_or_update->execute( $user_key,$nickname,$profile_image_url,$sns_data_cache,$token );

  $user_select_by_user_key->execute( $user_key );
  my $user = $user_select_by_user_key->fetchrow_hashref();

  my $rtntoken = $user->{token};

  return $rtntoken;
}

sub new{
  return builder {
    mount '/twitter' => Yairc::Login::Twitter->new;
  }
}

1;