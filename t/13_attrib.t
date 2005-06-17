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
my $label = 'by attribute';
my $te = HTML::TableExtract->new( attribs => { border => 1 } );
ok($te->parse_file($file), "$label (parse_file)");
my @tablestates = $te->table_states;
cmp_ok(@tablestates, '==', 3, "$label (extract count)");
good_data($_, "$label (data)") foreach @tablestates;
