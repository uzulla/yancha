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

my $nicknames    = {}; #共有ニックネームリスト
my $tags         = {}; #参加タグ->コネクションプールリスト
my $tags_reverse = {}; #クライアントコネクション->参加Tag リスト


sub new {
    my ( $class, @args ) = @_;
    my $self = bless { @args }, $class;
    $self->load_plugins( $self->config->{ plugnis } );
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

sub users { $nicknames; }

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

sub load_plugins {
    # not yet implemented
}

sub register_hook {
    my ( $self, $class, $hook_name, $subref ) = @_;
    push @{ $self->{ hooks }->{ $hook_name } }, $subref;
}

#
# PocketIO まわり
#

sub run {
    my ( $self ) = @_;
    return $self->app->dispatch();
}

sub server_info {
    my ( $self, $socket ) = @_;
    $socket->emit( 'server info', $_[0]->config->{ server_info } || $SERVER_INFO );
}


1;
__END__

