use strict;
use warnings;
use utf8;
use Encode;

use Test::More;
use t::Utils;
use Yancha;

use lib qw(./t/lib);

my $app = Yancha->new();

is( $app->load_module( 'Plugin', 'Test' ), 'Yancha::Plugin::Test' );
is( $app->load_module( 'Plugin', '+Test::Plugin' ), 'Test::Plugin' );
is( $app->load_module( '+Test::Plugin' ), 'Test::Plugin' );
is( $app->load_module( 'Test::Plugin' ), 'Test::Plugin' );

done_testing;

