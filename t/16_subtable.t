#!/usr/bin/perl

use strict;
use lib './lib';
use Test::More tests => 332;

use FindBin;
use lib $FindBin::RealBin;
use testload;

my $file = "$Dat_Dir/basic.html";

use HTML::TableExtract;

# By count
my $label = 'by subtable scoop';
my $te = HTML::TableExtract->new(
  depth     => 0,
  count     => 2,
  subtables => 1,
);
ok($te->parse_file($file), "$label (parse_file)");
my @tablestates = $te->tables;
cmp_ok(@tablestates, '==', 3, "$label (extract count)");
good_data($_, "$label (data)") foreach @tablestates;
