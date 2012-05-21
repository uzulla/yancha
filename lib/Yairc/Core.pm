package Yairc::Core;

use strict;
use warnings;
use utf8;
use JSON;
use Encode;
use Data::Dumper;

our $VERSION = '0.01';

use constant DEBUG => $ENV{ YAIRC_DEBUG };

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
        $socket->on( 'token login'  => sub { $self->token_login( @_ ); } );
        $socket->on( 'join tag'     => sub { $self->join_tag( @_ ); } );
        $socket->on( 'disconnect'   => sub { $self->disconnect( @_ ); } );
        $self->sys->call_hook( 'connected', $socket, $env );
    };
}

sub token_login {
    my ($self, $socket, $token, $cb) = @_;
    my $user = $self->sys->data_storage->get_user_by_token( $token );

    #TODO tokenが無い場合のエラー
    unless($user){
        $socket->emit('token login', { "status"=>"user notfound" });
        return;
    }

    $self->sys->call_hook( 'token_logined', $socket, $user );

    my $nickname = $user->{nickname};

    DEBUG && w sprintf('%s: hello %s (%s)', $socket->id, $nickname, $user->{ token });
    
    $socket->set(user_data => $user);
    
    my $socket_id = $socket->id();
    
    #nickname listを更新し、周知
    my $users = $self->sys->users;
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

    my $socket_id = $socket->id();

    # 前と今の接続を比較して、なくなったタグをリストアップ
    my @new_joined_tags = keys %{ $tag_and_time };
    my %joined_tag      = map { $_ => 1 } @{ $self->sys->tags_reverse->{$socket_id} ||= [] };

    # タグ毎にPocketIO::Poolを作成して自分の接続を追加、過去ログを送る
    my $log_limit = $self->sys->config->{ message_log_limit };
    my $tags      = $self->sys->tags;

    for my $tag ( @new_joined_tags ) {
        $tags->{ $tag } ||= PocketIO::Pool->new();
        # there is no proper api in PocketIO::Pool class, so manually set.
        $tags->{ $tag }->{connections}->{ $socket_id } = $socket->{conn};
        $self->_send_lastlog_by_tag_lastusec( $socket, $tag, $tag_and_time->{$tag}, $log_limit);
        delete $joined_tag{ $tag };
    }

    # 無くなったタグに紐づくコネクションを消していく
    for my $tag ( keys %joined_tag ) {
        delete $tags->{ $tag }->{connections}->{ $socket_id };
    }

    # SID＞tagテーブル更新
    @{ $self->sys->tags_reverse->{$socket_id} } = @new_joined_tags;
    #更新した参加タグをレスポンス
    $socket->emit('join tag', $tag_and_time);
}

sub user_message {
    my ( $self, $socket, $message ) = @_;

    $self->sys->call_hook( 'user_message', \$message );

    my @tags = $self->sys->extract_tags_from_text( $message );

    $self->sys->tag_trigger( \@tags, $socket, \$message );

    #pocketio のソケット毎ストレージから自分のニックネームを取り出す
    $socket->get('user_data' => sub {
        my ($socket, $err, $user) = @_;

        #userがない(セッションが無い)場合、再ログインを依頼して終わる。
        if(!defined($user)){
            $socket->emit('no session', $message);
            return;
        }

        #DBに保存
        my $post = $self->sys->data_storage
                        ->add_post( { text => $message, tags => [ @tags ] }, $user );

        $post->{is_message_log} = JSON::false;

        DEBUG && w sprintf('Send message from %s (%s) => "%s"',
                                    $user->{ nickname }, $user->{ token}, $message);

        #タグ毎に送信処理
        $self->sys->send_post_to_tag_joined( $post => \@tags );
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
            my $nickname = $user->{ nickname };

            my $socket_id = $socket->id();
            delete $users->{$socket_id};

            #タグ毎にできたPool等からも削除
            my $joined_tags = delete $self->sys->tags_reverse->{$socket_id};
            foreach my $k ( @$joined_tags ) {
                delete $tags->{$k}->{connections}->{$socket_id};
            }

            $socket->broadcast->emit('announcement', $nickname . ' disconnected');
            $socket->broadcast->emit('nicknames', _get_uniq_and_anon_nicknames($users));

            DEBUG && w sprintf('%s: bye %s (%s)', $socket->id, $nickname, $user->{ token });
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

1;
__END__

