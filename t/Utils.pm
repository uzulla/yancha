package t::Utils;

use strict;
use warnings;
use Plack::Builder;
use PocketIO;

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
        $dbh->do( $lines );
    }

    return $mysqld;
}



1;

