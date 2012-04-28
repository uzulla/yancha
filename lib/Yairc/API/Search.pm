package Yairc::API::Search;

use strict;
use warnings;
use Yairc::API;
use parent qw(Yairc::API);

our $VERSION = '0.01';

sub new {
    my ( $class, @args ) = @_;
    bless { @args }, $class;
}

sub search {
    my ($self, @args) = @_;
    my %args = @args;


    # ここから 検索パラメータ
    my %search_param = ();

    # limit
    my $limit_offset = 0;
    my $get_limit    = 100;
    if (defined( $args{'limit'} )) {

        if (ref $args{'limit'} eq 'ARRAY') {

            if (scalar @{ $args{'limit'} } >= 2) {
                ($limit_offset, $get_limit) = @{ $args{'limit'} };
            } else {
                ($get_limit) = @{ $args{'limit'} };
            }
        
        } elsif ($args{'limit'} > 0) {
            $get_limit = $args{'limit'};
        }

        $search_param{'limit'} = [$limit_offset, $get_limit];
    }

    # tag
    $search_param{'tag'} = (defined($args{'tag'})) ? $args{'tag'}:'';


    # ここまで 検索パラメータ

    my @log = $self->search_by(%search_param);
    
    return $self->request_by_json( @log );
}

sub search_by {
    my ($self, @args) = @_;
    my %args = @args;

    my @bind_param = ();

    my $select = 'SELECT * FROM `post` ';
    my $order  = 'ORDER BY `created_at_ms` DESC ';

    my $where = '';
    if (defined( $args{'tag'} )) {
        $where = 'WHERE UPPER(`text`) LIKE UPPER(?) ';
        push(@bind_param, "%#$args{'tag'}%");
    }

    my $limit = '';
    if (defined( $args{'limit'} )) {
        $limit = "LIMIT $args{'limit'}[0], $args{'limit'}[1] ";
    }

    my $get_log_data_sth = $self->{ dbh }->prepare(
        $select.
        $where.
        $order.
        $limit
    );

    my $rv;
    if (@bind_param) {
        $rv = $get_log_data_sth->execute(@bind_param);
    } else {
        $rv = $get_log_data_sth->execute();
    }

    my @hash_list = ();
    while (my $hash = $get_log_data_sth->fetchrow_hashref() ) {
        push(@hash_list, $hash);
    }

    return @hash_list;
}

1;
