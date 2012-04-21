my $root;

BEGIN {
    use File::Basename ();
    use File::Spec     ();

    $root = File::Basename::dirname(__FILE__);
    $root = File::Spec->rel2abs($root);

    unshift @INC, "$root/../../lib";
}

use strict;
use utf8;
use warnings;
use PocketIO;
use DBI;
use JSON;
use Plack::App::File;
use Plack::Builder;
use Plack::Middleware::Static;
use Encode;
use Time::HiRes qw/ time /;
use Data::Dumper;
use Config::Pit;

my $nicknames = {}; #共有ニックネームリスト
my $tags = {};#参加タグ->コネクションプールリスト
my $tags_reverse = {};#クライアントコネクション->参加Tag リスト

my $config = pit_get( "yairc", require => {
       "dsn" => "dsn",
       "db_user" => "db username",
       "db_pass" => "db password"
});

my $dbh =  DBI->connect($config->{dsn}, $config->{db_user}, $config->{db_pass}) || die DBI::errstr; #plz change
#$dbh->do("set names utf8");
my $insert_post_sth = $dbh->prepare('INSERT INTO `post` (`by`, `text`, `created_at_ms`) VALUES (?, ?, ?) ');
my $select_lastlog_by_tag_lastusec_sth = $dbh->prepare('SELECT * FROM `post` WHERE `text` like ? AND `created_at_ms` > ? ORDER BY `created_at_ms` DESC LIMIT 100 ');

sub insert_post {
  my ($by, $text) = @_;
  $insert_post_sth->execute( $by, $text, get_now_micro_sec() );
  return;
}

sub send_lastlog_by_tag_lastusec{
  my ($pio, $tag, $lastusec) = @_;
  my $rv = $select_lastlog_by_tag_lastusec_sth->execute( '%#'.$tag.'%', $lastusec );

  my @hash_list = ();  
  while(my $hash = $select_lastlog_by_tag_lastusec_sth->fetchrow_hashref()){
    push(@hash_list, decodeUTF8hash($hash)); #緩募：DBから取ってきてイチイチDecodeしなくていい方法
  }

  foreach my $hash(reverse(@hash_list)){
    $pio->emit('user message log', build_user_message_hash($hash));
  }
}

sub w {
  my ($text) = @_;
  warn(encode('UTF-8', $text));
}

sub get_now_micro_sec{
  return Time::HiRes::time() * 100_000;
}

sub decodeUTF8hash{
  my ($hash) = @_;
  %$hash = map { decode('UTF-8', $_) } %$hash;
  return $hash;
}

sub build_tag_list_from_text{
  my ($str) = @_;
  my @match = $str =~ /#([a-zA-Z0-9]+)/g; #もっと良い感じのタグ判定正規表現にしないといけない
  #delete duplicated tags. and toUpper.
  my $h;
  foreach my $k (@match){
    $h->{uc($k)} = 1;
  }
  return keys(%$h);
}

sub build_user_message_hash{
  my ($hash) = @_;
  @{$hash->{tags}} = build_tag_list_from_text($hash->{text});
  return $hash;
}

builder {
    mount '/socket.io/socket.io.js' =>
      Plack::App::File->new(file => "$root/public/socket.io.js");

    mount '/socket.io/static/flashsocket/WebSocketMain.swf' =>
      Plack::App::File->new(file => "$root/public/WebSocketMain.swf");

    mount '/socket.io/static/flashsocket/WebSocketMainInsecure.swf' =>
      Plack::App::File->new(file => "$root/public/WebSocketMainInsecure.swf");

    mount '/socket.io' => PocketIO->new(
        handler => sub {
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
                  insert_post($nick, $message);
                  
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
              }
            );
            
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

            #自分のニックネーム登録。PocketIOのサンプルコードを流用した為にのこっているが、nickをpocketIOの機能で保存するのは不要では。
            #現状においては、ログイン代わり。
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
                      send_lastlog_by_tag_lastusec($self, $tag, $lastusec);
                      
                      push(@new_joined_tags, $tag);
                    }
                    
                    
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
                    foreach my $d(keys $diff){
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
    );

    mount '/' => builder {
        enable "Static",
          path => qr/\.(?:js|css|jpe?g|gif|png|html?|swf|ico)$/,
          root => "$root/public";

        enable "SimpleLogger", level => 'debug';

        my $html = do {
            local $/;
            open my $fh, '<', "$root/public/chat.html"
              or die $!;
            <$fh>;
        };

        sub {
            [   200,
                [   'Content-Type'   => 'text/html',
                    'Content-Length' => length($html)
                ],
                [$html]
            ];
        };
    };
};
