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
use Config::Pit;

use FindBin;
use lib ("$FindBin::Bin/lib");
use Yairc;
use Yairc::API;

my $config = pit_get( "yairc", require => {
       "dsn" => "dsn",
       "db_user" => "db username",
       "db_pass" => "db password"
});

my $dbh = DBI->connect($config->{dsn}, $config->{db_user}, $config->{db_pass}, { mysql_enable_utf8 => 1 })
        || die DBI::errstr; #plz change


builder {
    mount '/socket.io/socket.io.js' =>
      Plack::App::File->new(file => "$root/public/socket.io.js");

    mount '/socket.io/static/flashsocket/WebSocketMain.swf' =>
      Plack::App::File->new(file => "$root/public/WebSocketMain.swf");

    mount '/socket.io/static/flashsocket/WebSocketMainInsecure.swf' =>
      Plack::App::File->new(file => "$root/public/WebSocketMainInsecure.swf");

    mount '/socket.io' => PocketIO->new( instance => Yairc->new( dbh => $dbh ) );

    mount '/api' => builder {
        # リクエストパラメータで取得するデータ形式とか発言の取得範囲を指定できたらいいなっ

        my $api = Yairc::API->new( dbh => $dbh );
        
        my $res = $api->get_log_data();
        sub {
            [   200,
                [   'Content-Type'   => $res->{'content-type'},
                    'Content-Length' => length($res->{'data'})
                ],
                [$res->{'data'}]
            ];
        };
    };

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
