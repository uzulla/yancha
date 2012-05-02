my $root;

BEGIN {
    use File::Basename ();
    use File::Spec     ();

    $root = File::Basename::dirname(__FILE__);
    $root = File::Spec->rel2abs($root);

    unshift @INC, "$root/../../lib";
}

use strict;
use utf8;
use warnings;
use PocketIO;
use Plack::App::File;
use Plack::Builder;
use Plack::Middleware::Static;
use Encode;
use Data::Dumper;

use Plack::Session;
use Plack::Request;

use FindBin;
use lib ("$FindBin::Bin/lib");
use Yairc;
use Yairc::DB;
use Yairc::API::Search;
use Yairc::Login::Twitter;

my $dbh = Yairc::DB->new('yairc');

builder {
    enable 'Session';

    mount '/socket.io/socket.io.js' =>
      Plack::App::File->new(file => "$root/public/socket.io.js");

    mount '/socket.io/static/flashsocket/WebSocketMain.swf' =>
      Plack::App::File->new(file => "$root/public/WebSocketMain.swf");

    mount '/socket.io/static/flashsocket/WebSocketMainInsecure.swf' =>
      Plack::App::File->new(file => "$root/public/WebSocketMainInsecure.swf");

    mount '/socket.io' => PocketIO->new( instance => Yairc->new( dbh => $dbh ) );

    # APIリクエストサンプル
    # https://gist.github.com/2440738
    mount '/api' => do ( './api.psgi' ) ;

    Yairc::Login::Twitter->build_psgi_endpoint( '/login/twitter' );

    mount '/' => builder {
        enable "Static",
          path => qr/\.(?:js|css|jpe?g|gif|png|html?|swf|ico)$/,
          root => "$root/public";

        enable "SimpleLogger", level => 'debug';

        my $html = do {
            local $/;
            open my $fh, '<', "$root/public/chat.html"
              or die $!;
            <$fh>;
        };

        sub {
            [   200,
                [   'Content-Type'   => 'text/html',
                    'Content-Length' => length($html)
                ],
                [$html]
            ];
        };
    };
};
