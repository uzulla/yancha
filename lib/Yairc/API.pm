package Yairc::API;

use strict;
use warnings;
use JSON;

our $VERSION = '0.01';

sub new {
    my ( $class, @args ) = @_;
    bless { @args }, $class;
}

sub request_by_json {
    my ($self, @args) = @_;

    return {
        'data'          => encode_json(\@args),
        'content-type'  => 'application/json',
    };
}

1;
