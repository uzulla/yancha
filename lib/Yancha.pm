package Yancha;

use strict;
use warnings;
use utf8;
use Carp   ();
use Encode ();
use Data::Dumper ();

our $VERSION = '0.01';

use constant DEBUG => $ENV{ YANCHA_DEBUG };

our $SERVER_INFO =  {
    'version' => $VERSION,
    'name'    => 'Yancha(kari)',
    'introduction'   => 'Hello Hachioji.pm',
};

my $users        = {}; # session id -> user data
my $tags         = {}; # 参加タグ->コネクションプールリスト
my $tags_reverse = {}; # クライアントコネクション->参加Tag リスト


sub new {
    my ( $class, @args ) = @_;
    my $self = bless { @args }, $class;
    $self->load_plugins( $self->config->{ plugins } );
    return $self;
}

sub app {
    $_[0]->{ app } ||= do {
        require Yancha::Core;
        Yancha::Core->new( sys => $_[0] );
    }
}

# もうそろそろアクセサ生成モジュールつかうべきか

sub data_storage { $_[0]->{ data_storage } } 

sub config { $_[0]->{ config } ||= {} }

sub users { $users; }

sub tags { $tags; }

sub tags_reverse { $tags_reverse; }

sub extract_tags_from_text {
    my ( $self, $str ) = @_;
    # 将来的にはUnicode Propertyのword(\w)にしたいが、ui側の変更も必要
    # タグ前のスペース、全角にも対応
    my @tags = map { uc($_) } $str =~ /(?:^|\s)#([a-zA-Z0-9]{1,32})(?=\s|$)/g;
    return @tags > 10 ? @tags[0..9] : @tags;
}

sub login {
    # TODO 廃止
    my ( $self, $name ) = @_;
    $_[0]->{ login }->{ $name } ||= do {
        my $module = substr( $name, 0, 1 ) eq '+'
                        ? $name : ref( $self ) . '::Auth::' . ucfirst( $name );
        eval qq{ require $module };
        Carp::croak( $@ ) if $@;
        $module->new( data_storage => $self->data_storage, sys => $self );
    };
}


sub build_psgi_endpoint_from_server_info {
    my ( $self, $name, $conf ) = @_;

    unless ( $conf and ref( $conf ) eq 'HASH' ) {
        $conf = $self->config->{ server_info } || {};
        $conf = $conf->{ $name . '_endpoint' };
    }

    unless ( $conf ) {
        Carp::croak( "No $name endpoint config" );
    }

    require Plack::Builder;
    Plack::Builder->import;
    for my $endpoint ( keys %{ $conf } ) {
        my ( $module_name, $arg, undef ) = @{ $conf->{ $endpoint } };
        my $type   = length $name <= 3 ? uc( $name ) : ucfirst( $name ); # API対策…いけてない
        my $module = $self->load_module( $type => $module_name );
        unless ( $module->can('build_psgi_endpoint') ) {
            Carp::croak( "$module must have build_psgi_endpoint." );
        }
        my $builder = $module->new( sys => $self );
        $arg ||= {};
        $arg->{ endpoint } = $endpoint;
        mount( $endpoint => $builder->build_psgi_endpoint( $arg ) );
    }
}

sub load_module {
    my ( $self, $type, $module ) = @_;

    if ( @_ == 2 ) {
        $module = $type;
        $module = '+' . $module if $module !~ /^\+/;
    }

    if ( $module !~ s/^\+// ) {
        $module = __PACKAGE__ . '::' . $type . '::' . $module;
    }

    eval {
        ( my $path = $module . '.pm' ) =~ s{::}{/}g;
        require $path;
        $path->import();
    };
    if ( $@ ) {
        Carp::croak $@;
    }

    return $module;
}

sub load_plugins {
    my ( $self, $plugins ) = @_;
    return unless $plugins and ref($plugins) eq 'ARRAY';

    for my $plugin_and_args ( @{ $plugins } ) {
        my ( $plugin, $args ) = @{ $plugin_and_args };
        if ( $plugin !~ s/^\+// ) {
            $plugin = __PACKAGE__ . '::Plugin::' . $plugin;
        }
        eval { ( my $path = $plugin . '.pm' ) =~ s{::}{/}g; require $path };
        if ( $@ ) {
            Carp::carp $@;
            next;
        }
        $plugin->setup( $self, @$args );
    }
}

sub register_hook {
    my ( $self, $hook_name, $subref, $args ) = @_;
    push @{ $self->{ hooks }->{ $hook_name } }, [$subref, $args];
}

sub call_hook {
    my ( $self, $hook_name, @args ) = @_;
    for ( @{ $self->{ hooks }->{ $hook_name } || [] } ) {
        my ($subref, $args) = @$_;
        $subref->( $self, @args, @$args );
    }
}

sub register_calling_tag {
    my ( $self, $tag, $subref, $args ) = @_;
    if ( defined $tag ) {
        push @{ $self->{ tag_trigger }->{ $tag } }, [$subref, $args];
    }
    else {
        push @{ $self->{ tag_trigger_no_tag } }, [$subref, $args];
    }
}

