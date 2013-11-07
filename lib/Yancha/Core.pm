package Yancha::Core;

use strict;
use warnings;
use utf8;
use JSON;
use Encode;
use Data::Dumper;

our $VERSION = '0.01';

use constant DEBUG => $ENV{ YANCHA_DEBUG };

sub new {
    my $class = shift;
    bless { @_ }, $class;
}

sub sys { $_[0]->{ sys }; }

sub DESTROY {
    #print STDERR "destroied.\n";
}


sub w ($) {
    my ($text) = @_;
    print STDERR encode('UTF-8', $text), "\n";
}

sub dispatch {
    my ( $self ) = @_;
    return sub {
        my ($socket, $env) = @_;
        # $env is empty until PocketIO version 0.14
        $socket->on( 'server info'  => sub { $self->sys->server_info( @_ ) } );
        $socket->on( 'user message' => sub { $self->user_message( @_ ); } );
        $socket->on( 'plusplus'     => sub { $self->plusplus( @_ ); } );
        $socket->on( 'token login'  => sub { $self->token_login( @_ ); } );
        $socket->on( 'join tag'     => sub { $self->join_tag( @_ ); } );
        $socket->on( 'disconnect'   => sub { $self->disconnect( @_ ); } );
        $socket->on( 'fukumotosan'  => sub { $self->fukumotosan( @_ ); } );
        $socket->on( 'delete user message'   => sub { $self->delete_user_message( @_ ); } );
        $self->sys->call_hook( 'connected', $socket, $env );
    };
}

sub token_login {
    my ($self, $socket, $token, $cb) = @_;
    my $user = $self->sys->data_storage->get_user_by_token( $token );

    my $user_client_info = $socket->{conn}->{on_connect_args}->[0];
    my $remote_addr = ($user_client_info->{"HTTP_X_FORWARDED_FOR"}) ? $user_client_info->{"HTTP_X_FORWARDED_FOR"} : $user_client_info->{REMOTE_ADDR};
    $user->{client} = {
        remote_addr => $remote_addr,
        server_info => $user_client_info->{HTTP_HOST},
        user_agent  => $user_client_info->{HTTP_USER_AGENT},
    };

    #TODO tokenが無い場合のエラー
    unless($user){
        $socket->emit('token login', { "status"=>"user notfound" });
        return;
    }

    my $socket_id = $socket->id();
    my $users = $self->sys->users;

    if($users->{ $socket_id }){
        DEBUG && w sprintf('%s: already logined', $socket->id );
        $socket->emit('token login', {
          "status"    => "ok",
          "user_data" => $user,
        });
        return;
    }

    $self->sys->call_hook( 'token_logined', $socket, $user );

    my $nickname = $user->{nickname};

    DEBUG && w sprintf('%s: hello %s (%s)', $socket->id, _nickname_and_token( $user, 8 ));

    $socket->set(user_data => $user);

    #nickname listを更新し、周知
    $users->{ $socket_id } = $user;
    $socket->sockets->emit('nicknames', _get_uniq_and_anon_nicknames($users));

    #サーバー告知メッセージ
    $socket->broadcast->emit('announcement', $nickname . ' connected');

    $socket->emit('token login', {
      "status"    => "ok",
      "user_data" => $user,
    });

    $cb->(JSON::true);
}

sub join_tag { #参加タグの登録（タグ毎のコネクションプールの管理）
    my ($self, $socket, $tag_and_time, $cb) = @_;

    unless ( $tag_and_time and ref( $tag_and_time ) eq 'HASH' ) {
        DEBUG && w( "Invalid object was passed to join_tag." );
        $tag_and_time = {};
    }
    elsif ( scalar( keys %$tag_and_time ) > 20 ) {
        # タグの数に制限かけないとDOSアタックできる
        DEBUG && w( "So many tags were passed to join_tag." );
        $tag_and_time = {};
    }
    else {
        %{ $tag_and_time } = map { uc($_) => $tag_and_time->{ $_ } } keys %{ $tag_and_time  };
    }

    my $log_limit = $self->sys->config->{ message_log_limit };
    my $on_added  = sub {
        my ( $socket, $tag ) = @_;
        $self->_send_lastlog_by_tag_lastusec( $socket, $tag, $tag_and_time->{$tag}, $log_limit );
    };

    my @new_joined_tags = keys %{ $tag_and_time };

    $self->sys->call_hook( 'join_tag', $socket, \@new_joined_tags );
    $self->sys->add_tag_socket( $socket, \@new_joined_tags, { on_added => $on_added } );
    $self->sys->call_hook( 'after_sent_log', $socket );

    #更新した参加タグをレスポンス
    $socket->emit('join tag', $tag_and_time);
}

