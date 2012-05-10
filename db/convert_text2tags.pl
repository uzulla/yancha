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

use Yairc;
use Yairc::DataStorage::DBI;
use Yairc::Config::Simple;

my $config = Yairc::Config::Simple->load_file( $ENV{ YAIRC_CONFIG_FILE } || "$root/../config.pl" );
my $data_storage = Yairc::DataStorage::DBI->connect( connect_info => $config->{ database }->{ connect_info } );

my $posts = $data_storage->search_post( {}, { limit => 10000 } );

for my $post ( @$posts ) {
    my @tags = Yairc->build_tag_list_from_text( $post->{ text } );
    $post->{ tags } = [ @tags ];
    $data_storage->replace_post( $post );
}


