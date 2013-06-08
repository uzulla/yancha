package t::Utils::TestDB::MySQL;
use strict;
use warnings;

BEGIN {
    use Test::More;
    plan skip_all => 'Test::mysqld is required to run this test'
      unless eval { require Test::mysqld; 1 };
}

sub new {
    my ($class, %opt) = @_;
    my $schema_file = $opt{ schema } || '';

    my $mysqld = Test::mysqld->new(
        my_cnf => { 'skip-networking' => '' }
    ) or plan skip_all => $Test::mysqld::errstr;

    my $dbh = DBI->connect( $mysqld->dsn() );

    my $res = $dbh->selectall_arrayref('SELECT VERSION();');
    my $mysql_version = $res->[0][0];

    my @mysql_version_list = split(/\./, $mysql_version);

    if($mysql_version_list[0] >= 5 && $mysql_version_list[1] >= 5){
        $schema_file =~ s/\.sql$/_mysql55.sql/;
    }

    open( my $fh, '<', $schema_file ) or plan skip_all => "Can't open schema file $schema_file.";

    for my $lines ( split/;\n/, do { <$fh>; local $/; <$fh> } ) {
        next if $lines =~ /^\r?\n$/; # empty line
        $dbh->do( $lines );
    }

    $opt{mysqld} = $mysqld;
    bless \%opt => $class;
}

sub mysqld { $_[0]->{mysqld} }

sub dsn { $_[0]->mysqld->dsn }

1;
