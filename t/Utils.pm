package t::Utils;

use strict;
use warnings;
use Plack::Builder;
use PocketIO;
use AnyEvent;

BEGIN {
    use Test::More;
    plan skip_all => 'Test::mysqld is required to run this test'
      unless eval { require Test::mysqld; 1 };
}


sub server_with_dbi {

    require Yancha;
    require Yancha::DataStorage::DBI;

    my ( $self, %opt ) = @_;
    my $config       = $opt{ config } || {};
    my $data_storage = Yancha::DataStorage::DBI->connect(
                            connect_info => $config->{ database }->{ connect_info } );
    my $sys = Yancha->new( config => $config, data_storage => $data_storage );

    builder {
        enable 'Session';

        my $api_endpoint_conf  = ($config->{server_info} || {})->{api_endpoint};
        my $auth_endpoint_conf = ($config->{server_info}->{ auth_endpoint } || {
            auth_endpoint => { '/login' => [ 'Yancha::Auth::Simple', { name_field => 'nick' } ] },
        })->{auth_endpoint};

        $sys->build_psgi_endpoint_from_server_info('api', $api_endpoint_conf)
                                                          if $api_endpoint_conf;

        $sys->build_psgi_endpoint_from_server_info('auth', $auth_endpoint_conf);

        mount '/socket.io' => PocketIO->new(
                socketio => $config->{ socketio },
                instance => $sys,
        );
    };
}


sub setup_mysqld {
    my ( $self, %opt ) = @_;
    my $schema_file = $opt{ schema } || '';

    my $mysqld = Test::mysqld->new(
        my_cnf => { 'skip-networking' => '' }
    ) or plan skip_all => $Test::mysqld::errstr;

    my $dbh = DBI->connect( $mysqld->dsn() );

    open( my $fh, '<', $schema_file ) or plan skip_all => "Can't open schema file $schema_file.";

    for my $lines ( split/;\n/, do { <$fh>; local $/; <$fh> } ) {
        next if $lines =~ /^\r?\n$/; # empty line
        $dbh->do( $lines );
    }

    return $mysqld;
}


sub create_clients_and_set_tags {
    my ( $self, $port, @users ) = @_;
    my $cv = AnyEvent->condvar;
    my $w  = AnyEvent->timer( after => 5 * scalar(@users), cb => sub {
        Carp::carp("Time out.");
        $cv->end for 1 .. scalar(@users);
    } );

    my @clients;

    for my $user ( @users ) {
        my $client   = Yancha::Client->new();
        my $nickname = $user->{ nickname } || 'client';
        my $on_connect = $user->{ on_connect };

        $cv->begin;

        $client->login( "http://localhost:$port/", => 'login', { nick => $nickname } );
        $client->connect or Carp::croak "Can't create client.";

        $on_connect->( $client ) if $on_connect;

        $client->run(sub {
            my ( $self, $socket ) = @_;
            my @tags = exists $user->{ tags } ? @{ $user->{ tags } } : 'PUBLIC';
            $client->socket->on('token login', sub {
                my $status = $_[1]->{ status };
                if ( $_[1]->{ status } ne 'ok' ) {
                    Carp::carp $nickname . " login fail.";
                }
                else {
                    $client->set_tags( @tags, sub { $cv->end; } );
                }
             });
            $socket->emit('token login', $client->token);
        });

        push @clients, $client;
    }

    $cv->wait;

    return @clients;
}


1;

