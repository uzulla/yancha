package Yancha::DataStorage::DBI::SQLite;
use strict;
use warnings;
use base 'Yancha::DataStorage::DBI';

our $VERSION = '0.01';

sub init {
    my ( $self ) = @_;
    $self->{sql_maker} = SQL::Maker->new(driver => 'SQLite');
}

sub _add_user {
    my ( $self, $user ) = @_;
    my $now = time;
    my ($sql, @binds) = $self->{sql_maker}->insert('user', [
        (map { $_ => $user->{$_} }
             qw/user_key nickname profile_image_url sns_data_cache/),
        created_at => $now,
        updated_at => $now,
    ]);
    return $self->dbh->do($sql, {}, @binds);
}

sub add_user {
    my ( $self, $user ) = @_;
    my $ret = $self->_add_user($user);
    my $ret_session = $self->add_session($user->{user_key},$user->{token});

    return ($ret && $ret_session) ? $user : undef;
}

sub get_user_by_userkey {
    my ( $self, $user ) = @_;
    my $userkey = ref $user ? $user->{ user_key } : $user;

    my ($sql, @binds) = $self->{sql_maker}->select('user', ['*'], {
        user_key => $userkey
    });

    return $self->dbh->selectrow_hashref($sql, {}, @binds);
}

sub get_user_by_token {
    my ( $self, $user ) = @_;
    my $token = ref $user ? $user->{ token } : $user;

    my ($sql, @binds) = $self->{sql_maker}->select('session', ['*'], {
        token => $token
    });
    my $row = $self->dbh->selectrow_hashref($sql, {}, @binds);

    my $_user = $self->get_user_by_userkey($row->{user_key});
    if($_user){
        $_user->{ token } = $token;
    }
    return $_user;
}

sub replace_user {
    my ( $self, $user ) = @_;

    my $now = time;
    my ($sql, @binds) = $self->{sql_maker}->update('user', [
        (map { $_ => $user->{$_} }
             qw/nickname profile_image_url sns_data_cache/),
        updated_at => $now,
    ], {
        user_key => $user->{user_key},
    });
    return $self->dbh->do($sql, {}, @binds);
}

sub add_or_replace_user {
    my ( $self, $user, $extra ) = @_;
    my $_user = $self->get_user_by_userkey( $user->{ user_key } );

    if ($_user) {
        $self->replace_user($user);
    } else {
        $self->_add_user($user);
    }

    $_user = $self->get_user_by_userkey( $user->{user_key} );
    $self->add_session( $user->{user_key}, $user->{token}, $extra );
    $_user->{token} = $user->{token};
    return $_user;
}

sub remove_user {
    my ( $self, $user ) = @_;
    my $userkey = $user->{ user_key };
    my ($sql, @binds);

    ($sql, @binds) = $self->{sql_maker}->delete('session', {
        user_key => $user->{user_key},
    });
    $self->dbh->do($sql, {}, @binds);

    ($sql, @binds) = $self->{sql_maker}->delete('user', {
        user_key => $user->{user_key},
    });
    return $self->dbh->do($sql, {}, @binds);
}

sub count_user {
    my $self = shift;

    my ($sql, @binds) = $self->{sql_maker}->select('user', [\'count(*)']);
    return $self->dbh->selectrow_array($sql, {}, @binds);
}

sub add_session {
    my ( $self, $user, $token, $extra ) = @_;
    my $userkey = ref $user ? $user->{ user_key } : $user;
    $extra ||= {};
    my $exp = $extra->{ token_expiration_sec } ||= 604800; # 7 days

    my ($sql, @binds) = $self->{sql_maker}->insert('session', [
        user_key => $userkey,
        token => $token,
        expire_at => time + $exp,
    ]);
    return $self->dbh->do($sql, {}, @binds);
}

sub get_session_by_token {
    my ( $self, $token ) = @_;

    my ($sql, @binds) = $self->{sql_maker}->select('session', ['*'], {
        token => $token,
        expire_at => {'>' => time},
    });
    return $self->dbh->selectrow_hashref($sql, {}, @binds);
}

sub clear_expired_session {
    my ( $self ) = @_;
    my ($sql, @binds) = $self->{sql_maker}->delete('session', {
        expire_at => {'<' => time},
    });
    return $self->dbh->do($sql, {}, @binds);
}

sub revoke_token {
    my ( $self, $user ) = @_;
    my $token = ref $user ? $user->{ token } : $user;
    my ($sql, @binds) = $self->{sql_maker}->delete('session', {
        token => $token
    });
    return $self->dbh->do($sql, {}, @binds);
}

