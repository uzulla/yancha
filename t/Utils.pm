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

    require Yairc;
    require Yairc::DataStorage::DBI;
    require Yairc::Login::Simple;
    require Yairc::Login::Twitter;

    my ( $self, %opt ) = @_;
    my $config       = $opt{ config } || {};
    my $data_storage = Yairc::DataStorage::DBI->connect(
                            connect_info => $config->{ database }->{ connect_info } );

    builder {
        enable 'Session';

        mount '/socket.io' => PocketIO->new(
                socketio => $config->{ socketio },
                instance => Yairc->new( config => $config, data_storage => $data_storage ) 
        );

        mount '/login/twitter' => Yairc::Login::Twitter->new(data_storage => $data_storage)
                                ->build_psgi_endpoint( $config->{ twitter_appli } );

        mount '/login' => Yairc::Login::Simple->new(data_storage => $data_storage)
                                ->build_psgi_endpoint( { name_field => 'nick' } );
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
        my $client   = Yairc::Client->new();
        my $nickname = $user->{ nickname } || 'client';
        my $on_connect = $user->{ on_connect };

        $cv->begin;

        $client->login( "http://localhost:$port/", => 'login', { nick => $nickname } );
        $client->connect or Carp::croak "Can't create client.";

        $on_connect->( $client ) if $on_connect;

        $client->run(sub {
            my ( $self, $socket ) = @_;
            my @tags = exists $user->{ tags } ? @{ $user->{ tags } } : 'PUBLIC';
            $client->socket->on('token_login', sub {
                $client->set_tags( @tags, sub { $cv->end; } );
             });
            $socket->emit('token_login', $client->token);
        });

        push @clients, $client;
    }

    $cv->wait;

    return @clients;
}


1;

