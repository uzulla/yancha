
my $root;

BEGIN {
    use File::Basename ();
    use File::Spec     ();

    $root = File::Basename::dirname(__FILE__);
    $root = File::Spec->rel2abs($root);

    unshift @INC, "$root/../../lib";
}

use strict;
use warnings;
use Plack::Request;

use FindBin;
use lib ("$FindBin::Bin/lib");
use Yancha::API::Search;
use Yancha::DataStorage::DBI;
use Yancha::Config::Simple;

my $config = Yancha::Config::Simple->load_file( $ENV{ YAIRC_CONFIG_FILE } || "$root/config.pl" );
my $data_storage = Yancha::DataStorage::DBI->connect( connect_info => $config->{ database }->{ connect_info } );

my $api = Yancha::API::Search->new( data_storage => $data_storage );

sub {
    my $env = shift;
    my $req = Plack::Request->new($env);
    my $res = $api->search($req);

    [   200,
        [
        'Content-Type'   => $res->{'content-type'},
        'Content-Length' => length($res->{'data'})
        ],
        [$res->{'data'}]
    ];
}



