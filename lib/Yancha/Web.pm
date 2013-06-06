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
        return res { redirect('/android.html'); };
    }

    $template = 'chat.tx';

    return {
        template => 'chat.tx',
    };
};

path '/android.html' => sub {
    return {
        template => 'android.tx',
    };
};

path '/about(\.html)?' => sub {
    my $req = shift;
    return {
        template => 'about.tx',
    };
};

path '/hints(\.html)?' => sub {
    my $req = shift;
    return {
        template => 'hints.tx',
    };
};

path '/join_users(\.html)?' => sub {
    my $req = shift;
    return {
        template => 'join_users.tx',
    };
};


path qr{^/quot(ation\.html)?$} => sub {
    return {
        template => 'quot.tx',
    };
};

path '/search(\.html)?' => sub {
    my $req = shift;
    return {
        template => 'search.tx',
    };
};

1;
