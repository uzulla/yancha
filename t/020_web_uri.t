use strict;
use warnings;
use utf8;
use t::Utils;
use Plack::Test;
use Plack::Util;
use Test::More;
use Yancha;
use Yancha::Web;
use Yancha::Config::Simple;
use Yancha::DataStorage::DBI;
use Plack::Builder;
use File::Copy::Recursive qw(dircopy);

my @test_uri = (
    ['/', 200],
    ['/quot', 200],
    ['/search', 200],
    ['/hints', 200],
    ['/about', 200],
    ['/login', 302]
);


my $config = Yancha::Config::Simple->load_file( "./config.pl.sample" );
my $testdb  = t::Utils->setup_testdb( schema => './db/init.sql' );
my $storage = Yancha::DataStorage::DBI->connect( connect_info => [ $testdb->dsn() ] );
my $sys= Yancha->new( config => $config, data_storage => $storage );

my $app = builder {
    $sys->build_psgi_endpoint_from_server_info('auth');
    mount '/' => Yancha::Web->run(%$config);
};

dircopy('./view', './t/view');
test_psgi
    app => $app,
    client => sub {
        my $cb = shift;
        
        for my$case ( @test_uri ) {
            my ($uri, $status) = @$case;
            my $req = HTTP::Request->new(GET => 'http://localhost' . $uri);
            my $res = $cb->($req);
            is $res->code, $status;
            #diag "$uri: " . $res->code unless $res->status == $status;
        }
    };

done_testing;
