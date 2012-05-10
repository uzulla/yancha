use strict;
use warnings;
use utf8;
use Encode;

use Test::More;

BEGIN {
    use_ok('Yairc');
}

for my $line (<DATA>) {
    chomp($line);
    next unless length $line;
    next if $line =~ /^\s*--/;
    my ( $text, @tags ) = split/\s*,\s*/, $line;

    my $post = { text => $text };
    my $hash = Yairc->build_user_message_hash( $post );

    is( join(',', sort { $a cmp $b } @{$hash->{tags}} ), join(',', sort @tags), Encode::encode_utf8($text) );
}

my $lines =<<LINES;
これは複数行でして #ho
ge は#hogeではなくて#hoとしてあつかわれたい
LINES

my $hash = Yairc->build_user_message_hash( { text => $lines } );
is( join(',', sort { $a cmp $b } @{$hash->{tags}} ), 'HO', 'mulit line' );

$lines =<<LINES;
これも複数行でして #foo #ho
 ge は#foo,#hoとしてあつかわれたい
LINES

$hash = Yairc->build_user_message_hash( { text => $lines } );
is( join(',', sort { $a cmp $b } @{$hash->{tags}} ), 'FOO,HO', 'mulit line' );


done_testing;

__DATA__
Hello World. #HACHIOJI, HACHIOJI
Hello. #PUBLIC #HACHIOJI, HACHIOJI, PUBLIC
#012, 012
# no tag
##aa,
#aa",
# #aa, AA
#hoge#fuga,
#hoge #fuga, HOGE, FUGA
#ascii, ASCII
-- TODO : #非アスキー, 非アスキー
これは#タグではないよ,
これも　#タグではないよ,
しかしこれは　#tag だ！, TAG
-- TODO : #ほげascii #foo #ふが, ほげASCII, FOO, ふが
#非常に長いタグ #01234567890123456789012345678901, 01234567890123456789012345678901
#長すぎて不正 #012345678901234567890123456789012,

