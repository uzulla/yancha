package Yancha::Auth::Twitter;

use strict;
use warnings;

use base 'Yancha::Auth';
use Plack::Builder;
use Plack::Request;
use Plack::Response;
use JSON;

use FindBin;
use lib ("$FindBin::Bin/lib");
use Net::Twitter::Lite;


sub build_psgi_endpoint {
    my ( $self, $opt ) = @_;
    my $endpoint = $opt->{ endpoint };
    my $nt = Net::Twitter::Lite->new(
        consumer_key    => $opt->{ consumer_key },
        consumer_secret => $opt->{ consumer_secret },
        legacy_lists_api => 0,
    );

    # クライアント向け情報にアクセスポイントを設定する
    $self->sys->config->{ server_info }->{ auth_endpoint }
                        ->{ $endpoint }->[2]->{ start_point } = $endpoint . '/start';

    # Carp::croak("Invalid login endpoint root.") unless $endpoint_root =~ m{^[-./\w]*$};
    return builder {

        mount '/start' => builder {
            sub {
                my $env     = shift;
                my $session = Plack::Session->new( $env );
                my $ret_url = $self->redirect_url( $env, "$endpoint/callback" );
                my $url     = $nt->get_authorization_url( callback => $ret_url );

                $session->set( 'token', $nt->request_token );
                $session->set( 'token_secret', $nt->request_token_secret );

                my $res = Plack::Response->new;
                $res->redirect($url);
                return $res->finalize;
            }
        };

        mount '/callback' => builder {
            sub {
                my $env = shift;
                my $req = Plack::Request->new($env);
                my $oauth_verifier = $req->param('oauth_verifier');
                my ( $access_token, $access_token_secret, $user_id, $screen_name, $profile_image_url );
                my $session = Plack::Session->new( $env );
        
                unless ( $session->get('token') ){
                    warn 'session lost';
                    return [ 401, ['Content-Type' => 'text/html',], ["session lost"] ];
                }

                my $token = '';
                unless ( $req->param('denied') ) {
                    $nt->request_token( $session->get('token') );
                    $nt->request_token_secret( $session->get('token_secret') );
                    my $verifier = $req->param('oauth_verifier');
                    ( $access_token, $access_token_secret, $user_id, $screen_name ) =
                                          $nt->request_access_token( verifier => $verifier );

                    my $profile = eval { $nt->verify_credentials() };
                    my $user    = $self->set_user_into_storage( {
                        user_key          => 'twitter:' . $profile->{id},
                        nickname          => $screen_name,
                        profile_image_url => $profile->{profile_image_url},
                        sns_data_cache    => encode_json($profile),
                    } );
                    $token = $user->{ token };
                }

                my $res = Plack::Response->new();
                my $ret_url = $self->redirect_url( $env );
                $res->redirect( $ret_url );
                $res->cookies->{yancha_auto_login_token} = {
                    value => $token,
                    path  => "/",
                    expires => time + 24 * 60 * 60,
                };
                return $res->finalize;
            };
        };
    };

}




1;
