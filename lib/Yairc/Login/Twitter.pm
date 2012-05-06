package Yairc::Login::Twitter;

use strict;
use warnings;

use base 'Yairc::Login';
use Plack::Builder;
use Plack::Request;
use Plack::Response;
use JSON;

use FindBin;
use lib ("$FindBin::Bin/lib");
use Net::Twitter::Lite;


sub build_psgi_endpoint {
    my ( $self, $opt ) = @_;
    my $nt = Net::Twitter::Lite->new(
        consumer_key    => $opt->{ consumer_key },
        consumer_secret => $opt->{ consumer_secret },
    );

    # Carp::croak("Invalid login endpoint root.") unless $endpoint_root =~ m{^[-./\w]*$};
    return builder {

        mount '/start' => builder {
            sub {
                my $env     = shift;
                my $session = Plack::Session->new( $env );
                my $url     = $nt->get_authorization_url(
                                callback => 'http://'.$env->{HTTP_HOST}.'/login/twitter/callback' );
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
                $res->redirect('http://'.$env->{HTTP_HOST}.'/');
                $res->cookies->{yairc_auto_login_token} = {
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
