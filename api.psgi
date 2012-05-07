
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
use Yairc::API::Search;
use Yairc::DataStorage::DBI;
use Yairc::Config::Simple;

my $config = Yairc::Config::Simple->load_file( $ENV{ YAIRC_CONFIG_FILE } || "$root/config.pl" );
my $data_storage = Yairc::DataStorage::DBI->connect( connect_info => $config->{ database }->{ connect_info } );

my $api = Yairc::API::Search->new( data_storage => $data_storage );

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



