package Yairc;

use strict;
use warnings;
use utf8;
use Carp   ();
use Encode ();
use Data::Dumper ();

our $VERSION = '0.01';

use constant DEBUG => $ENV{ YAIRC_DEBUG };

our $SERVER_INFO =  {
    'version' => $VERSION,
    'name'    => 'Yairc(kari)',
    'introduction'   => 'Hello Hachioji.pm',
    'login_endpoint' => {},
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
        require Yairc::Core;
        Yairc::Core->new( sys => $_[0] );
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
    my @tags = map { uc($_) } $str =~ /(?:^| |　)#([a-zA-Z0-9]{1,32})(?= |$)/mg;
    return @tags > 10 ? @tags[0..9] : @tags;
}

sub login {
    my ( $self, $name ) = @_;
    $_[0]->{ login }->{ $name } ||= do {
        my $module = substr( $name, 0, 1 ) eq '+'
                        ? $name : ref( $self ) . '::Login::' . ucfirst( $name );
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
    # Plack::Builder->import; # why it does not export 'mount'?
    for my $endpoint ( keys %{ $conf } ) {
        my ( $name, $arg, undef ) = @{ $conf->{ $endpoint } };
        my $module = $self->load_module( 'API' => $name );
        unless ( $module->can('build_psgi_endpoint') ) {
            Carp::croak( "$module must have build_psgi_endpoint." );
        }
        my $builder = $module->new( sys => $self );
        Plack::Builder::mount $endpoint => $builder->build_psgi_endpoint( $arg );
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
    $socket->emit( 'server info', $_[0]->config->{ server_info } || $SERVER_INFO );
}


1;
__END__

