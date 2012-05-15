package Yairc::Login;

use strict;
use warnings;
use Digest::SHA ();
use Time::HiRes  ();

sub new {
    my ( $class, @args ) = @_;
    return bless { @args }, $class;
}

sub data_storage { $_[0]->{ data_storage } } 

sub sys { $_[0]->{ sys } }

sub set_user_into_storage {
    my ( $self, $user ) = @_;
    my $token = $self->generate_token(64);

    $user->{ token } = $token;
    # 現状初回に発行されたtokenが使われ続ける。いずれ変更

    $self->sys->call_hook( 'authenticated', undef, $user );

    my $ret_user = $self->data_storage->add_or_replace_user( $user );
    $ret_user->{token} = $token;

    return $ret_user;
}

sub generate_token { # almost code are from HTTP::Session
    my ( $class, $len, $rand_sub ) = @_;
    my $unique = $rand_sub ? $rand_sub->() : Time::HiRes::gettimeofday() . [] . rand();
    return substr( Digest::SHA::sha256_hex( $unique ), 0, $len );
}


1;
