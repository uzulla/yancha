#!/usr/bin/env perl
use strict;
use warnings;
use File::Basename qw/dirname/;
use SQL::Translator;

my $dirname = dirname __FILE__;

my $translator = SQL::Translator->new;
my $sql_for_sqlite = $translator->translate(
    from => 'MySQL',
    to => 'SQLite',
    filename => "$dirname/../db/init.sql",
) or die $translator->error;

# SQL::Translator doesn't output AUTOINCREMENT keyword,
# but we need it to pass t/002_data_storage_mysql.t.
$sql_for_sqlite =~ s/\b(INTEGER PRIMARY KEY)\b/$1 AUTOINCREMENT/g;

open my $out, '>', "$dirname/../db/init_sqlite.sql" or die $!;
print $out $sql_for_sqlite;

__END__

=encoding utf8

=head1 NAME

mysql_to_sqlite.pl - Translates from init.sql to init_sqlite.sql.

=head1 DESCRIPTION

This script is for authors. Please run this script when you change init.sql.

=cut

