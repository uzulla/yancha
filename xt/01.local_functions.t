#!perl

use strict;
use warnings;
use utf8;

use Test::More;

eval "use Test::LocalFunctions";
plan skip_all => "Test::LocalFunctions required for testing variables" if $@;

all_local_functions_ok();
