package Yancha::Auth;

use strict;
use warnings;
use Digest::SHA ();
use Time::HiRes  ();

sub new {
    my ( $class, @args ) = @_;
    my $self = bless { @args }, $class;
    $self->setup() if $self->can('setup');
    return $self;
}

sub sys { $_[0]->{ sys } }

sub redirect_url {
    my ( $self, $env, $root ) = @_;
    my $url = $env->{'psgi.url_scheme'} . '://' . $env->{'HTTP_HOST'};
    if ( !defined $root and exists $self->sys->{ server_info } ) {
        $root = $self->sys->{ server_info }->{ root };
    }
    $root ||= '';
    return $url . $root;
}

sub set_user_into_storage {
    my ( $self, $user ) = @_;
    my $token = $self->generate_token(64);

    $user->{ token } = $token;
    # 現状初回に発行されたtokenが使われ続ける。いずれ変更

    $self->sys->call_hook( 'authenticated', undef, $user );

    my $extra    = { token_expiration_sec => $self->sys->config->{ token_expiration_sec } };
    my $ret_user = $self->sys->data_storage->add_or_replace_user( $user, $extra );
    $ret_user->{token} = $token;

    return $ret_user;
}

sub generate_token { # almost code are from HTTP::Session
    my ( $class, $len, $rand_sub ) = @_;
    my $unique = $rand_sub ? $rand_sub->() : Time::HiRes::gettimeofday() . [] . rand();
    return substr( Digest::SHA::sha256_hex( $unique ), 0, $len );
}


1;
