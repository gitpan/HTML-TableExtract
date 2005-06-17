#!/usr/bin/perl

my $test_count;
BEGIN { $test_count = 118 }

use strict;
use lib './lib';
use Test::More tests => $test_count;

use FindBin;
use lib $FindBin::RealBin;
use testload;

my $file = "$Dat_Dir/basic.html";

use HTML::TableExtract qw(tree);

my($tb_present, $et_present);
BEGIN {
  eval "use HTML::TreeBuilder";
  $tb_present = !$@;
  eval "use HTML::ElementTable";
  $et_present = !$@;
}

SKIP: {
  skip "HTML::TreeBuilder not installed",  $test_count unless $tb_present;
  skip "HTML::ElementTable not installed", $test_count unless $et_present;
  my $label = 'element table';
  my $te = HTML::TableExtract->new(
    depth     => 0,
    count     => 2,
  );
  isa_ok($te, 'HTML::TreeBuilder', "$label - HTML::TableExtract");
  ok($te->parse_file($file), "$label (parse_file)");
  my @tablestates = $te->table_states;
  cmp_ok(@tablestates, '==', 1, "$label (extract count)");
  good_data($_, "$label (data)") foreach @tablestates;
  my $tree = $te->tree;
  ok($tree, 'treetop');
  isa_ok($tree, 'HTML::Element');
  foreach my $ts ($te->tables) {
    my $tree = $ts->tree;
    ok($tree, 'tabletop');
    isa_ok($tree, 'HTML::ElementTable');
  }
  local *FH;
  open(FH, '<', $file) or die "Oops opening $file : $!\n";
  my $hstr = join('', <FH>);
  close(FH);
  $hstr =~ s/\n//gm;
  $te->_attribute_purge;
  my $estr = $te->elementify->as_HTML;
  $estr =~ s/\n//gm;
  cmp_ok($estr, 'eq', $hstr, 'mass html comp');
}
