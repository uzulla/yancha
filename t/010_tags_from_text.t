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
    is( join(',', sort { $a cmp $b }
                Yairc->extract_tags_from_text( $text ) ), join(',', sort @tags), Encode::encode_utf8($text) );
}

my $lines =<<LINES;
これは複数行でして #ho
ge は#hogeではなくて#hoとしてあつかわれたい
LINES

is( join(',', sort { $a cmp $b }
                Yairc->extract_tags_from_text( $lines ) ), 'HO', 'mulit line' );

$lines =<<LINES;
これも複数行でして #foo #ho
 ge は#foo,#hoとしてあつかわれたい
LINES

is( join(',', sort { $a cmp $b }
                Yairc->extract_tags_from_text( $lines ) ), 'FOO,HO', 'mulit line' );

$lines =<<LINES;
タグの最大値は10 #tag01 #tag02 #tag03 #tag04 #tag05
#tag06 #
taghoge #tag07 #tag08 #tag09 #tag10 #tag11
LINES

is( join(',', sort { $a cmp $b }
                Yairc->extract_tags_from_text( $lines ) ),
                'TAG01,TAG02,TAG03,TAG04,TAG05,TAG06,TAG07,TAG08,TAG09,TAG10', 'mulit line' );


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

