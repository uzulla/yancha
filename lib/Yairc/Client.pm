package Yairc::Client;

use strict;
use warnings;
use PocketIO::Client::IO;
use LWP::UserAgent;
#use HTTP::Cookies;
use Carp ();

sub new {
    my $class = shift;
    my %opt   = @_;

    $opt{ ua } ||= LWP::UserAgent->new( exists $opt{ ua_opts } ? %{$opt{ ua_opts }} : () );

    return bless \%opt, $class;
}


sub login {
    my ( $self, $url, $login_point, $user ) = @_;

    $self->{ url } = $url;

    $login_point = $url =~ m{/$} ? $url . $login_point : "$url/$login_point";
    my $res = $self->{ua}->post( $login_point, $user );

    if ( $res->is_error ) {
        Carp::carp( "login error: " . $res->content );
        return;
    }

    #my $cookie = HTTP::Cookies->new->extract_cookies($res); # use?
    #$self->{ cookie } = $cookie;

    my ( $token ) = $res->header('set-cookie') =~ /yairc_auto_login_token=([-\w]+);/;

    $self->token( $token );

    return 1;    
}

sub connect {
    my ( $self, $url ) = @_;
    $url ||= $self->{ url };
    my $socket = PocketIO::Client::IO->connect( $url );

    unless ( $socket ) {
        Carp::carp("connection fail.");
        return;
    }

    $socket->on('user message', sub {});
    $socket->on('join tag', sub {});
    $socket->on('nicknames', sub {});
    $socket->on('announcement', sub {});
    $socket->on('token login', sub {});
    $socket->on('no session', sub {});

    $self->socket( $socket );

    return 1;
}

sub run {
    my ( $self, $subref ) = @_;
    my $socket = $self->{ socket };
    $socket->on( 'connect', sub { $subref->( $self, $socket ) } );
}

sub token {
    $_[0]->{ token } = $_[1] if @_ > 1;
    $_[0]->{ token };    
};

sub socket {
    $_[0]->{ socket } = $_[1] if @_ > 1;
    $_[0]->{ socket };
};

sub set_tags {
    my $self   = shift;
    my $subref = pop;
    my ( @tags ) = @_;
    my %tag = map { uc $_ => uc $_ } @tags;
    $self->socket->on('join tag', $subref);
    $self->socket->emit( 'join tag', \%tag );
}

1;
__END__

=encoding utf8

=head1 NAME

Yairc::Client - Yairc用簡易クライアント

=head1 SYNOPSIS

    use Yairc::Client;
    use Data::Dumper;

    my $client = Yairc::Client->new();

    my $cv = AnyEvent->condvar;
    my $w; $w = AnyEvent->timer( after => 30, cb => sub {
        print "Time out.\n";
        $cv->send;
    } );

    $client->login( 'http://localhost:3000/', => 'login', {nick => 'test_client'} );
    $client->connect;

    $client->run(sub {
        my ( $self, $socket ) = @_;

        $socket->on('nicknames', sub {
            my ( $self, $data ) = @_;
            print Data::Dumper( $data );
            $cv->send;
        });

        $socket->emit('token login', $self->token);
    });

    $cv->wait;

=head1 DESCRIPTION

テストやbot用にどうぞ

=head1 METHODS

=head2 new

    $client = Yairc::Client->new( %opt );

新しいオブジェクトの生成。
オプション

=over

=item ua

L<LWP::UserAgent>オブジェクト。
もしくはpostメソッド互換のあるオブジェクト。

=item ua_opts

uaオプションを渡していないとき内部で自動生成される
L<LWP::UserAgent>オブジェクトに渡す引数を指定。

=back

=head2 login

    $bool = $client->login( $url, $login_point, $field );

トークンを得るためのログインを行う。
$fieldはinputフィールドのnameとvalueのハッシュ。
現状simpleログインのみ対応。
成功するとC<< $client->token >>でトークンを取り出せる。

=head2 connect

    $bool = $client->connect();
    $bool = $client->connect( $url );

コネクションをはる。$urlを指定しなければloginで指定したurlが利用される。

=head2 run

        $client->run( $subref );

サーバ接続後の処理を非同期で実行。
$subrefにはクライアント自身と、PocketIO::Socketが渡される。

    sub {
        my ( $client, $socket ) = @_;

    }

=head2 token

    $client->token( $token );
    $token = $client->token;

トークンのgetter/setter。
Yaircはログインの有無をこのトークンでチェックしている。

=head1 TODO

=over

=item Twitterログインに対応する

=item reconnect

=back

=head1 SEE ALSO

L<Yairc>, L<PocketIO>, L<PocketIO::Cleint::IO>, L<AnyEvent>, L<LWP::UserAgent>

=cut


