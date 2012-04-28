use strict;
use warnings;
use Plack::Request;

use FindBin;
use lib ("$FindBin::Bin/lib");
use Yairc::DB;
use Yairc::API::Search;


my $dbh = Yairc::DB->new('yairc');
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



