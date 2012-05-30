package Yancha::Auth::Simple;

# Simple and Yancha core login function

use strict;
use warnings;

use base 'Yancha::Login';
use Plack::Builder;
use Plack::Request;
use Plack::Response;
use Plack::Session;


sub build_psgi_endpoint {
    my ( $self, $opt ) = @_;
    my $name_field = $opt->{ 'name_field' } || 'nick';

    # Carp::croak("Invalid login endpoint root.") unless $endpoint_root =~ m{^[-./\w]*$};

    return builder {
        sub {
            my $env     = shift;
            my $req     = Plack::Request->new($env);
            my $session = Plack::Session->new( $env );
            my $nick    = $req->parameters->{ $name_field };

            my $url = 'http://'.$env->{HTTP_HOST}; # ok?
            my $res = Plack::Response->new;
            $res->redirect($url);

            unless ( length $nick ){
                return $res->finalize;
            }

            my $user = $self->set_user_into_storage( {
                user_key          => '-:' . $nick,
                nickname          => $nick,
                profile_image_url => '',
                sns_data_cache    => '',
            } );

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

