package Yancha::Web;

my $config;

BEGIN {
    use Yancha::Config::Simple;
    $config = Yancha::Config::Simple->load_file( $ENV{ YANCHA_CONFIG_FILE } || undef );
}

use strict;
use warnings;
use utf8;
use Yancha::Util;
use Nephia plugins => [
    'Dispatch',
    'View::Xslate' => $config->{'view'},
];
    
our $VERSION = 0.01;
    
app {
    get '/' => sub {
        my $req = req;
    
        my $template;
        if (Yancha::Util->is_smartphone( $req->env->{HTTP_USER_AGENT} || '' )) {
            return redirect('/android.html');
        }
    
        return [200, [], render('chat.tx')];
    };
    
    get '/android.html' => sub {
        return [200, [], render('android.tx')];
    };
    
    get qr{^/about(\.html)?} => sub {
        return [200, [], render('about.tx')];
    };
    
    get qr{/hints(\.html)?} => sub {
        return [200, [], render('hints.tx')];
    };


    get qr{/tagcloud(\.html)?} => sub {
        return [200, [], render('tagcloud.tx')];
    };

    
    get qr{^/join_users(\.html)?} => sub {
        return [200, [], render('join_users.tx')];
    };
    
    
    get qr{^/quot(ation\.html)?$} => sub {
        return [200, [], render('quot.tx')];
    };
    
    post qr{^/quot(ation\.html)?$} => sub {
        return [200, [], render('quot.tx')];
    };

    get qr{^/search(\.html)?$} => sub {
        return [200, [], render('search.tx')];
    };
};
    
1;
