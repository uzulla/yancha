use strict;
use utf8;
use warnings;
use FindBin;
use lib ("$FindBin::Bin/lib");

my $root;

BEGIN {
    use File::Basename ();
    use File::Spec     ();

    $root = File::Basename::dirname(__FILE__);
    $root = File::Spec->rel2abs($root);

    unshift @INC, "$root/../../lib", "$root/../lib";
}


use Data::Dumper;

use Yancha;
use Yancha::DataStorage::DBI;
use Yancha::Config::Simple;

my $config = Yancha::Config::Simple->load_file( $ENV{ YANCHA_CONFIG_FILE } || "$root/../config.pl" );
my $data_storage = Yancha::DataStorage::DBI->connect( connect_info => $config->{ database }->{ connect_info } );

my $posts = $data_storage->search_post( {}, { limit => 10000 } );

for my $post ( @$posts ) {
    my @tags = Yancha->extract_tags_from_text( $post->{ text } );
    $post->{ tags } = [ @tags ];
    $data_storage->replace_post( $post );
}


