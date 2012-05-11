package Yairc;

use strict;
use warnings;
use utf8;
use JSON;
use DBI;
use Encode;
use Data::Dumper;

our $VERSION = '0.01';

use constant DEBUG => $ENV{ YAIRC_DEBUG };

my $nicknames    = {}; #共有ニックネームリスト
my $tags         = {}; #参加タグ->コネクションプールリスト
my $tags_reverse = {}; #クライアントコネクション->参加Tag リスト


sub new {
    my ( $class, @args ) = @_;
    my $self = bless { @args }, $class;

    return $self;
}

sub data_storage { $_[0]->{ data_storage } } 

sub config { $_[0]->{ config } ||= {} }

sub w {
    my ($text) = @_;
    warn(encode('UTF-8', $text));
}

sub send_lastlog_by_tag_lastusec {
    my ($self, $pio, $tag, $lastusec, $limit) = @_;

    my $posts = $self->data_storage->get_last_posts_by_tag( $tag, $lastusec, $limit );

    foreach my $post ( reverse( @$posts ) ){
        $post->{'is_message_log'} = JSON::true;
        $pio->emit('user message', $self->build_user_message_hash($post));
    }
}

sub extract_tags_from_text {
    my ( $self, $str ) = @_;
    # 将来的にはUnicode Propertyのword(\w)にしたいが、ui側の変更も必要
    # タグ前のスペース、全角にも対応
    my @tags = map { uc($_) } $str =~ /(?:^| |　)#([a-zA-Z0-9]{1,32})(?= |$)/mg;
    return @tags > 10 ? @tags[0..9] : @tags;
}

sub build_user_message_hash {
    my ( $self, $hash ) = @_;
    $hash->{tags} = [ $self->extract_tags_from_text($hash->{text}) ];
    return $hash;
}

sub get_uniq_and_anon_nicknames_list {
    my ( $nicknames ) = @_;
    my $uniq_nicknames = {};
    foreach my $nick (values(%$nicknames)) {
      $uniq_nicknames->{$nick} = $nick;
    }
    return $uniq_nicknames;
}

#
# 実処理
#

sub run {
    my ( $self ) = @_;

    return sub {
        my ($socket, $env) = @_;

        $socket->on(
            'user message' => sub {
                $self->user_message( @_ );
            }   
        );

        $socket->on(
            'token_login' => sub {
                $self->token_login( @_ );
            }
        );

        $socket->on( #参加タグの登録（タグ毎のコネクションプールの管理）
            'join_tag' => sub {
                $self->join_tag( @_ );
            }
        );

        $socket->on( #切断時処理
            'disconnect' => sub {
                $self->disconnect( @_ );
            }
        );
    }

}

#
# Application Part
# TODO: 何とかする
#

sub user_message {
    my ( $self, $socket, $message ) = @_;

    #メッセージ内のタグをリストに
    my @tags = $self->extract_tags_from_text($message);
                
    #タグがみつからなかったら、#PUBLICタグを付けておく
    if ( @tags == 0 ){
        $message = $message . " #PUBLIC";
        push( @tags, "PUBLIC" );
    }
    
    #pocketio のソケット毎ストレージから自分のニックネームを取り出す
    $socket->get('user_data' => sub {
        my ($socket, $err, $user) = @_;

        #userがない(セッションが無い)場合、再ログインを依頼して終わる。
        if(!defined($user)){
            $socket->emit('no session', $message);
            return;
        }

        #DBに保存
        my $post = $self->data_storage->add_post( { text => $message, tags => [ @tags ] }, $user );

        #タグ毎に送信処理
        foreach my $i ( @tags) {
            if($tags->{$i}){
                DEBUG && w "Send to ${i} from $user->{nickname} => \"${message}\"";
        
                #ちょいとややこしいPocketIOの直接Poolを触る場合
                my $event = PocketIO::Message->new(
                    type => 'event',
                    data => {
                        name => 'user message',
                        args => [ $self->build_user_message_hash( {
                                %$post, 'is_message_log' => JSON::false,
                            } ) 
                        ]
                    }
                );
                $tags->{$i}->send($event);
            }
        }
    });
}

