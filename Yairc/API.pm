package Yairc::API;

use strict;
use warnings;
use JSON;
use DBI;
use Encode;
use Data::Dumper;

our $VERSION = '0.01';

sub new {
    my ( $class, @args ) = @_;
    bless { @args }, $class;
}

sub get_log_data {
    my ($self, @args) = @_;

    my $get_log_data_sth = $self->{ dbh }->prepare('SELECT * FROM `post` ORDER BY `created_at_ms` DESC LIMIT 100 ');
    my $rv = $get_log_data_sth->execute();

    my @hash_list = ();
    while (my $hash = $get_log_data_sth->fetchrow_hashref() ) {
        push(@hash_list, $hash);
    }

    my $json = JSON->new;
    return {
        'data'          => $json->encode(\@hash_list),
        'content-type'  => 'application/json',
    };
}

1;
