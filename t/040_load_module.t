use strict;
use warnings;
use utf8;
use Encode;

use Test::More;
use t::Utils;
use Yairc;

use lib qw(./t/lib);

my $app = Yairc->new();

is( $app->load_module( 'Plugin', 'Test' ), 'Yairc::Plugin::Test' );
is( $app->load_module( 'Plugin', '+Test::Plugin' ), 'Test::Plugin' );
is( $app->load_module( '+Test::Plugin' ), 'Test::Plugin' );
is( $app->load_module( 'Test::Plugin' ), 'Test::Plugin' );

done_testing;

