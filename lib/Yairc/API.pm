package Yairc::API;

use strict;
use warnings;
use Encode;
use JSON;
use Plack::Response;

our $VERSION = '0.01';

sub new {
    my ( $class, @args ) = @_;
    bless { @args }, $class;
}

sub sys { $_[0]->{ sys } }

sub build_psgi_endpoint {
    my ( $self, $opt ) = @_;

    require Plack::Builder;
    # Plack::Builder->import(); # why it does not export 'builder'?

    return Plack::Builder::builder {
        sub {
            my $env = shift;
            my $req = Plack::Request->new($env);
            my $res = $self->run($req, $opt);
            return $res->finalize;
        };
    };

}

sub response_as_json {
    my ($self, $data, $code) = @_;
    my $res = Plack::Response->new($code || 200);

    $res->content_type( 'application/json' );
    $res->body( encode_json($data) );

    return $res;
}

sub response_as_text {
    my ($self, $data, $code) = @_;
    my $res = Plack::Response->new($code || 200);

    $res->content_type( 'text/plain' );
    $res->body( join( "\n", map { Encode::encode_utf8( join(',', values %$_ ) ) } @$data ) );

    return $res;
}

1;

