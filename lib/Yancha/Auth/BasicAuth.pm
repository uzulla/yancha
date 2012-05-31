package Yancha::Auth::BasicAuth;

# Basic Auth

use strict;
use warnings;

use base 'Yancha::Auth';
use Plack::Builder;
use Plack::Request;
use Plack::Response;
use Plack::Session;
use Plack::Middleware::Auth::Basic;
use Authen::Htpasswd;

sub build_psgi_endpoint {
    my ( $self, $opt ) = @_;
    my $passwd_file  = $opt->{ 'passwd_file' }  || '';
    my $check_hashes = $opt->{ 'check_hashes' };
    my $realm        = $opt->{ 'realm' };

    # Carp::croak("Invalid login endpoint root.") unless $endpoint_root =~ m{^[-./\w]*$};

    my $basic = Plack::Middleware::Auth::Basic->new();
    $basic->app( sub { 1; } );
    $basic->realm( $realm );
    $basic->authenticator(sub {
        my ( $username, $password ) = @_;
        my $pwfile = Authen::Htpasswd->new( $passwd_file, { check_hashes => $check_hashes } );
        my $user   = $pwfile->lookup_user( $username );
        return unless $user;
        return $user->check_password( $password );
    });

    return builder {
        sub {
            my $env      = shift;
            my $req      = Plack::Request->new($env);
            my $session  = Plack::Session->new( $env );

            my $ret = $basic->call( $env );

            return $ret if ref $ret; # if $ret is arrayref, it indicates unauthorized.

            my $nickname = $env->{REMOTE_USER};

            return $basic->unauthorized unless length $nickname;

            my $user = $self->set_user_into_storage( {
                user_key          => 'basic_auth:' . $nickname,
                nickname          => $nickname,
                profile_image_url => '',
                sns_data_cache    => '',
            } );

            return $self->response_token_only($user)->finalize
                                    if $req->parameters->{ token_only };

            $session->set( 'token', $user->{ token } );

            my $res = Plack::Response->new;
            $res->redirect( $self->redirect_url( $env ) );
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

