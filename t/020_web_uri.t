use strict;
use warnings;
use utf8;
use t::Utils;
use Plack::Test;
use Plack::Util;
use Test::More;

my @test_uri = qw( / /quotation /search /hints /about /login );

my $app = Plack::Util::load_psgi 'chat.psgi';
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
