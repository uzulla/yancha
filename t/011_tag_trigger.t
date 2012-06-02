use strict;
use warnings;
use utf8;
use Encode;

use Test::More;
use Yancha;

my $yancha = Yancha->new;
my ( $message, $ctx ) = ("Hello World", { 'ctx' => 1 });
my $tags = [];

$yancha->tag_trigger( undef, $tags, \$message, $ctx );

is_deeply( $tags, [], 'no registered' );

$yancha->register_calling_tag( undef, sub {
    my ( $self, $socket, $tag, $tags, $message_ref, $ctx, @args ) = @_;

    is( $tag, undef, "no tag trigger's tag is undef." );
    is( $$message_ref, 'Hello World' );
    is_deeply( $tags, [], 'no registered' );
    is( $ctx->{ ctx}, 1, 'ctx' );
    is_deeply( [@args], [ 'foo', 'bar' ], 'args' );

    $$message_ref .= '!';
    push @{$tags}, 'FOO';

}, ['foo','bar'] );

$yancha->tag_trigger( undef, $tags, \$message, $ctx );

is_deeply( $tags, [qw/FOO/], 'undef tag triggered' );

$yancha->register_calling_tag( 'foo', sub {
    my ( $self, $socket, $tag, $tags, $message_ref, $ctx, @args ) = @_;

    is( $tag, 'FOO', "FOO tag" );
    is( $$message_ref, 'Hello World!' );
    is_deeply( $tags, [qw/FOO/] );
    is( $ctx->{ ctx}, 1, 'ctx' );
    is_deeply( [@args], [ 'bar', 'baz' ], 'args' );

    $$message_ref .= '!';
    push @{$tags}, 'REG_12345';

}, ['bar','baz'] );

$yancha->tag_trigger( 'foo', $tags, \$message, $ctx );

is_deeply( $tags, [qw/FOO REG_12345/], 'undef tag triggered' );

$yancha = Yancha->new;
$yancha->register_calling_tag( qr/REG_(\d+)/, sub {
    my ( $self, $socket, $tag, $tags, $message_ref, $ctx, @args ) = @_;

    is( $tag, 'REG_12345', "REG_ tag" );
    is( $$message_ref, 'Hello World!!' );
    is_deeply( $tags, [qw/FOO REG_12345/] );
    is( $ctx->{ ctx }, 1, 'ctx' );
    is_deeply( $ctx->{ splat }, [12345], 'matched' );
    is_deeply( [@args], [123], 'args' );

    $$message_ref .= '!';
    pop @$tags;
    push @$tags, 'REG';

}, [123] );

$yancha->tag_trigger( 'reg_12345', $tags, \$message, $ctx );

is_deeply( $tags, [qw/FOO REG/] );
is( $message, 'Hello World!!!', 'all right' );

done_testing;

