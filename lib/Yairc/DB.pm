package Yairc::DB;

use strict;
use warnings;
use DBI;
use Config::Pit;

sub new {
    my ($self, $name) = @_;

    $name ||= 'yairc';
    my $config = pit_get( $name, require => {
            "dsn" => "dsn",
            "db_user" => "db username",
            "db_pass" => "db password"
        });

    my $dbh = DBI->connect(
            $config->{dsn},
            $config->{db_user},
            $config->{db_pass},
            {
                mysql_enable_utf8 => 1 ,
                mysql_auto_reconnect => 1,
                RaiseError => 1,
            }
    ) || die DBI::errstr; #plz change

    return $dbh;
}

1;
