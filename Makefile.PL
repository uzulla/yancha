use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME          => 'Yancha',
    AUTHOR        => 'uzulla',
    VERSION_FROM  => 'lib/Yancha.pm',
### XXX NOW FAILURE TO USING ABSTRACT_FROM
#    ABSTRACT_FROM => 'lib/Yancha.pm',
    PL_FILES      => {},
    PREREQ_PM     => {
        'Test::More'  => 0,
        'version'     => 0,
        'JSON'        => 0,
        'DBI'         => 0,
        'Encode'      => 0,
        'Nephia'      => 0.10,
        'Nephia::View::Xslate' => 0.02,
        'Time::HiRes' => 0,
        'PocketIO'    => 0.13,
        'Plack'       => 0,
        'FindBin'     => 0,
        'Digest::SHA' => 0,
        'SQL::Maker'  => '1.05',
        'LWP::Protocol::https' => 0,
        'Plack::Session' => 0,
        'Authen::Htpasswd' => 0,
        'AnyEvent::PocketIO::Client' => 0,
        'AnyEvent::Twitter' => 0,
	'XML::FeedPP' => 0,
    },
    dist  => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean => { FILES    => 'Yancha-*' },
);

