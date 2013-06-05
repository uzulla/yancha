package Yancha::Web;
use strict;
use warnings;
use Nephia;
use Yancha::Util;

our $VERSION = 0.01;

path '/' => sub {
    my ($req, @args) = @_;

    my $template;
    if (Yancha::Util->is_smartphone( $req->env->{HTTP_USER_AGENT} || '' )) {
        $template = 'chat_sp.tx';
    } else {
        $template = 'chat.tx';
    }

    return {
        template => $template,
    };
};

path '/about' => sub {
    my $req = shift;
    return {
        template => 'about.tx',
    };
};

path '/hints' => sub {
    my $req = shift;
    return {
        template => 'hints.tx',
    };
};

path '/join_users' => sub {
    my $req = shift;
    return {
        template => 'join_users.tx',
    };
};


# 下位互換のためにquotation.htmlを残しておく
path qr{^/quot(ation\.html)?$} => sub {
    my $req = shift;

    my $where;
    my $posts = [];
    if ( my $ids = $req->param('id') ) {
        $where->{ id } = [ grep { $_ =~ /^[0-9]+$/ } split /,/, $ids ];
        $posts = config->{app}->data_storage->search_post( $where, {order_by => 'created_at_ms ASC'} );

        for my$p( @$posts ) {
            $p->{profile_image_url} = config->{view}->{function}->{static}('/img/nobody.png') unless $p->{profile_image_url};
        }
    }

    return {
        template => 'quot.tx',
        posts    => $posts,
        post_count => scalar(@$posts),
    };
};

path '/search' => sub {
    my $req = shift;
    return {
        template => 'search.tx',
    };
};

1;