sub tag_trigger {
    my ( $self, $tags, $socket, $message_ref ) = @_;

    unless ( scalar( @$tags ) ) {
        for ( @{ $self->{ tag_trigger_no_tag } || [] } ) {
            my ($subref, $args) = @$_;
            $subref->( $self, $socket, undef, $message_ref, $tags, @$args );
        }
    }

    for ( @$tags ) {
        next unless exists $self->{ tag_trigger }->{ $_ };
        for ( @{ $self->{ tag_trigger }->{ $_ } } ) {
            my ($subref, $args) = @{ $_ };
            $subref->( $self, $socket, $_, $message_ref, $tags, @$args );
        }
    }
}

#
# PocketIO まわり
#

sub run {
    my ( $self ) = @_;
    $self->call_hook( 'run', undef );
    return $self->app->dispatch();
}

sub server_info {
    my ( $self, $socket ) = @_;
    my $config = $self->config;
    my $server_info = $self->{server_info} ||= do {
        if ( exists $config->{ server_info } ) {
            $self->_server_info( $config->{ server_info } );
        }
        else {
            $SERVER_INFO;
        }
    };
    $socket->emit( 'server info', $server_info );
}

sub _server_info {
    my ( $self, $info ) = @_;
    {
        name          => $info->{ name },
        version       => $info->{ version },
        introduction  => $info->{ introduction },
        default_tag   => $info->{ default_tag },
        auth_endpoint => +{
            map {
                $_ => $info->{ auth_endpoint }->{$_}->[2] || ''
            } keys %{ $info->{ auth_endpoint } }
        },
    };
}

#
# CONNECTION
#

sub add_tag_socket {
    my ( $self, $socket, $new_joined_tags, $opt ) = @_;
    my $socket_id = ref $socket ? $socket->id : $socket;

    my %joined_tag = map { $_ => 1 } @{ $self->tags_reverse->{ $socket_id } ||= [] };

    # タグ毎にPocketIO::Poolを作成して自分の接続を追加、過去ログを送る
    $opt ||= {};
    my $tags       = $self->tags;
    my $on_added   = $opt->{ on_added };
    my $on_removed = $opt->{ on_removed };

    for my $tag ( @{ $new_joined_tags } ) {
        $tags->{ $tag } ||= PocketIO::Pool->new();
        # there is no proper api in PocketIO::Pool class, so manually set.
        $tags->{ $tag }->{connections}->{ $socket_id } = $socket->{conn};
        $on_added->( $socket, $tag ) if $on_added;
        delete $joined_tag{ $tag };
    }

    # 無くなったタグに紐づくコネクションを消していく
    for my $tag ( keys %joined_tag ) {
        $on_removed->( $socket, $tag ) if $on_removed;
        delete $tags->{ $tag }->{connections}->{ $socket_id };
    }

    # SID => tagテーブル更新
    $self->tags_reverse->{ $socket_id } = [ @{ $new_joined_tags } ];
}

sub remove_tag_socket {
    my ( $self, $socket, $joined_tags, $opt ) = @_;
    my $socket_id = ref $socket ? $socket->id : $socket;

    delete $self->users->{$socket_id};

    $joined_tags ||= delete $self->tags_reverse->{$socket_id};

    #タグ毎にできたPool等からも削除
    $opt ||= {};
    my $tags       = $self->tags;
    my $on_removed = $opt->{ on_removed };

    foreach my $tag ( @$joined_tags ) {
        $on_removed->( $socket, $tag ) if $on_removed;
        delete $tags->{ $tag }->{connections}->{ $socket_id };
    }
}

sub send_post_to_tag_joined {
    my ( $self, $post, $tags ) = @_;
    my $event = $self->post_to_event( $post );
    $self->send_event_to_tag_joined( $event, $tags, 'no_dup' );
}

sub post_to_event {
    my ( $self, $post ) = @_;
    return PocketIO::Message->new(
        type => 'event',
        data => { name => 'user message', args => [ $post ] }
    );
}

sub send_event_to_tag_joined {
    my ( $self, $event, $target_tags, $no_dup ) = @_;
    my $tags = $self->tags;
    my %sent; # if $no_dup, we shall send the event to users once.

    $target_tags = [ $target_tags ] unless ref $target_tags;

    for my $tag ( @{ $target_tags } ) {
        next unless exists $tags->{ $tag };
        DEBUG && print STDERR sprintf("Send event to tag %s\n", $tag);
        my $conns = $tags->{ $tag }->{ connections };
        for my $socket_id ( keys %{ $conns } ) {
            next if $no_dup && exists $sent{ $socket_id };
            next unless $conns->{ $socket_id }->is_connected;
            $conns->{ $socket_id }->socket->send( $event );
            $sent{ $socket_id }++;
        }
    }
}

1;
__END__

