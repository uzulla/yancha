use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME          => 'Yairc',
    AUTHOR        => 'uzulla',
    VERSION_FROM  => 'lib/Yairc.pm',
### XXX NOW FAILURE TO USING ABSTRACT_FROM
#    ABSTRACT_FROM => 'lib/Yairc.pm',
    PL_FILES      => {},
    PREREQ_PM     => {
        'Test::More'  => 0,
        'version'     => 0,
        'JSON'        => 0,
        'DBI'         => 0,
        'Encode'      => 0,
        'Time::HiRes' => 0,
        'PocketIO'    => 0,
        'Plack'       => 0,
        'Config::Pit' => 0,
        'FindBin'     => 0,
    },
    dist  => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean => { FILES    => 'Yairc-*' },
);