sub user_message {
    my ( $self, $socket, $message ) = @_;
    my $ctx = { record_post => 1 }; # このメッセージに対する各プラグイン間でのやりとり用

    $self->sys->call_hook( 'user_message', $socket, \$message, $ctx );

    my @tags = $self->sys->extract_tags_from_text( $message );

    $self->sys->tag_trigger( $socket, \@tags, \$message, $ctx );

    $self->sys->add_default_tag( \@tags, \$message ) unless @tags;

    #pocketio のソケット毎ストレージから自分のニックネームを取り出す
    $socket->get('user_data' => sub {
        my ($socket, $err, $user) = @_;

        #userがない(セッションが無い)場合、再ログインを依頼して終わる。
        if(!defined($user)){
            $socket->emit('no session', $message);
            return;
        }

        my $post = $self->sys->data_storage
                        ->make_post({ text => $message, tags => [ @tags ], user =>  $user });

        $self->sys->call_hook( 'before_send_post', $socket, $post, $ctx );

        $post = $self->sys->data_storage->add_post( $post ) if $ctx->{ record_post };

        $post->{is_message_log} = JSON::false;

        DEBUG && w sprintf('Send message from %s (%s) => "%s"',
                                    _nickname_and_token( $user, 8 ), $message);

        #タグ毎に送信処理
        $self->sys->send_post_to_tag_joined( $post => \@tags );
    });
}

sub plusplus {
    my ( $self, $socket, $post_id ) = @_;

    $self->sys->data_storage->plusplus($post_id);

    my $post = $self->sys->data_storage->get_post_by_id( $post_id );

    $post->{is_message_log} = JSON::true;

    $self->sys->send_post_to_tag_joined( $post => $post->{ tags } );
}

sub fukumotosan {
    my ( $self, $socket ) = @_;

    $socket->get('user_data' => sub {
        my ($socket, $err, $user) = @_;

        if(!defined($user)){
            $socket->emit('no session');
            return;
        }

        my $client_info = $user->{client};
        my $message = <<"EOM";
User-Agent: $client_info->{user_agent}
Remote-Address: $client_info->{remote_addr}
Server: $client_info->{server_info} #PUBLIC #FUKUMOTOSAN
EOM

        $self->user_message($socket, $message);
    });
}

sub delete_user_message {
    my ( $self, $socket, $post_id ) = @_;

    #pocketio のソケット毎ストレージから自分のニックネームを取り出す
    $socket->get('user_data' => sub {
        my ($socket, $err, $user) = @_;

        #userがない(セッションが無い)場合、再ログインを依頼して終わる。
        if(!defined($user)){
            return;
        }

        my $post = $self->sys->data_storage->get_post_by_id( $post_id );

        if($post->{user_key} ne $user->{user_key}){
          DEBUG && w sprintf('delete message but mismatch user_key %s / %s',
                                     $post->{user_key}, $user->{user_key});
          return;

        }

        DEBUG && w sprintf('delete message from %s (%s) => "%s"',
                                    _nickname_and_token( $user, 8 ), $post_id);

        my $result = $self->sys->data_storage->remove_post($post);

        if($result){
          $post->{is_message_log} = JSON::true;

          $self->sys->send_delete_post_to_tag_joined( $post => $post->{ tags } );
        }
    });
}


sub disconnect {
    my ( $self, $socket ) = @_;

    $socket->get(
        'user_data' => sub {
            my ($socket, $err, $user) = @_;
            my $users = $self->sys->users;
            my $tags  = $self->sys->tags;

            $self->sys->call_hook( 'disconnected', $socket, $user );

            if( !defined($user) ){
                DEBUG && w sprintf('%s: bye unlogined user', $socket->id);
                return;
            }

            $self->sys->remove_tag_socket( $socket );

            $socket->broadcast->emit('announcement', $user->{ nickname } . ' disconnected');
            $socket->broadcast->emit('nicknames', _get_uniq_and_anon_nicknames($users));

            DEBUG && w sprintf('%s: bye %s (%s)', $socket->id, _nickname_and_token( $user, 8 ));
        }
    );
}

#
# INTERNAL
#

sub _send_lastlog_by_tag_lastusec {
    my ($self, $pio, $tag, $lastusec, $limit) = @_;

    my $posts = $self->sys->data_storage->get_last_posts_by_tag( $tag, $lastusec, $limit );

    foreach my $post ( reverse( @$posts ) ){
        $post->{'is_message_log'} = JSON::true;
        $pio->emit('user message', $post);
    }
}

sub _get_uniq_and_anon_nicknames {
    my ( $users ) = @_;
    return { map { $_->{ nickname } => $_->{ nickname } } values %$users };
}

sub _nickname_and_token {
    my ( $user, $num ) = @_;
    if ( $num ) {
        return ( $user->{ nickname }, substr( $user->{ token }, 0, $num ) . '...' );
    }
    else {
        return ( $user->{ nickname }, $user->{ token } );
    }
}

1;
__END__

