package Yancha::Auth::Twitter;

use strict;
use warnings;

use base 'Yancha::Auth';
use Plack::Builder;
use Plack::Request;
use Plack::Response;
use JSON;
use Try::Tiny;
use Carp;

use FindBin;
use lib ("$FindBin::Bin/lib");
use Net::Twitter::Lite;
use AnyEvent::Twitter;
use Data::Dumper;

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
                my $ret_url = $self->redirect_url( $env, "$endpoint/callback" );
                
                return sub {
                    my $responder = shift;
                    my $headers = [];
                    my $req     = Plack::Request->new($env);
                    my $session = Plack::Session->new($env);

                    AnyEvent::Twitter->get_request_token(
                        consumer_key    => $opt->{ consumer_key },
                        consumer_secret => $opt->{ consumer_secret },
                        callback_url    => $ret_url,
                        auth => 'authenticate',
                        cb => sub {
                            my ($location, $response, $body, $header) = @_;
                            
                            $session->set( 'token', $response->{oauth_token});
                            $session->set( 'token_secret', $response->{oauth_token_secret} );
                            $session->set( 'token_only', 1 ) if $req->parameters->{ token_only };

                            my $res = Plack::Response->new;
                            $res->redirect($location);
                            $responder->($res->finalize);
                        },
                    );
                };
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

                my $_token = '';
                unless ( $req->param('denied') ) {
                    my $verifier = $req->param('oauth_verifier');
                    
                    return sub {
                      my $responder = shift;
                      my $session = Plack::Session->new( $env );
                      
                      AnyEvent::Twitter->get_access_token(
                        consumer_key       => $opt->{ consumer_key },
                        consumer_secret    => $opt->{ consumer_secret },
                        oauth_token        => $session->get('token'),
                        oauth_token_secret => $session->get('token_secret'),
                        oauth_verifier     => $verifier,
                        cb => sub {
                          my ($__token, $body, $header) = @_;
                          
                          my $at = AnyEvent::Twitter->new(
                            consumer_key       => $opt->{ consumer_key },
                            consumer_secret    => $opt->{ consumer_secret },
                            access_token        => $__token->{oauth_token},
                            access_token_secret => $__token->{oauth_token_secret},
                          );
                          
                          $at->get('account/verify_credentials', sub {
                            my ($header, $response, $reason) = @_;
                            
                            my $user    = $self->set_user_into_storage( {
                              user_key          => 'twitter:' . $response->{id},
                              nickname          => $response->{screen_name},
                              profile_image_url => $response->{profile_image_url},
                              profile_url       => 'https://twitter.com/#!/'.$response->{screen_name},
                              sns_data_cache    => encode_json($response),
                            } );
                            my $_token = $user->{ token };
                            
                            if($session->remove( 'token_only' )){
                              $responder->($self->response_token_only($_token)->finalize);
                            }else{
                              my $res = Plack::Response->new();
                              my $ret_url = $self->redirect_url( $env );
                              $res->redirect( $ret_url );
                              $res->cookies->{yancha_auto_login_token} = {
                                  value => $_token,
                                  path  => "/",
                                  expires => time + 24 * 60 * 60,
                              };
                              $responder->($res->finalize);
                            }
                          });
                        },
                      );
                    }
                
                }else{

                  my $res = Plack::Response->new();
                  my $ret_url = $self->redirect_url( $env );
                  $res->redirect( $ret_url );
                  $res->cookies->{yancha_auto_login_token} = {
                      value => $_token,
                      path  => "/",
                      expires => time + 24 * 60 * 60,
                  };
                  return $res->finalize;
                }
            };
        };
    };

}




1;

