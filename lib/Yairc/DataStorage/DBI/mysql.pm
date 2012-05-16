package Yairc::DataStorage::DBI::mysql;

use strict;
use warnings;
use base 'Yairc::DataStorage::DBI';

our $VERSION = '0.01';

sub init {
    my ( $self ) = @_;
    my $dbh = $self->dbh;
    # 本体から持ってきた
    # TODO: ステートメントハンドル保持しなくてもいいんじゃない？
    $self->{ user_insert_or_update } = $dbh->prepare(q/
        INSERT INTO `user` (
            `user_key`,`nickname`,`profile_image_url`,
            `sns_data_cache`,`created_at`,`updated_at`
        ) VALUES ( ?, ?, ?, ?, now(), now() )
        ON DUPLICATE KEY UPDATE `sns_data_cache`=values(`sns_data_cache`),
        `nickname`=values(`nickname`),
        `profile_image_url`=values(`profile_image_url`),
        `updated_at`=now();
    /); # / .. for poor editor syntax hilight

    $self->{ user_select_by_userkey } = $dbh->prepare(
        'SELECT * FROM `user` WHERE `user_key`=? '
    );
    $self->{ user_key_select_by_token } = $dbh->prepare(
        'SELECT * FROM `session` WHERE `token`=? '
    );
    $self->{ insert_post } = $dbh->prepare(
        'INSERT INTO `post` (
            `user_key`, `nickname`, `profile_image_url`, `text`, `tags`, `created_at_ms`)
            VALUES (?, ?, ?, ?, ?, ?) '
    );
    $self->{ get_last_posts_by_tag } = $dbh->prepare(
        'SELECT * FROM `post` WHERE `tags` like ? AND `created_at_ms` > ?
                ORDER BY `created_at_ms` DESC LIMIT ? ');
    $self->{ get_session_by_token } = $dbh->prepare(
        'SELECT * FROM `session` WHERE `token` = ? AND `expire_at` > now() ');

}

sub add_user {
    my ( $self, $user ) = @_;
    my $ret = $self->dbh->do(q{
        INSERT INTO `user` (
            `user_key`,`nickname`,`profile_image_url`,
            `sns_data_cache`,`created_at`,`updated_at`
        ) VALUES ( ?, ?, ?, ?, now(), now() )
    }, {}, @{$user}{qw/user_key nickname profile_image_url sns_data_cache/} );

    my $ret_session = $self->add_session($user->{user_key},$user->{token});

    return ($ret && $ret_session) ? $user : undef;
}

sub get_user_by_userkey {
    my ( $self, $user ) = @_;
    my $userkey = ref $user ? $user->{ user_key } : $user;
    my $sth = $self->{ user_select_by_userkey };
    $sth->execute( $userkey );
    return $sth->fetchrow_hashref;
}

sub get_user_by_token {
    my ( $self, $user ) = @_;
    my $token = ref $user ? $user->{ token } : $user;
    my $sth = $self->{ user_key_select_by_token };
    $sth->execute( $token );
    my $row = $sth->fetchrow_hashref;
    my $_user = $self->get_user_by_userkey($row->{user_key});
    $_user->{ token } = $token;
    return $_user;
}

sub replace_user {
    my ( $self, $user ) = @_;
    my $sth = $self->dbh->prepare(q{
        UPDATE `user` SET
        `nickname` = ?, `profile_image_url` = ?,
        `sns_data_cache` = ?, `updated_at` = now()
        WHERE `user_key` = ?
    });
    return $sth->execute(@{$user}{qw/nickname profile_image_url sns_data_cache user_key/});
}

sub add_or_replace_user {
    my ( $self, $user, $extra ) = @_;
    my $sth = $self->{ user_insert_or_update };
    $sth->execute( @{$user}{qw/user_key nickname profile_image_url sns_data_cache/} );
    my $_user = $self->get_user_by_userkey( $user->{ user_key } );
    $self->add_session( $user->{user_key}, $user->{token}, $extra );
    $_user->{token} = $user->{token};
    return $_user;
}

sub remove_user {
    my ( $self, $user ) = @_;
    my $userkey = $user->{ user_key };
    $self->dbh->do(q{DELETE FROM `session` WHERE user_key = ? }, {}, $userkey);
    return $self->dbh->do(q{DELETE FROM `user` WHERE user_key = ? }, {}, $userkey);
}

sub count_user {
    return $_[0]->dbh->selectrow_array('SELECT count(*) FROM `user`');
}

sub add_session {
    my ( $self, $user, $token, $extra ) = @_;
    my $userkey = ref $user ? $user->{ user_key } : $user;
    $extra ||= {};
    my $exp = $extra->{ token_expiration_sec } ||= 604800; # 7 days
    return $self->dbh->do(sprintf(q{
        INSERT INTO `session` (
            `user_key`,`token`,`expire_at`
        ) VALUES ( ?, ?, ADDDATE( now(), INTERVAL %d SECOND ) )
    }, $exp), {}, ($userkey, $token) );
}

sub get_session_by_token {
    my ( $self, $token ) = @_;
    my $sth = $self->{ get_session_by_token };
    $sth->execute($token);
    return $sth->fetchrow_hashref;
}

sub clear_expire_token {
    my ( $self ) = @_;
    return $self->dbh->do(q{DELETE FROM `session` WHERE expire_at < now() }, {});
}

sub revoke_token {
    my ( $self, $user ) = @_;
    my $token = ref $user ? $user->{ token } : $user;
    return $self->dbh->do(q{DELETE FROM `session` WHERE `token` = ?}, {}, $token);
}

