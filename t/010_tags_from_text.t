use strict;
use warnings;

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
                Yairc::build_tag_list_from_text( $text ) ), join(',', sort @tags), $text );
}


done_testing;

__DATA__
Hello World. #HACHIOJI, HACHIOJI
Hello. #PUBLIC #HACHIOJI, HACHIOJI, PUBLIC
#012, 012
# no tag
##aa, AA
#hoge#fuga, HOGE, FUGA
#ascii, ASCII
#非アスキー

