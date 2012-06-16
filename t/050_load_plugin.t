use strict;
use warnings;
use utf8;
use Encode;

use Test::More;
use t::Utils;
use Yancha;

use lib qw(./t/lib);

{
    no strict 'refs';
    no warnings;
    *{'Yancha::Plugin::Test::setup'} = sub {
        my ( $class, $sys, @args ) = @_;
        is( $class, 'Yancha::Plugin::Test', 'first arg' );
        isa_ok( $sys,   'Yancha', 'second arg' );
        is( $args[0], 'foo' );
        is( $args[1], 'bar' );
    };
    *{'Test::Plugin::setup'} = sub {
        my ( $class, $sys, @args ) = @_;
        is( $class, 'Test::Plugin', 'first arg' );
        isa_ok( $sys,   'Yancha', 'second arg' );
        is( $args[0], 'fuga' );
    };
}



my $config = {
    message_log_limit => 20,
};
my $app = Yancha->new( config => $config );

ok( $app );

$app->load_plugins( [
    [ 'Yancha::Plugin::Test' => ['foo','bar'] ],
    [ 'Test::Plugin', => ['fuga'] ],
] );

done_testing;

