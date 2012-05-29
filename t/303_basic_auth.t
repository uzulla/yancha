use strict;
use warnings;
use PocketIO::Test;
use Yairc;
use t::Utils;
use AnyEvent;
use Yairc::Client;
use Yairc::DataStorage::DBI;
use Plack::Builder;
use utf8;

BEGIN {
    use Test::More;
    plan skip_all => 'Test::mysqld and PocketIO::Client::IO and Authen::Htpasswd are required to run this test'
      unless eval {
        require Test::mysqld; require PocketIO::Client::IO;
        require Authen::Htpasswd;
        1;
      };
}

my $mysqld = t::Utils->setup_mysqld( schema => './db/init.sql' );
my $config = {
    database => { connect_info => [ $mysqld->dsn ] },
    'server_info' => {
        version       => '1.00',
        name          => 'Hachoji.pm',
        default_tag   => 'PUBLIC',
        introduction  => 'テストサーバ',
        auth_endpoint => {
            '/login'   => [
                'BasicAuth' => {
                    passwd_file  => '.htpasswd',
                    check_hashes => ['plain'],
                    realm        => 'Hachioji.pm',
                },
            ],
        }
    },
};

my $data_storage = Yairc::DataStorage::DBI->connect(
                            connect_info => $config->{ database }->{ connect_info } );

my $sys = Yairc->new( config => $config, data_storage => $data_storage );

# make password file
open( my $fh, '>', '.htpasswd' ) or die $!;
print $fh "user:foobar\n";
close($fh);

my $server = builder {
    enable 'Session';

    $sys->build_psgi_endpoint_from_server_info('auth');

    mount '/socket.io' => PocketIO->new(
            socketio => $config->{ socketio },
            instance => $sys,
    );

    mount '/' => sub { [200, ['Content-Length'=>2], ['ok']] },
};

my $client = sub {
    my ( $port ) = shift;

    my $cv = AnyEvent->condvar;
    my $w  = AnyEvent->timer( after => 10, cb => sub {
        fail("Time out.");
        $cv->send;
    } );

    my $client = Yairc::Client->new();

    $client->{ua}->requests_redirectable([]);
    $client->{url} = "http://localhost:$port/";

    my $url    = "http://localhost:$port/login";
    my $res = $client->{ua}->get( $url );
    is( $res->code, 401, 'unauthorized' );

    $client->{ua}->credentials( "localhost:$port", 'Hachioji.pm', 'user', 'hoge' );
    $res = $client->{ua}->get( $url );
    is( $res->code, 401, 'unauthorized' );

    $client->{ua}->credentials( "localhost:$port", 'Hachioji.pm', 'user', 'foobar' );
    $res = $client->{ua}->get( $url );
    is( $res->code, 302, 'authorized' );

    my ( $token ) = $res->header('set-cookie') =~ /yairc_auto_login_token=([-\w]+);/;
    ok( $client->token( $token ), 'token' );

    $client->connect;

    $client->run(sub {
        my ( $self, $socket ) = @_;
        $client->socket->on('token login', sub {
            my $status = $_[1]->{ status };
            if ( $_[1]->{ status } eq 'ok' ) {
                $cv->send;
            }
        });
        $socket->emit('token login', $client->token);
    });

    $cv->wait;
};

test_pocketio $server, $client;

ok(1, 'test done');

unlink('.htpasswd') or warn $!;

done_testing;

