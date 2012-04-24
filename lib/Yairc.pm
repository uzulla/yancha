package Yairc;

use strict;
use warnings;
use JSON;
use DBI;
use Encode;
use Time::HiRes qw/ time /;

our $VERSION = '0.01';

my $nicknames    = {}; #共有ニックネームリスト
my $tags         = {}; #参加タグ->コネクションプールリスト
my $tags_reverse = {}; #クライアントコネクション->参加Tag リスト


sub new {
    my ( $class, @args ) = @_;
    my $self = bless { @args }, $class;
    my $dbh  = $self->{ dbh };

    $self->{ insert_post_sth } = $dbh->prepare('INSERT INTO `post` (`by`, `text`, `created_at_ms`) VALUES (?, ?, ?) ');
    $self->{ select_lastlog_by_tag_lastusec_sth } = $dbh->prepare('SELECT * FROM `post` WHERE `text` like ? AND `created_at_ms` > ? ORDER BY `created_at_ms` DESC LIMIT 100 ');

    return $self;
}

sub w {
    my ($text) = @_;
    warn(encode('UTF-8', $text));
}

sub insert_post {
    my ($self, $by, $text) = @_;
    $self->{ insert_post_sth }->execute( $by, $text, get_now_micro_sec() );
    return;
}

sub send_lastlog_by_tag_lastusec {
    my ($self, $pio, $tag, $lastusec) = @_;
    my $select_lastlog_by_tag_lastusec_sth = $self->{ select_lastlog_by_tag_lastusec_sth };
    my $rv = $select_lastlog_by_tag_lastusec_sth->execute( '%#'.$tag.'%', $lastusec );

    my @hash_list = ();  
    while( my $hash = $select_lastlog_by_tag_lastusec_sth->fetchrow_hashref() ){
        push(@hash_list, $hash);
    }

    foreach my $hash(reverse(@hash_list)){
        $pio->emit('user message log', build_user_message_hash($hash));
    }
}

sub get_now_micro_sec{
    return Time::HiRes::time() * 100_000;
}

sub build_tag_list_from_text{
    my ($str) = @_;
    my %tag = map { uc($_) => 1 } $str =~ /#([a-zA-Z0-9]+)/g; #もっと良い感じのタグ判定正規表現にしないといけない
    return keys %tag;
}

sub build_user_message_hash{
    my ($hash) = @_;
    @{$hash->{tags}} = build_tag_list_from_text($hash->{text});
    return $hash;
}


