package Yairc::API;

use strict;
use warnings;
use Encode;
use JSON;

our $VERSION = '0.01';

sub new {
    my ( $class, @args ) = @_;
    bless { @args }, $class;
}

sub data_storage { $_[0]->{ data_storage } } 

sub response_as_json {
    my ($self, $data) = @_;

    return {
        'data'          => encode_json($data),
        'content-type'  => 'application/json',
    };
}

sub response_as_text {
    my ($self, $data) = @_;

    return {
        'data'          => join( "\n", map { Encode::encode_utf8( join(',', values %$_ ) ) } @$data ),
        'content-type'  => 'text/plain',
    };
}


1;
