use strict;
use Yairc::API;

my $config = pit_get( "yairc", require => {
       "dsn" => "dsn",
       "db_user" => "db username",
       "db_pass" => "db password"
});

my $dbh = DBI->connect(
    $config->{dsn}, 
    $config->{db_user}, 
    $config->{db_pass}, 
    { 
        mysql_enable_utf8 => 1,
        mysql_auto_reconnect => 1,
        RaiseError => 1,
    }
);

{
    config => $config,
    dbh => $dbh,
    api => Yairc::API->new( dbh => $dbh ),
};
