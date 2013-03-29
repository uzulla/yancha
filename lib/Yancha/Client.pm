package Yancha::Client;

use strict;
use warnings;
use PocketIO::Client::IO;
use Carp ();

my @event_list = (
    'user message',
    'join tag',
    'nicknames',
    'announcement',
    'token login',
    'no session',
    'plusplus', 
);

sub new {
    my $class = shift;
    my %opt   = @_;

    $opt{ ua } ||= do {
        require LWP::UserAgent;
        LWP::UserAgent->new( exists $opt{ ua_opts } ? %{$opt{ ua_opts }} : () );
    };
    $opt{ tags } ||= { 'PUBLIC' => '0' };
    $opt{ event }{ $_ } ||= sub {} for @event_list;

    return bless \%opt, $class;
}


sub login {
    my ( $self, $url, $login_point, $user ) = @_;

    my $token = $self->retrieve_token( $url, $login_point, $user );
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

    $socket->on($_ => $self->{event}{$_}) for @event_list;

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
    my %tag = map { uc $_ => 0 } @tags;

    $self->{ tags } = { %tag };

    $self->socket->on('join tag', $subref);
    $self->socket->emit( 'join tag', \%tag );
}

sub update_tags_ltime_from_post {
    my ( $self, $post ) = @_;
    for my $tag ( @{ $post->{ tags } || [] } ) {
        $self->{ tags }->{ $tag } = $post->{ created_at_ms };
    }
    return;
}

sub retrieve_token {
    my ( $self, $url, $login_point, $user ) = @_;

    $self->{ url } = $url;

    $login_point = $url =~ m{/$} ? $url . $login_point : "$url/$login_point";
    my $user_agent = $self->{ua};
    my $res = $user_agent->post( $login_point, $user );

    if ( $res->is_error ) {
        Carp::carp( "login error: " . $res->content );
        return;
    }

    my ( $token ) = $res->header('set-cookie') =~ /yancha_auto_login_token=([-\w]+);/;

    return $token;
}

1;
__END__

=encoding utf8

=head1 NAME

Yancha::Client - Yancha用簡易クライアント

=head1 SYNOPSIS

    use Yancha::Client;
    use Data::Dumper;

    my $client = Yancha::Client->new();

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

    $client = Yancha::Client->new( %opt );

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
Yanchaはログインの有無をこのトークンでチェックしている。

=head1 TODO

=over

=item Twitterログインに対応する

=item reconnect

=back

=head1 SEE ALSO

L<Yancha>, L<PocketIO>, L<PocketIO::Cleint::IO>, L<AnyEvent>, L<LWP::UserAgent>

=cut


