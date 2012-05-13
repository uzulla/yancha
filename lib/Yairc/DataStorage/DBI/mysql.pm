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
            `sns_data_cache`,`token`,`created_at`,`updated_at`
        ) VALUES ( ?, ?, ?, ?, ?, now(), now() )
        ON DUPLICATE KEY UPDATE `sns_data_cache`=values(`sns_data_cache`),
        `nickname`=values(`nickname`),
        `profile_image_url`=values(`profile_image_url`),
        `updated_at`=now(), `token`=values(`token`);
    /); # / .. for poor editor syntax hilight

    $self->{ user_select_by_userkey } = $dbh->prepare(
        'SELECT * FROM `user` WHERE `user_key`=? '
    );
    $self->{ user_select_by_token } = $dbh->prepare(
        'SELECT * FROM `user` WHERE `token`=? '
    );
    $self->{ insert_post } = $dbh->prepare(
        'INSERT INTO `post` (
            `user_key`, `nickname`, `profile_image_url`, `text`, `tags`, `created_at_ms`)
            VALUES (?, ?, ?, ?, ?, ?) '
    );
    $self->{ get_last_posts_by_tag } = $dbh->prepare(
        'SELECT * FROM `post` WHERE `tags` like ? AND `created_at_ms` > ?
                ORDER BY `created_at_ms` DESC LIMIT ? ');
}

sub add_user {
    my ( $self, $user ) = @_;
    my $ret = $self->dbh->do(q{
        INSERT INTO `user` (
            `user_key`,`nickname`,`profile_image_url`,
            `sns_data_cache`,`token`,`created_at`,`updated_at`
        ) VALUES ( ?, ?, ?, ?, ?, now(), now() )
    }, {}, @{$user}{qw/user_key nickname profile_image_url sns_data_cache token/} );

    return $ret ? $user : undef;
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
    my $sth = $self->{ user_select_by_token };
    $sth->execute( $token );
    return $sth->fetchrow_hashref;
}

sub replace_user {
    my ( $self, $user ) = @_;
    my $sth = $self->dbh->prepare(q{
        UPDATE `user` SET
        `nickname` = ?, `profile_image_url` = ?,
        `sns_data_cache` = ?, `token` = ?, `updated_at` = now()
        WHERE `user_key` = ?
    });
    return $sth->execute(@{$user}{qw/nickname profile_image_url sns_data_cache token user_key/});
}

sub add_or_replace_user {
    my ( $self, $user ) = @_;
    my $sth = $self->{ user_insert_or_update };
    $sth->execute( @{$user}{qw/user_key nickname profile_image_url sns_data_cache token/} );
    $self->get_user_by_userkey( $user->{ user_key } );
}

sub remove_user {
    my ( $self, $user ) = @_;
    my $userkey = $user->{ user_key };
    return $self->dbh->do(q{DELETE FROM `user` WHERE user_key = ? }, {}, $userkey);
}

sub count_user {
    return $_[0]->dbh->selectrow_array('SELECT count(*) FROM `user`');
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
    my ( $self, $where, $attr ) = @_;
    # 便宜的にtagのみで絞り込みかつ手動だが、今後複雑になるならSQL::Makerなど検討
    # っていうか使いたい。結局かかる手間たいしてかわらないし
    # →さすがに限界なので次回から使う方向で修正
    my @binds;
    my $sql    = 'SELECT * FROM `post`';
    my $limit  = $attr->{ limit };
    my $offset = $attr->{ offset };

    unless ( $limit and $limit =~ /^\d+$/ ) {
        $limit = 1000;
    }

    if ( $limit > 10000 ) { $limit = 10000; } # 暫定

    if ( exists $where->{ tag } ) {
        my $tags = $where->{ tag };
        $tags  = ref $tags ? $tags : [ $tags ];
        $sql  .= ' WHERE ( ' . join( ' OR ', (q/UPPER(`tags`) LIKE UPPER(?)/) x scalar(@$tags) ) . ' )';
        push @binds, map { '% ' . $_ . ' %' } @$tags;
    }

    if ( exists $where->{ created_at_ms } ) {
        if ( $sql =~ /WHERE/ ) {
            $sql .= ' AND ';
        }
        else {
            $sql .= ' WHERE ';
        }
        my $times = $where->{ created_at_ms };
        my @sqls;
        push @sqls, '`created_at_ms` >= ?' if $times->[0];
        push @sqls, '`created_at_ms` <  ?' if $times->[1];
        $sql  .= ' ( ' . join( ' AND ', @sqls ) . ' ) ';
        push @binds, map { $_ . '00000' } grep { defined } @$times;
    }

    if ( exists $where->{ id } ) {
        my $ids = ref $where->{ id } ? $where->{ id } : [ $where->{ id } ];
        if ( $sql =~ /WHERE/ ) {
            $sql .= ' AND ';
        }
        else {
            $sql .= ' WHERE ';
        }
        if ( ref $ids eq 'ARRAY' ) {
            $sql .= '( `id` IN(' . join( ',', ('?') x scalar(@$ids) ) . ' ) )';
        }
        else { # ex. { '>=', 132 }
            my ( $op ) = keys %$ids;
            $sql .= "`id` $op ?";
            $ids = [ $ids->{ $op } ];
        }
        push @binds, @$ids;
    }

    if ( my $order_by = $attr->{ order_by } ) {
        $sql .= " ORDER BY $order_by ";
    }
    else {
        $sql .= ' ORDER BY `created_at_ms` DESC ';
    }

    $sql .= " LIMIT $limit ";
    $sql .= defined $offset && $offset =~ /^\d+$/ ? " OFFSET $offset" : '';
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


1;
__END__

