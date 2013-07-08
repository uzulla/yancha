use strict;
use warnings;
use utf8;
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

use File::Spec;
use File::Basename 'dirname';

use Plack::Builder;
use Plack::Middleware::Static;
use Plack::App::File;
use Plack::Session;

use lib ("$FindBin::Bin/lib", "$FindBin::Bin/extlib/lib/perl5");
use PocketIO;
use Yancha;
use Yancha::Web;
use Yancha::DataStorage::DBI;
use Yancha::Config::Simple;

my $config = Yancha::Config::Simple->load_file( $ENV{ YANCHA_CONFIG_FILE } || "$root/config.pl" );
unless (defined($config->{view})) {
    die <<'ERR'

config.plに以下の設定が見つかりません.
config.pl.sampleからコピーしてから起動してください
------
    'view' => {
        'function' => {
            static => sub {
                my $uri = shift;
                $uri =~ s/^\///;
                return '/static/'.$uri;
            },  
            uri => sub {
                my $uri = shift;
                $uri =~ s/^\///;
                return '/'.$uri;
            },
        },
    },
------

ERR
}

my $data_storage = Yancha::DataStorage::DBI->connect(
    connect_info => $config->{ database }->{ connect_info },
    on_connect_exec => $config->{ database }->{ on_connect_exec }
    );
my $yancha = Yancha->new( config => $config, data_storage => $data_storage );

builder {
    enable 'Session';
    enable "SimpleLogger", level => 'debug';

    enable 'Plack::Middleware::Static',
        path => qr{^(?:/robots\.txt|/favicon\.ico)$},
        root => File::Spec->catdir(dirname(__FILE__), 'root', 'static');

    mount '/socket.io/socket.io.js' =>
      Plack::App::File->new(file => File::Spec->catfile($root, 'root', 'static', 'socket.io.js'));

    mount '/socket.io/static/flashsocket/WebSocketMain.swf' =>
      Plack::App::File->new(file => File::Spec->catfile($root, 'root', 'static', 'WebSocketMain.swf'));

    mount '/socket.io/static/flashsocket/WebSocketMainInsecure.swf' =>
      Plack::App::File->new(file => File::Spec->catfile($root, 'static', 'WebSocketMainInsecure.swf'));

    mount '/socket.io' => PocketIO->new( socketio => $config->{ socketio }, instance => $yancha );

    $yancha->build_psgi_endpoint_from_server_info('api');

    $yancha->build_psgi_endpoint_from_server_info('auth');

    mount '/' => Yancha::Web->run({ view => $config->{view} });
}
