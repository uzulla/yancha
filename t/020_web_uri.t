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
use File::Copy::Recursive qw(dircopy);

my @test_uri = qw( / /quotation /search /hints /about /login );


my $config = Yancha::Config::Simple->load_file( "./config.pl.sample" );
my $testdb  = t::Utils->setup_testdb( schema => './db/init.sql' );
my $storage = Yancha::DataStorage::DBI->connect( connect_info => [ $testdb->dsn() ] );
my $yancha = Yancha->new( config => $config, data_storage => $storage );

$config->{app} = $yancha;

dircopy('./view', './t/view');
my $app = Yancha::Web->run(%$config);
test_psgi
    app => $app,
    client => sub {
        my $cb = shift;
        
        for my$uri( @test_uri ) {
            my $req = HTTP::Request->new(GET => 'http://localhost/');
            my $res = $cb->($req);
            is $res->code, 200;
            diag $res->content if $res->code != 200;
        }
    };

done_testing;
