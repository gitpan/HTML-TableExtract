#!/usr/bin/perl

use strict;
use lib './lib';
use Test::More tests => 12;

use FindBin;
use lib $FindBin::RealBin;
use testload;

my $file = "$Dat_Dir/basic.html";

use HTML::TableExtract;

# Check header row retention cases

my($label, $te, @rows, $table);

$label = 'header row (basic, default)';
$te = HTML::TableExtract->new();
ok($te->parse_file($file), "$label (parse)");
$table = $te->first_table_found;
@rows = $table->rows;
cmp_ok(@rows, '==', scalar @{$table->{grid}}, "$label (row count)");

$label = 'header row (basic, no keep)';
$te = HTML::TableExtract->new( keep_headers => 0 );
ok($te->parse_file($file), "$label (parse)");
$table = $te->first_table_found;
@rows = $table->rows;
cmp_ok(@rows, '==', scalar @{$table->{grid}}, "$label (row count)");

$label = 'header row (basic, keep)';
$te = HTML::TableExtract->new( keep_headers => 0 );
ok($te->parse_file($file), "$label (parse)");
$table = $te->first_table_found;
@rows = $table->rows;
cmp_ok(@rows, '==', scalar @{$table->{grid}}, "$label (row count)");

$label = 'header row (header, default)';
$te = HTML::TableExtract->new( headers => [qw(Eight Six Four Two Zero)] );
ok($te->parse_file($file), "$label (parse)");
$table = $te->first_table_found;
@rows = $table->rows;
cmp_ok(@rows, '==', scalar @{$table->{grid}} - 1, "$label (row count)");

$label = 'header row (header, nokeep)';
$te = HTML::TableExtract->new( headers => [qw(Eight Six Four Two Zero)],
                               keep_headers => 0,
                             );
ok($te->parse_file($file), "$label (parse)");
$table = $te->first_table_found;
@rows = $table->rows;
cmp_ok(@rows, '==', scalar @{$table->{grid}} - 1, "$label (row count)");

$label = 'header row (header, keep)';
$te = HTML::TableExtract->new( headers => [qw(Eight Six Four Two Zero)],
                               keep_headers => 1,
                             );
ok($te->parse_file($file), "$label (parse)");
$table = $te->first_table_found;
@rows = $table->rows;
cmp_ok(@rows, '==', scalar @{$table->{grid}}, "$label (row count)");