sub token_login {
    my ($self, $socket, $token, $cb) = @_;
    my $user = $self->data_storage->get_user_by_token( $token );

    #TODO tokenが無い場合のエラー
    unless($user){
        $socket->emit('token_login', { "status"=>"user notfound" });
    }

    my $nickname = $user->{nickname};

    DEBUG && w "hello $nickname";
    
    $socket->set(user_data => $user);
    
    my $socket_id = $socket->id();
    
    #nickname listを更新し、周知
    $nicknames->{$socket_id} = $user->{nickname};
    $socket->sockets->emit('nicknames', get_uniq_and_anon_nicknames_list($nicknames));

    #サーバー告知メッセージ
    $socket->broadcast->emit('announcement', $nickname . ' connected');
    
    $socket->emit('token_login', {
      "status"    => "ok",
      "user_data" => $user,
    });
    
    $cb->(JSON::true);
}

sub join_tag { #あまりにも適当な実装なので、後でリファクタる必要あり
    my ($self, $socket, $tag_list, $cb) = @_;
    
    my $h = {};
    foreach my $k ( keys(%$tag_list) ){
        $h->{uc $k} = $tag_list->{$k};
    }
    
    $tag_list = $h;

    #現在の（自分の）SocketIDを取得
    my $socket_id = $socket->id();
    
    #SocketID->参加Tagテーブルの初期化
    if( !$tags_reverse->{$socket_id} ) {
      $tags_reverse->{$socket_id} = ();
    }

    my $log_limit   = $self->config->{ message_log_limit };
    my $joined_tags = $tags_reverse->{$socket_id};
    #テンポラリ
    my @new_joined_tags = ();
    #タグ毎にPocketIO::Poolを作成して、自分の接続を追加
    foreach my $tag ( keys(%$tag_list) ) {
        #w $tag;
        if( !$tags->{$tag} ) {
            $tags->{$tag} = PocketIO::Pool->new();
        }
        $tags->{$tag}->{connections}->{$socket_id} = $socket->{conn};
      
      my $lastusec = $tag_list->{$tag};
      $self->send_lastlog_by_tag_lastusec($socket, $tag, $lastusec, $log_limit);
      
      push(@new_joined_tags, $tag);
    }
    
    #send_lastlog_by_tags_lastusec($self, \@new_joined_tags, $lastusec);
    
    #前と、今の接続を比較して、なくなったタグをリストアップ
    my $diff = {};
    
    foreach my $k(@$joined_tags){
      $diff->{$k} += 1;
    }
    foreach my $k(@new_joined_tags){
      $diff->{$k} += 2;
    }
    #w Dumper($diff);
    
    #無くなったタグを消していく
    foreach my $d(keys %$diff){
      if($diff->{$d}==1){
        #remove
        #w "delete tag ".$d;
        delete $tags->{$d}->{connections}->{$socket_id}; 
      }elsif($diff->{$d}==2){
        #new
      }elsif($diff->{$d}==3){
        #exists
      }
    }
    
    #SID＞tagテーブル更新
    @{$tags_reverse->{$socket_id}} = @new_joined_tags;
    
    #更新した参加タグをレスポンス
    $socket->emit('join_tag', $tag_list);
    
    #w "dump tags--";
    #w Dumper($tags);
}

sub disconnect {
    my ( $self, $socket ) = @_;

    $socket->get(
        'user_data' => sub {
            my ($socket, $err, $user) = @_;

            if( !defined($user) ){
                DEBUG && w "bye undefined nickname user";
                return;
            }
            my $nickname = $user->{ nickname };

            my $socket_id = $socket->id();
            delete $nicknames->{$socket_id};
            
            #タグ毎にできたPool等からも削除
            my $joined_tags = $tags_reverse->{$socket_id};
            foreach my $k ( @$joined_tags ) {
                delete $tags->{$k}->{connections}->{$socket_id};
            }
            
            delete $tags_reverse->{$socket_id};
            
            #w 'delete conn from pool';
            #w Dumper($tags);
            #w Dumper($tags_reverse);
            
            $socket->broadcast->emit('announcement', $nickname . ' disconnected');
            $socket->broadcast->emit('nicknames', get_uniq_and_anon_nicknames_list($nicknames));

            DEBUG && w "bye ".$nickname;
        }
    );
}


1;
__END__

