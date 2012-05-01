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
use Net::Twitter::Lite;
use Data::UUID;
use JSON;

use FindBin;
use lib ("$FindBin::Bin/lib");
use Yairc;
use Yairc::DB;
use Yairc::API::Search;


my $dbh = Yairc::DB->new('yairc');


my $nt = Net::Twitter::Lite->new(
    consumer_key    => 'gtpTrhPdlkSqbmmG7M9lew',
    consumer_secret => 'ayIwIXzTNSE4deChyn2p1VmXfhxjXPgj79PVMoGs',
);
my $user_insert_or_update = $dbh->prepare('INSERT INTO `user` (`user_key`,`nickname`,`profile_image_url`,`sns_data_cache`,`token`,`created_at`,`updated_at`) VALUES (?, ?, ?, ?, ?, now(), now()) ON DUPLICATE KEY UPDATE `sns_data_cache`=values(`sns_data_cache`),`nickname`=values(`nickname`),`profile_image_url`=values(`profile_image_url`),`updated_at`=now();');
my $user_select_by_user_key  = $dbh->prepare('SELECT * FROM `user` WHERE `user_key`=? ');


sub user_info_set {
  my ($user_key,$nickname,$profile_image_url,$sns_data_cache) = @_;
  my $ug = new Data::UUID;
  my $token = $ug->create_str();
  $user_insert_or_update->execute( $user_key,$nickname,$profile_image_url,$sns_data_cache,$token );

  $user_select_by_user_key->execute( $user_key );
  my $user = $user_select_by_user_key->fetchrow_hashref();

  my $rtntoken = $user->{token};

  return $rtntoken;
}


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

    mount '/login' => builder {
      sub {
        my $env    = shift;
        my $session = Plack::Session->new( $env );
        my $url     = $nt->get_authorization_url(
            callback => 'http://'.$env->{HTTP_HOST}.'/callback' );
        $session->set( 'token', $nt->request_token );
        $session->set( 'token_secret', $nt->request_token_secret );

        my $res = Plack::Response->new;
        $res->redirect($url);
        return $res->finalize;
      };
    };

    mount '/callback' => builder {
      sub {
        my $env = shift;
        
        my $req = Plack::Request->new($env);
        my $oauth_verifier     = $req->param('oauth_verifier');
        my ( $access_token, $access_token_secret, $user_id, $screen_name, $profile_image_url );
        my $session = Plack::Session->new( $env );
        
        unless ( $session->get('token') ){
          warn 'session lost';
          return [   500,
              [   'Content-Type'   => 'text/html',
              ],
              ["session lost"]
          ];
        }

        my $token = '';
        unless ( $req->param('denied') ) {
            $nt->request_token( $session->get('token') );
            $nt->request_token_secret( $session->get('token_secret') );
            my $verifier = $req->param('oauth_verifier');
            ( $access_token, $access_token_secret, $user_id, $screen_name ) =
              $nt->request_access_token( verifier => $verifier );
              
            my $profile = eval { $nt->verify_credentials() };
            #w Dumper($profile);
            
            #db store
            $token = user_info_set(
              'twitter:'.$profile->{id},
              $screen_name,
              $profile->{profile_image_url},
              encode_json($profile),
            );
            $session->set( 'yairc_auto_login_token', $token);
        }
        
        my $res = Plack::Response->new;
        $res->redirect('http://'.$env->{HTTP_HOST}.'/');
        $res->cookies->{yairc_auto_login_token} = $token;
        return $res->finalize;
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
