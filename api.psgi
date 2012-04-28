use strict;
use warnings;
use Plack::Request;
use FindBin;
use lib ("$FindBin::Bin/lib");
use Yairc;
use Yairc::API::Search;
use Config::Pit;


my $config = pit_get( "yairc", require => {
       "dsn" => "dsn",
       "db_user" => "db username",
       "db_pass" => "db password"
});


my $dbh = DBI->connect($config->{dsn}, $config->{db_user}, $config->{db_pass}, { mysql_enable_utf8 => 1 })
        || die DBI::errstr; #plz change

my $api = Yairc::API::Search->new( dbh => $dbh );

sub {
    my $env = shift;
    my $req = Plack::Request->new($env);

    my $tag = $req->param('tag');
    $tag = ($tag) ? $tag:'';

    #パラメータの数値判定はYairc::API::Search->search()任せ
    my $limit = $req->param('limit');
    my @limit = split(',', $limit);

    my $res = $api->search(
                limit   => \@limit,
                tag     => $tag,
            );

    [   200,
        [
        'Content-Type'   => $res->{'content-type'},
        'Content-Length' => length($res->{'data'})
        ],
        [$res->{'data'}]
    ];
}



