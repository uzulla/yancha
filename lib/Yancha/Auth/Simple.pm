package Yancha::Auth::Simple;

# Simple and Yancha core login function

use strict;
use warnings;

use base 'Yancha::Auth';
use Plack::Builder;
use Plack::Request;
use Plack::Response;
use Plack::Session;
use Encode;

sub build_psgi_endpoint {
    my ( $self, $opt ) = @_;
    my $name_field = $opt->{ 'name_field' } || 'nick';
    my $endpoint = $opt->{ endpoint };

    # クライアント向け情報に入力欄名を設定する
    $self->sys->config->{ server_info }->{ auth_endpoint }
                        ->{ $endpoint }->[2]->{ name_field } = $name_field;

    # Carp::croak("Invalid login endpoint root.") unless $endpoint_root =~ m{^[-./\w]*$};

    return builder {
        sub {
            my $env     = shift;
            my $req     = Plack::Request->new($env);
            my $session = Plack::Session->new( $env );
            my $nick    = decode_utf8 $req->parameters->{ $name_field };

            my $url = ($req->parameters->{ callback_url }) ? 
                $req->parameters->{ callback_url } :
                $self->redirect_url( $env );
            my $res = Plack::Response->new;
            $res->redirect($url);

            unless ( length $nick ){
                return $res->finalize;
            }

            my $user = $self->set_user_into_storage( {
                user_key          => '-:' . $nick,
                nickname          => $nick,
                profile_image_url => '',
                profile_url       => '',
                sns_data_cache    => '',
            } );

            # TODO: ここから下まとめる
            if ( $req->parameters->{ token_only } ) {
                return $self->response_token_only($user, $req->parameters->{ callback_url } )->finalize;
            }

            $session->set( 'token', $user->{ token } );

            $res->cookies->{yancha_auto_login_token} = {
                value => $user->{ token },
                path  => "/",
                expires => time + 24 * 60 * 60,
            };
            return $res->finalize;
        };
    };

}

1;
__END__

