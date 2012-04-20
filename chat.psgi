my $root;

BEGIN {
    use File::Basename ();
    use File::Spec     ();

    $root = File::Basename::dirname(__FILE__);
    $root = File::Spec->rel2abs($root);

    unshift @INC, "$root/../../lib";
}

use strict;
#use utf8;
use PocketIO;
use DBI;
use JSON;
use Plack::App::File;
use Plack::Builder;
use Plack::Middleware::Static;
use Encode;
use Time::HiRes qw/ time /;
use Data::Dumper;

my $nicknames = {};
my $tags = {};
my $tags_reverse = {};

my $dbh =  DBI->connect('dbi:mysql:host=localhost;database=yairc', 'yairc', 'yairc') || die DBI::errstr;  
#$dbh->do('SET NAMES utf8');

my $insert_post_sth = $dbh->prepare('INSERT INTO `post` (`by`, `text`, `created_at_ms`) VALUES (?, ?, ?) ');
my $select_lastlog_by_tag_lastusec_sth = $dbh->prepare('SELECT * FROM `post` WHERE `text` like ? AND `created_at_ms` > ? ORDER BY `created_at_ms` DESC LIMIT 100 ');

sub insert_post {
  my ($by, $text) = @_;
  $insert_post_sth->execute( (encode('UTF-8', $by), encode('UTF-8',$text), get_now_micro_sec()) );
  return;
}

sub w {
  my ($text) = @_;
  warn(encode('UTF-8', $text));
}

sub get_now_micro_sec{
  my $time = Time::HiRes::time();
  return $time * 100_000;
}


sub send_lastlog_by_tag_lastusec{
  my ($pio, $tag, $lastusec) = @_;
  
  #w 'send_lastlog_by_tag_lastusec------------';
  #w $tag;
  #w $lastusec;  
  
  my $rv = $select_lastlog_by_tag_lastusec_sth->execute( (encode('UTF-8', '%#'.$tag.'%'), $lastusec) );

  my @hash_list = ();  
  while(my $hash = $select_lastlog_by_tag_lastusec_sth->fetchrow_hashref()){
    push(@hash_list, decodeUTF8hash($hash));
  }

  foreach my $hash(reverse(@hash_list)){
    #w Dumper $hash;
    $pio->emit('user message log', build_user_message_hash($hash));
  }
}

sub decodeUTF8hash{
  my ($hash) = @_;

  my $rtn = {};
  foreach my $i (keys $hash){
    $rtn->{$i} = decode('UTF-8', $hash->{$i} );
  } 
  
  return $rtn;

}

sub build_tag_list_from_text{
  w 'build_tag_list_from_text';
  my ($str) = @_;
  w $str;
  my @match = $str =~ /#([a-zA-Z0-9]+)/g; 
  #  /(?:^|[^ー゛゜々ヾヽぁ-ヶ一-龠ａ-ｚＡ-Ｚ０-９a-zA-Z0-9&_\/]+)[#](\w*[a-zA-Z_]\w*)/; #
  w Dumper(@match);
  my $h;
  foreach my $k (@match){
    my $s = uc($match[$k]);
    $h->{$s} = 1;
  }
  
  w Dumper $h;
  
  return keys(%$h);
}

sub build_user_message_hash{
  my ($hash) = @_;
  @{$hash->{tags}} = build_tag_list_from_text($hash->{text});
  #$hash = encodeUTF8hash($hash);
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
                
                
                #正規表現でタグを抜いておく、タグがみつからなかったら、PUBLICに?
                my @tag_list = build_tag_list_from_text($message);
                
                if($#tag_list == -1){
                  $message = $message . " #PUBLIC";
                  push(@tag_list, "PUBLIC" );
                }
                
                $self->get('nick' => sub {
                  my ($self, $err, $nick) = @_;
                  
#                  if(length($message)>1024){}
                  
                  if($nick eq ''){
                    $self->emit('nickname', $message);
                    return;
                  }
                  insert_post($nick, $message);
                  
                  #w '--------------';
                  #w Dumper(@tag_list);
                  
                  foreach my $i (@tag_list){
                    #w $i;
                    #w $tag_list[$i];
                    if($tags->{$tag_list[$i]}){
                      #w "Send to ${tag_list[$i]} from ${nick} => \"${message}\"";
                      my $event = PocketIO::Message->new(type => 'event', data => {name => 'user message', args => build_user_message_hash( {
                        'created_at_ms' => get_now_micro_sec(),
                        'text' => $message,
                        'id' => -1,
                        'by' => $nick
                        })
                      });
                      $tags->{$tag_list[$i]}->send($event);
                    }
                  }

                  
                });
                
              }
            );
            
            $self->on(
              'ping pong' => sub {
                my $self = shift;
                my ($message) = @_;

                $self->get('nick' => sub {
                  my ($self, $err, $nick) = @_;
                  if($nick eq ''){
                    #w "not registed pingpong ";
                    $self->emit('ping pong', 'FAIL');
                    return;
                  }
                  #w $nick." PING PONG ";

                  $self->emit('ping pong', 'PONG');
                });
              }
            );

            $self->on(
                'nickname' => sub {
                    my $self = shift;
                    my ($nick, $cb) = @_;

#                     if ($nicknames->{$nick}) { #同一名称ではじく必要ないんじゃないの？
#                         $cb->(JSON::true);
#                     } else {
                        $cb->(JSON::false);

                        $self->set(nick => $nick);

                        $nicknames->{$nick} = $nick;
                        #w "hello ".$nick;

                        $self->broadcast->emit('announcement', $nick . ' connected');
                        $self->sockets->emit('nicknames', $nicknames);
#                     }
                }
            );


            $self->on(
                'join_tag' => sub {
                    #あまりにも適当な実装なので、後でリファクタれ
                    my $self = shift;
                    my ($tag_list, $cb) = @_;
                    
                    my $h = {};
                    foreach my $k (keys(%$tag_list)){
                      my $uk = uc $k;
                      $h->{$uk} = $tag_list->{$k};
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


            $self->on(
                'disconnect' => sub {
                    my $self = shift;

                    $self->get(
                        'nick' => sub {
                            my ($self, $err, $nick) = @_;
                            warn "bye ".$nick;
                            delete $nicknames->{$nick};

                            $self->broadcast->emit('announcement',
                                $nick . ' disconnected');
                            $self->broadcast->emit('nicknames', $nicknames);

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
