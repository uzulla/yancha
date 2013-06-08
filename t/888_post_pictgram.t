use strict;
use warnings;
use t::Utils;
use Data::Dumper;
use Test::More;
use Yancha;
use Yancha::DataStorage::DBI;
use utf8;

sub text2post {
    my ( $text ) = @_;
    my @tags = Yancha->extract_tags_from_text( $text );

    if ( @tags == 0 ){
        $text = $text . " #PUBLIC";
        push( @tags, "PUBLIC" );
    }

    return { text => $text, tags => [ @tags ] };
}


my $testdb  = t::Utils->setup_testdb( schema => './db/init.sql' );
my $storage = Yancha::DataStorage::DBI->connect( connect_info => [ $testdb->dsn() ] );

my $user = {
    user_key => '-:0001',
    nickname => 'user',
    token    => '10101010',
    profile_image_url => '',
    profile_url       => '',
    sns_data_cache    => '',
};

$storage->add_post( text2post( "\x{1f601}" ), $user ); # "\x{1f601}" ->😁
$storage->add_post( text2post( "\x{1f602}" ), $user ); # "\x{1f602}" ->😂

my $posts = $storage->search_post( { text => ["\x{1f601}"]} );
is( scalar(@$posts), 1 );

done_testing;

