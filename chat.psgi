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

    unshift @INC, "$root/../../lib";
}

use Plack::Builder;
use Plack::Middleware::Static;
use Plack::App::File;
use Plack::Session;

use PocketIO;
use Yairc;
use Yairc::DataStorage::DBI;
use Yairc::Config::Simple;

my $config = Yairc::Config::Simple->load_file( $ENV{ YAIRC_CONFIG_FILE } || "$root/config.pl" );
my $data_storage = Yairc::DataStorage::DBI->connect( connect_info => $config->{ database }->{ connect_info } );
my $yairc  = Yairc->new( config => $config, data_storage => $data_storage );

builder {
    enable 'Session';
    enable "SimpleLogger", level => 'debug';

    mount '/socket.io/socket.io.js' =>
      Plack::App::File->new(file => "$root/public/socket.io.js");

    mount '/socket.io/static/flashsocket/WebSocketMain.swf' =>
      Plack::App::File->new(file => "$root/public/WebSocketMain.swf");

    mount '/socket.io/static/flashsocket/WebSocketMainInsecure.swf' =>
      Plack::App::File->new(file => "$root/public/WebSocketMainInsecure.swf");

    mount '/socket.io' => PocketIO->new( socketio => $config->{ socketio }, instance => $yairc );

    $yairc->build_psgi_endpoint_from_server_info('api');

    mount '/login/twitter' => $yairc->login('Twitter')
                                    ->build_psgi_endpoint( $config->{ twitter_appli } );

    mount '/login'         => $yairc->login('Simple')
                                    ->build_psgi_endpoint( { name_field => 'nick' } );

    mount '/' => builder {
        enable "Static",
          path => qr/\.(?:js|css|jpe?g|gif|png|html?|swf|ico)$/,
          root => "$root/public";

        mount '/' => Plack::App::File->new( file => "$root/public/chat.html" );
    };

};