sub revoke_user_tokens {
    my ( $self, $user ) = @_;
    my $userkey = ref $user ? $user->{ user_key } : $user;
    return $self->dbh->do(q{DELETE FROM `session` WHERE `user_key` = ?}, {}, $user);
}


# post

sub add_post {
    my ( $self, $post, $user ) = @_;
    # | TAG1 TAG2 TAG3 |
    my @tags = @{ $post->{ tags } };
    my $tags = $post->{ tags } ? ' '. join( ' ', @tags ) . ' ' : '';
    $post = $user ? {
        text => $post->{ text },
        nickname => $user->{ nickname },
        user_key => $user->{ user_key },
        profile_image_url => $user->{ profile_image_url },
        created_at_ms     => $self->_get_now_micro_sec(),
        tags              => $tags,
    } : { %$post, created_at_ms => $self->_get_now_micro_sec() };

    $self->{ insert_post }->execute(
                    @{$post}{ qw/user_key nickname profile_image_url text tags created_at_ms/ } );
    $post->{ id } = $self->dbh->last_insert_id(undef, undef, 'post', 'id');
    $post->{ tags } = [ @tags ]; # restore
    return $post;
}

sub remove_post {
    my ( $self, $post ) = @_;
    my $id = $post->{ id };
    return $self->dbh->do(q{DELETE FROM `post` WHERE id = ? }, {}, $id);
}

sub replace_post {
    my ( $self, $post ) = @_;
    my $id   = $post->{ id };
    my $tags = $post->{ tags } ? ' '. join( ' ', @{ $post->{ tags } } ) . ' ' : '';
    my $ret  = $self->dbh->do(qq{
        UPDATE `post` SET `user_key` = ?, `nickname` = ?, `profile_image_url` = ?,
                          `text` = ?, `created_at_ms` = ?, `tags` = ? WHERE `id` = ?
    }, {}, @{$post}{ qw/user_key nickname profile_image_url text created_at_ms/ }, $tags, $id );

    return $ret ? $post : undef;
}

sub get_last_posts_by_tag {
    my ( $self, $tag, $lastusec, $num ) = @_;
    $tag = uc($tag);

    my $sth = $self->{ get_last_posts_by_tag };
    $sth->execute( '% ' . $tag . ' %', $lastusec || 0, $num || 100 );

    my @posts;
    while ( my $post = $sth->fetchrow_hashref ) {
        $post->{ tags } =~ s{^ | $}{}g;
        $post->{ tags } = [ split / /, $post->{ tags } ];
        push @posts, $post;
    }
 
    return \@posts;
}

sub get_post_by_id {
    my ( $self, $id ) = @_;
    return $self->dbh->selectrow_hashref( 'SELECT * FROM `post` WHERE `id` = ?', {}, $id );
}

sub search_post {
    my ( $self, $params, $attr ) = @_;
    # 後でラッパー使う
    my $maker  = SQL::Maker->new( driver => 'mysql' );
    my $limit  = $attr->{ limit };

    unless ( $limit and $limit =~ /^\d+$/ ) {
        $attr->{ limit } = 1000;
    }
    elsif  ( $limit > 10000 ) {
        $attr->{ limit } = 10000;
    } # 暫定

    $attr->{ order_by } ||= 'created_at_ms DESC';

    my $where;
    my $where_tag;
    if ( exists $params->{ tag } ) {
        $where_tag = _sql_maker_cond();
        my $tags = $params->{ tag };
        $tags  = ref $tags ? $tags : [ $tags ];
        $where_tag->add('tags', [ map { { 'like' => '% ' . uc($_) . ' %' } } @$tags ]);
    }

    my $where_time;
    if ( exists $params->{ created_at_ms } ) {
        $where_time = _sql_maker_cond();
        my $times = $params->{ created_at_ms };
        if ( ref $times eq 'ARRAY' ) {
            my $where = [ '-and' ];
            push @{ $where }, { '>=', => $times->[0] } if $times->[0];
            push @{ $where }, { '<=', => $times->[1] } if $times->[1];
            $where_time->add( 'created_at_ms', $where );
        }
        elsif ( ref $times eq 'HASH' ) {
            $where_time->add( 'created_at_ms', $times );
        }
    }

    my $where_id;
    if ( exists $params->{ id } ) {
        $where_id = _sql_maker_cond();
        my $ids = ref $params->{ id } ? $params->{ id } : [ $params->{ id } ];
        if ( ref $ids eq 'ARRAY' ) {
            $where_id->add( 'id', $ids );
        }
        else {
            my ( $op ) = keys %$ids;
            $where_id->add( 'id', { $op => $ids->{ $op } });
        }
    }

    for ( $where_tag , $where_time, $where_id ) {
        if ( !$where and $_ ) {
            $where = $_;
            next;
        }
        next unless $_;
        $where = $where & $_;
    }

    my ( $sql, @binds ) = $maker->select( 'post', ['*'], $where, $attr );

#print STDERR $sql,"\n";
#print STDERR Data::Dumper::Dumper(\@binds);
    my $sth = $self->dbh->prepare( $sql );
    $sth->execute( @binds );

    my @posts;

    while ( my $post = $sth->fetchrow_hashref ) {
        $post->{ tags } =~ s{^ | $}{}g;
        $post->{ tags } = [ split / /, $post->{ tags } ];
        push @posts, $post;
    }

    return \@posts;
}

sub count_post {
    return $_[0]->dbh->selectrow_array('SELECT count(*) FROM `post`');
}


sub _sql_maker_cond {
    SQL::Maker::Condition->new( name_sep => '.', quote_char => '`' );
}

1;
__END__