sub revoke_user_tokens {
    my ( $self, $user ) = @_;
    my $userkey = ref $user ? $user->{ user_key } : $user;
    my ($sql, @binds) = $self->{sql_maker}->delete('session', {
        user_key => $userkey
    });
    return $self->dbh->do($sql, {}, @binds);
}


# post

sub add_post {
    my ( $self, $post ) = @_;

    if ( $_[2] ) { # back compat
        $post = $self->make_post( { %$post, user => $_[2] } );
    }

    my $tags = $post->{ tags }; # for restoring
    my $tags_string = $self->_tags_to_string( $tags );

    $post->{ tags } = $tags_string;

    my ($sql, @binds) = $self->{sql_maker}->insert('post', [
        (map { $_ => $post->{$_} }
             qw/user_key nickname profile_image_url text tags created_at_ms/),
    ]);
    $self->dbh->do($sql, {}, @binds);

    $post->{ id } = $self->dbh->last_insert_id(undef, undef, 'post', 'id')
                            or die "seems not to support last_insert_id method";
    $post->{ tags } = $tags; # restore

    return $post;
}

sub _tags_to_string {
    my ( $self, $tags ) = @_;
    return '' unless $tags;
    # | TAG1 TAG2 TAG3 |
    return @$tags ? ' '. join( ' ', @$tags ) . ' ' : '';
}

sub remove_post {
    my ( $self, $post ) = @_;
    my $id = $post->{ id };

    my ($sql, @binds) = $self->{sql_maker}->delete('post', {
        id => $id
    });
    return $self->dbh->do($sql, {}, @binds);
}

sub replace_post {
    my ( $self, $post ) = @_;
    my $id   = $post->{ id };
    my $tags = $self->_tags_to_string( $post->{ tags } );

    my ($sql, @binds) = $self->{sql_maker}->update('post', [
        (map { $_ => $post->{$_} }
             qw/user_key nickname profile_image_url text created_at_ms/),
        tags => $tags,
    ], {
        id => $id
    });
    my $ret = $self->dbh->do($sql, {}, @binds);

    return $ret ? $post : undef;
}

sub get_last_posts_by_tag {
    my ( $self, $tag, $lastusec, $num ) = @_;
    $tag = uc($tag);

    my ($sql, @binds) = $self->{sql_maker}->select('post', ['*'], {
        tags => {like => '% ' . $tag . ' %'},
        created_at_ms => {'>' => $lastusec || 0},
    }, {
        order_by => 'created_at_ms DESC',
        limit => $num || 100,
    });
    my $sth = $self->dbh->prepare($sql);
    $sth->execute(@binds);

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
    my ($sql, @binds) = $self->{sql_maker}->select('post', ['*'], {
        id => $id,
    });
    my $post = $self->dbh->selectrow_hashref($sql, {}, @binds);
    $post->{ tags } =~ s{^ | $}{}g;
    $post->{ tags } = [ split / /, $post->{ tags } ];
    return $post;
}

sub search_post {
    my ( $self, $params, $attr ) = @_;
    # 後でラッパー使う
    my $maker  = $self->{sql_maker};
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
        $where_tag = $maker->new_condition;
        my $tags = $params->{ tag };
        $tags  = ref $tags ? $tags : [ $tags ];
        $where_tag->add('tags', [ map { { 'like' => '% ' . uc($_) . ' %' } } @$tags ]);
    }

    my $where_text;
    if ( exists $params->{ text } ) {
        $where_text = $maker->new_condition;
        my $keywords = $params->{ text };
        $keywords = ref $keywords ? $keywords : [ $keywords ];
        $where_text->add( 'text', [ '-and', map { { 'like', => '%' . $_ . '%' } } grep { $_ ne '' } @$keywords ] );
    }

    my $where_time;
    if ( exists $params->{ created_at_ms } ) {
        $where_time = $maker->new_condition;
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
        $where_id = $maker->new_condition;
        my $ids = ref $params->{ id } ? $params->{ id } : [ $params->{ id } ];
        if ( ref $ids eq 'ARRAY' ) {
            $where_id->add( 'id', $ids );
        }
        else {
            my ( $op ) = keys %$ids;
            $where_id->add( 'id', { $op => $ids->{ $op } });
        }
    }

    for ( $where_id, $where_tag, $where_text, $where_time ) {
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
    my ($self) = @_;

    my ($sql, @binds) = $self->{sql_maker}->select('post', [\'count(*)']);
    return $self->dbh->selectrow_array($sql, @binds);
}

sub plusplus {
    my ($self,$id) = @_;

    my ($sql, @binds) = $self->{sql_maker}->update('post', [
        plusplus => \'plusplus + 1'
    ], {
        id => $id
    });
    $self->dbh->do($sql, {}, @binds);
}

1;

__END__
