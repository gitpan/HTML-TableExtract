#!/usr/bin/perl

use strict;
use lib './lib';
use Test::More tests => 110;

use FindBin;
use lib $FindBin::RealBin;
use testload;

my $file = "$Dat_Dir/skew.html";

use HTML::TableExtract;

# By count
my $label = 'by header with span correction';
my $te = HTML::TableExtract->new(
  headers => [ qw(head0 head1 head2 head3) ],
);
ok($te->parse_file($file), "$label (parse_file)");
my @tablestates = $te->table_states;
cmp_ok(@tablestates, '==', 1, "$label (extract count)");
good_skew_data($_, "$label (skew data)")     foreach @tablestates;
good_sticky_data($_, "$label (sticky data)") foreach @tablestates;
