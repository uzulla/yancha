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
use Yancha;
use Yancha::DataStorage::DBI;
use Yancha::Config::Simple;

my $config = Yancha::Config::Simple->load_file( $ENV{ YAIRC_CONFIG_FILE } || "$root/config.pl" );
my $data_storage = Yancha::DataStorage::DBI->connect( connect_info => $config->{ database }->{ connect_info } );
my $yancha = Yancha->new( config => $config, data_storage => $data_storage );

builder {
    enable 'Session';
    enable "SimpleLogger", level => 'debug';

    mount '/socket.io/socket.io.js' =>
      Plack::App::File->new(file => "$root/public/socket.io.js");

    mount '/socket.io/static/flashsocket/WebSocketMain.swf' =>
      Plack::App::File->new(file => "$root/public/WebSocketMain.swf");

    mount '/socket.io/static/flashsocket/WebSocketMainInsecure.swf' =>
      Plack::App::File->new(file => "$root/public/WebSocketMainInsecure.swf");

    mount '/socket.io' => PocketIO->new( socketio => $config->{ socketio }, instance => $yancha );

    $yancha->build_psgi_endpoint_from_server_info('api');

    $yancha->build_psgi_endpoint_from_server_info('auth');

    mount '/' => builder {
        enable "Static",
          path => qr/\.(?:js|css|jpe?g|gif|png|html?|swf|ico)$/,
          root => "$root/public";

        mount '/' => Plack::App::File->new( file => "$root/public/chat.html" );
    };

};