sub run {
    my ( $app ) = @_;

    return sub {
        my $self = shift;

        $self->on(
            'user message' => sub {
                my $self = shift;
                my ($message) = @_;
                
                #メッセージ内のタグをリストに
                my @tag_list = build_tag_list_from_text($message);
                
                #タグがみつからなかったら、#PUBLICタグを付けておく
                if($#tag_list == -1){
                  $message = $message . " #PUBLIC";
                  push(@tag_list, "PUBLIC" );
                }
                
                #pocketio のソケット毎ストレージから自分のニックネームを取り出す
                $self->get('nick' => sub {
                  my ($self, $err, $nick) = @_;
                  
                  #nickがない場合、ニックネーム再登録を依頼して終わる。
                  if(!defined($nick) || $nick eq ''){
                    $self->emit('nickname', $message);
                    return;
                  }
                  
                  #DBに保存
                  $app->insert_post($nick, $message);
                  
                  #タグ毎に送信処理
                  foreach my $i (@tag_list){
                    if($tags->{$i}){
                      w "Send to ${i} from ${nick} => \"${message}\"";
                      
                      #ちょいとややこしいPocketIOの直接Poolを触る場合
                      my $event = PocketIO::Message->new(type => 'event', data => {name => 'user message', args => build_user_message_hash( {
                        'created_at_ms' => get_now_micro_sec(),
                        'text' => $message,
                        'id' => -1,#DBに保存されていないと、IDが振られないので
                        'by' => $nick
                        })
                      });
                      $tags->{$i}->send($event);
                    }
                  }
                });
            });

            #接続維持のPing
            $self->on(
              'ping pong' => sub {
                my $self = shift;
                my ($message) = @_;

                $self->get('nick' => sub {
                  my ($self, $err, $nick) = @_;
                  if(!defined($nick) || $nick eq ''){
                    $self->emit('ping pong', 'FAIL');
                    return;
                  }

                  $self->emit('ping pong', 'PONG');
                });
              }
            );

            #自分のニックネーム登録、これは必要なのか何とも言えない、ログイン代わり
            $self->on(
                'nickname' => sub {
                    my $self = shift;
                    my ($nick, $cb) = @_;

#                     if ($nicknames->{$nick}) { #同一名称ではじく必要ないんじゃないの？
#                         $cb->(JSON::true);
#                     } else {
                        w "hello ${nick}";

                        $cb->(JSON::false);
                        $self->set(nick => $nick);
                        
                        #nickname listを更新し、周知
                        $nicknames->{$nick} = $nick;
                        $self->sockets->emit('nicknames', $nicknames);

                        #サーバー告知メッセージ
                        $self->broadcast->emit('announcement', $nick . ' connected');
#                     }
                }
            );

            #参加タグの登録（タグ毎のコネクションプールの管理）
            $self->on(
                'join_tag' => sub {
                    #あまりにも適当な実装なので、後でリファクタる必要あり
                    my $self = shift;
                    my ($tag_list, $cb) = @_;
                    
                    my $h = {};
                    foreach my $k (keys(%$tag_list)){
                      $h->{uc $k} = $tag_list->{$k};
                    }
                    
                    $tag_list = $h;

                    #現在の（自分の）SocketIDを取得
                    my $socket_id = $self->id();
                    
                    #SocketID->参加Tagテーブルの初期化
                    if(!$tags_reverse->{$socket_id}){
                      $tags_reverse->{$socket_id} = ();
                    }
                    
                    my $joined_tags = $tags_reverse->{$socket_id};
                    #テンポラリ
                    my @new_joined_tags = ();
                    #タグ毎にPocketIO::Poolを作成して、自分の接続を追加
                    foreach my $tag (keys(%$tag_list)){
                      #w $tag;
                      if(!$tags->{$tag}){
                        $tags->{$tag} = PocketIO::Pool->new();
                      }
                      $tags->{$tag}->{connections}->{$socket_id} = $self->{conn};
                      
                      my $lastusec = $tag_list->{$tag};
                      $app->send_lastlog_by_tag_lastusec($self, $tag, $lastusec);
                      
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
                    $self->emit('join_tag', $tag_list);
                    
                    #w "dump tags--";
                    #w Dumper($tags);
                }
            );

            #切断時処理
            $self->on(
                'disconnect' => sub {
                    my $self = shift;

                    $self->get(
                        'nick' => sub {
                            my ($self, $err, $nick) = @_;
                            
                            if(!defined($nick)){
                              w "bye undefined nickname user";
                              return;
                            }

                            delete $nicknames->{$nick};
                            
                            #タグ毎にできたPool等からも削除
                            my $socket_id = $self->id();
                            my $joined_tags = $tags_reverse->{$socket_id};
                            foreach my $k(@$joined_tags){
                               delete $tags->{$k}->{connections}->{$socket_id};
                            }
                            
                            delete $tags_reverse->{$socket_id};
                            
                            #w 'delete conn from pool';
                            #w Dumper($tags);
                            #w Dumper($tags_reverse);
                            
                            $self->broadcast->emit('announcement',
                                $nick . ' disconnected'); #nickがないときにエラー
                            $self->broadcast->emit('nicknames', $nicknames);

                            w "bye ".$nick;
                        }
                    );
                }
            );
        }

}

1;
__END__

