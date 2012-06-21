package t::Utils::TestDB::SQLite;
use strict;
use warnings;
use DBI;
use File::Temp ();
use Test::More;

sub new {
    my ($class, %opt) = @_;

    my $schema_file = delete $opt{schema} || '';
    $schema_file =~ s/\.sql$/_sqlite.sql/;

    my $db_file = File::Temp::tmpnam;
    my $dsn = [
        "dbi:SQLite:dbname=$db_file", '', '', {sqlite_unicode => 1}
    ];

    my $dbh = DBI->connect(@$dsn);
    open my $fh, '<', $schema_file
                     or plan skip_all => "Can't open schema file $schema_file.";

    for my $lines (split/;\n/, do { local $/; <$fh> }) {
        next if $lines =~ /^\r?\n$/; # empty line
        $dbh->do($lines);
    }

    $opt{schema} = $schema_file;
    $opt{dsn} = $dsn;
    $opt{db_file} = $db_file;
    bless \%opt => $class;
}

sub dsn { @{$_[0]->{dsn}} }

1;
