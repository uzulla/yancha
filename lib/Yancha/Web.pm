package Yancha::Web;
use strict;
use warnings;
use Nephia;
use Yancha::Util;

our $VERSION = 0.01;

path '/' => sub {
    my ($req, @args) = @_;

    my $template;
    if (Yancha::Util->is_smartphone($req->env->{HTTP_USER_AGENT})) {
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

path '/quotation' => sub {
    my $req = shift;
    return {
        template => 'quotation.tx',
    };
};

path '/search' => sub {
    my $req = shift;
    return {
        template => 'search.tx',
    };
};

1;
