# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'

######################### We start with some black magic to print on failure.

# Change 1..1 below to 1..last_test_to_print .
# (It may become useful if the test is moved to ./t subdirectory.)

BEGIN { $| = 1; print "1..1\n"; }
END {print "not ok 1\n" unless $loaded;}
use HTML::TableExtract;
$loaded = 1;
print "ok 1\n";

######################### End of black magic.

# Insert your test code below (better if it prints "ok 13"
# (correspondingly "not ok 13") depending on the success of chunk 13
# of the test code):

@headers = (
	    'Header Zero',
	    'Header One',
	    'Header Two',
	    'Header Three',
	    'Header Four',
	    'Header Five',
	    'Header Six',
	    'Header Seven',
	    'Header Eight',
	    'Header Nine',
	   );

$html = join('', <DATA>);

# By count
$pass = 1;
$te = new HTML::TableExtract(
			     count => 1,
			    );
$te->parse($html);
@tablestates = $te->table_states;
$pass = 0 unless @tablestates == 2;
foreach (@tablestates) {
  $pass = 0 unless good_data($_);
}
print $pass ? "ok " : "not ok ";
print "2 (by count)\n";

# By depth
$pass = 1;
$te = new HTML::TableExtract(
			     depth => 1,
			    );
$te->parse($html);
@tablestates = $te->table_states;
$pass = 0 unless @tablestates == 2;
foreach (@tablestates) {
  $pass = 0 unless good_data($_);
}
print $pass ? "ok " : "not ok ";
print "3 (by depth)\n";

# By header
%hcheck = (
	   Zero  => 0,
	   Two   => 2,
	   Four  => 4,
	   Six   => 6,
	   Eight => 8,
	  );
$pass = 1;
$te = new HTML::TableExtract(
			     headers => [qw(Eight Six Four Two Zero)],
			    );
$te->parse($html);
@tablestates = $te->table_states;
$pass = 0 unless @tablestates == 5;
foreach (@tablestates) {
  $pass = 0 unless good_data($_);
}
foreach ($te->tables) {
  my @rows = $te->rows($_);
  foreach my $r (0 .. $#rows) {
    my $rr = $r + 1;
    foreach my $c (0 .. $#{$rows[$r]}) {
#      print "Check $rr,$c : $rows[$r][$c] eq ' ($rr,$hcheck{$te->{headers}[$c]})' ?\n";
      $pass = 0 unless $rows[$r][$c] eq " ($rr,$hcheck{$te->{headers}[$c]})";
    }
  }
}
print $pass ? "ok " : "not ok ";
print "4 (by header)\n";

exit;

sub good_data {
  my $ts = shift;
  ref $ts or die "Oops: Table state array ref required\n";
  my $t = $ts->{content};

  my $skew;
  if ($t->[0][0] =~ /^Header/) {
    $skew = 1;
  }
  else {
    $skew = 0;
  }
  my $row = 0 + $skew;
  my %ctran;
  if (!$skew) {
    # Establish column translations in case we sliced.
    foreach (0 .. $#{$t->[$row]}) {
      my($coord) = $t->[$row][$_] =~ /\d+,(\d+)/;
      return 0 unless defined $coord;
      $ctran{$_} = $coord;
    }
  }
  # See if we got the numbers.
  foreach my $r ($row .. $#$t) {
    foreach my $c (0 .. $#{$t->[$r]}) {
      my $rc = $skew ? $r : $r + 1;
      my $cc = $skew ? $c : $ctran{$c};
#      print "Scan $t->[$r][$c] for ($rc, $cc)\n";
      $t->[$r][$c] =~ /^ \($rc,$cc\)$/ or return 0;
    }
  }
  if ($skew) {
    foreach my $c (0 .. $#{$t->[0]}) {
      my $hs = $headers[$c];
      $t->[0][$c] =~ /^$hs$/ or return 0;
    }
  }
  1;
}

__DATA__
<html>
<head><title>TableExtract Test HTML</title></head>
<body>
<h3>Here lies Table 1:</h3>
<table border=1><tr><td>Header Zero</td><td>Header One</td><td>Header Two</td><td>Header Three</td><td>Header Four</td><td>Header Five</td><td>Header Six</td><td>Header Seven</td><td>Header Eight</td><td>Header Nine</td></tr><tr><td> (1,0)</td><td> (1,1)</td><td> (1,2)</td><td> (1,3)</td><td> (1,4)</td><td> (1,5)</td><td> (1,6)</td><td> (1,7)</td><td> (1,8)</td><td> (1,9)</td></tr><tr><td> (2,0)</td><td> (2,1)</td><td> (2,2)</td><td> (2,3)</td><td> (2,4)</td><td> (2,5)</td><td> (2,6)</td><td> (2,7)</td><td> (2,8)</td><td> (2,9)</td></tr><tr><td> (3,0)</td><td> (3,1)</td><td> (3,2)</td><td> (3,3)</td><td> (3,4)</td><td> (3,5)</td><td> (3,6)</td><td> (3,7)</td><td> (3,8)</td><td> (3,9)</td></tr><tr><td> (4,0)</td><td> (4,1)</td><td> (4,2)</td><td> (4,3)</td><td> (4,4)</td><td> (4,5)</td><td> (4,6)</td><td> (4,7)</td><td> (4,8)</td><td> (4,9)</td></tr><tr><td> (5,0)</td><td> (5,1)</td><td> (5,2)</td><td> (5,3)</td><td> (5,4)</td><td> (5,5)</td><td> (5,6)</td><td> (5,7)</td><td> (5,8)</td><td> (5,9)</td></tr><tr><td> (6,0)</td><td> (6,1)</td><td> (6,2)</td><td> (6,3)</td><td> (6,4)</td><td> (6,5)</td><td> (6,6)</td><td> (6,7)</td><td> (6,8)</td><td> (6,9)</td></tr><tr><td> (7,0)</td><td> (7,1)</td><td> (7,2)</td><td> (7,3)</td><td> (7,4)</td><td> (7,5)</td><td> (7,6)</td><td> (7,7)</td><td> (7,8)</td><td> (7,9)</td></tr><tr><td> (8,0)</td><td> (8,1)</td><td> (8,2)</td><td> (8,3)</td><td> (8,4)</td><td> (8,5)</td><td> (8,6)</td><td> (8,7)</td><td> (8,8)</td><td> (8,9)</td></tr><tr><td> (9,0)</td><td> (9,1)</td><td> (9,2)</td><td> (9,3)</td><td> (9,4)</td><td> (9,5)</td><td> (9,6)</td><td> (9,7)</td><td> (9,8)</td><td> (9,9)</td></tr></table>

<h3>Here lies Table 2:</h3>
<table border=1><tr><td>Header Zero</td><td>Header One</td><td>Header Two</td><td>Header Three</td><td>Header Four</td><td>Header Five</td><td>Header Six</td><td>Header Seven</td><td>Header Eight</td><td>Header Nine</td></tr><tr><td> (1,0)</td><td> (1,1)</td><td> (1,2)</td><td> (1,3)</td><td> (1,4)</td><td> (1,5)</td><td> (1,6)</td><td> (1,7)</td><td> (1,8)</td><td> (1,9)</td></tr><tr><td> (2,0)</td><td> (2,1)</td><td> (2,2)</td><td> (2,3)</td><td> (2,4)</td><td> (2,5)</td><td> (2,6)</td><td> (2,7)</td><td> (2,8)</td><td> (2,9)</td></tr><tr><td> (3,0)</td><td> (3,1)</td><td> (3,2)</td><td> (3,3)</td><td> (3,4)</td><td> (3,5)</td><td> (3,6)</td><td> (3,7)</td><td> (3,8)</td><td> (3,9)</td></tr><tr><td> (4,0)</td><td> (4,1)</td><td> (4,2)</td><td> (4,3)</td><td> (4,4)</td><td> (4,5)</td><td> (4,6)</td><td> (4,7)</td><td> (4,8)</td><td> (4,9)</td></tr><tr><td> (5,0)</td><td> (5,1)</td><td> (5,2)</td><td> (5,3)</td><td> (5,4)</td><td> (5,5)</td><td> (5,6)</td><td> (5,7)</td><td> (5,8)</td><td> (5,9)</td></tr><tr><td> (6,0)</td><td> (6,1)</td><td> (6,2)</td><td> (6,3)</td><td> (6,4)</td><td> (6,5)</td><td> (6,6)</td><td> (6,7)</td><td> (6,8)</td><td> (6,9)</td></tr><tr><td> (7,0)</td><td> (7,1)</td><td> (7,2)</td><td> (7,3)</td><td> (7,4)</td><td> (7,5)</td><td> (7,6)</td><td> (7,7)</td><td> (7,8)</td><td> (7,9)</td></tr><tr><td> (8,0)</td><td> (8,1)</td><td> (8,2)</td><td> (8,3)</td><td> (8,4)</td><td> (8,5)</td><td> (8,6)</td><td> (8,7)</td><td> (8,8)</td><td> (8,9)</td></tr><tr><td> (9,0)</td><td> (9,1)</td><td> (9,2)</td><td> (9,3)</td><td> (9,4)</td><td> (9,5)</td><td> (9,6)</td><td> (9,7)</td><td> (9,8)</td><td> (9,9)</td></tr></table>

<h3>Here lies Table 3 with 4 and 5 inside:</h3>
<table border=1><tr><td>Header Zero</td><td>Header One</td><td>Header Two</td><td>Header Three</td><td>Header Four</td><td>Header Five</td><td>Header Six</td><td>Header Seven</td><td>Header Eight</td><td>Header Nine</td></tr><tr><td> (1,0)</td><td> (1,1)</td><td> (1,2)</td><td> (1,3)</td><td> (1,4)</td><td> (1,5)</td><td> (1,6)</td><td> (1,7)</td><td> (1,8)</td><td> (1,9)</td></tr><tr><td> (2,0)</td><td> (2,1)</td><td> (2,2)</td><td> (2,3)</td><td> (2,4)</td><td> (2,5)</td><td> (2,6)</td><td> (2,7)</td><td> (2,8)</td><td> (2,9)</td></tr><tr><td> (3,0)</td><td> (3,1)</td><td> (3,2)</td><td> (3,3)</td><td> (3,4)</td><td> (3,5)</td><td> (3,6)</td><td> (3,7)</td><td> (3,8)</td><td> (3,9)</td></tr><tr><td> (4,0)</td><td> (4,1)</td><td> (4,2)</td><td> (4,3)</td><td> (4,4)</td><td> (4,5)</td><td> (4,6)</td><td> (4,7)</td><td> (4,8)</td><td> (4,9)</td></tr><tr><td> (5,0)</td><td> (5,1)</td><td> (5,2)</td><td> (5,3)</td><td> (5,4)</td><td> (5,5)<table border=1><tr><td>Header Zero</td><td>Header One</td><td>Header Two</td><td>Header Three</td><td>Header Four</td><td>Header Five</td><td>Header Six</td><td>Header Seven</td><td>Header Eight</td><td>Header Nine</td></tr><tr><td> (1,0)</td><td> (1,1)</td><td> (1,2)</td><td> (1,3)</td><td> (1,4)</td><td> (1,5)</td><td> (1,6)</td><td> (1,7)</td><td> (1,8)</td><td> (1,9)</td></tr><tr><td> (2,0)</td><td> (2,1)</td><td> (2,2)</td><td> (2,3)</td><td> (2,4)</td><td> (2,5)</td><td> (2,6)</td><td> (2,7)</td><td> (2,8)</td><td> (2,9)</td></tr><tr><td> (3,0)</td><td> (3,1)</td><td> (3,2)</td><td> (3,3)</td><td> (3,4)</td><td> (3,5)</td><td> (3,6)</td><td> (3,7)</td><td> (3,8)</td><td> (3,9)</td></tr><tr><td> (4,0)</td><td> (4,1)</td><td> (4,2)</td><td> (4,3)</td><td> (4,4)</td><td> (4,5)</td><td> (4,6)</td><td> (4,7)</td><td> (4,8)</td><td> (4,9)</td></tr><tr><td> (5,0)</td><td> (5,1)</td><td> (5,2)</td><td> (5,3)</td><td> (5,4)</td><td> (5,5)</td><td> (5,6)</td><td> (5,7)</td><td> (5,8)</td><td> (5,9)</td></tr><tr><td> (6,0)</td><td> (6,1)</td><td> (6,2)</td><td> (6,3)</td><td> (6,4)</td><td> (6,5)</td><td> (6,6)</td><td> (6,7)</td><td> (6,8)</td><td> (6,9)</td></tr><tr><td> (7,0)</td><td> (7,1)</td><td> (7,2)</td><td> (7,3)</td><td> (7,4)</td><td> (7,5)</td><td> (7,6)</td><td> (7,7)</td><td> (7,8)</td><td> (7,9)</td></tr><tr><td> (8,0)</td><td> (8,1)</td><td> (8,2)</td><td> (8,3)</td><td> (8,4)</td><td> (8,5)</td><td> (8,6)</td><td> (8,7)</td><td> (8,8)</td><td> (8,9)</td></tr><tr><td> (9,0)</td><td> (9,1)</td><td> (9,2)</td><td> (9,3)</td><td> (9,4)</td><td> (9,5)</td><td> (9,6)</td><td> (9,7)</td><td> (9,8)</td><td> (9,9)</td></tr></table></td><td> (5,6)</td><td> (5,7)</td><td> (5,8)</td><td> (5,9)</td></tr><tr><td> (6,0)</td><td> (6,1)</td><td> (6,2)</td><td> (6,3)</td><td> (6,4)</td><td> (6,5)</td><td> (6,6)</td><td> (6,7)</td><td> (6,8)</td><td> (6,9)</td></tr><tr><td> (7,0)</td><td> (7,1)</td><td> (7,2)</td><td> (7,3)</td><td> (7,4)</td><td> (7,5)</td><td> (7,6)</td><td> (7,7)<table border=1><tr><td>Header Zero</td><td>Header One</td><td>Header Two</td><td>Header Three</td><td>Header Four</td><td>Header Five</td><td>Header Six</td><td>Header Seven</td><td>Header Eight</td><td>Header Nine</td></tr><tr><td> (1,0)</td><td> (1,1)</td><td> (1,2)</td><td> (1,3)</td><td> (1,4)</td><td> (1,5)</td><td> (1,6)</td><td> (1,7)</td><td> (1,8)</td><td> (1,9)</td></tr><tr><td> (2,0)</td><td> (2,1)</td><td> (2,2)</td><td> (2,3)</td><td> (2,4)</td><td> (2,5)</td><td> (2,6)</td><td> (2,7)</td><td> (2,8)</td><td> (2,9)</td></tr><tr><td> (3,0)</td><td> (3,1)</td><td> (3,2)</td><td> (3,3)</td><td> (3,4)</td><td> (3,5)</td><td> (3,6)</td><td> (3,7)</td><td> (3,8)</td><td> (3,9)</td></tr><tr><td> (4,0)</td><td> (4,1)</td><td> (4,2)</td><td> (4,3)</td><td> (4,4)</td><td> (4,5)</td><td> (4,6)</td><td> (4,7)</td><td> (4,8)</td><td> (4,9)</td></tr><tr><td> (5,0)</td><td> (5,1)</td><td> (5,2)</td><td> (5,3)</td><td> (5,4)</td><td> (5,5)</td><td> (5,6)</td><td> (5,7)</td><td> (5,8)</td><td> (5,9)</td></tr><tr><td> (6,0)</td><td> (6,1)</td><td> (6,2)</td><td> (6,3)</td><td> (6,4)</td><td> (6,5)</td><td> (6,6)</td><td> (6,7)</td><td> (6,8)</td><td> (6,9)</td></tr><tr><td> (7,0)</td><td> (7,1)</td><td> (7,2)</td><td> (7,3)</td><td> (7,4)</td><td> (7,5)</td><td> (7,6)</td><td> (7,7)</td><td> (7,8)</td><td> (7,9)</td></tr><tr><td> (8,0)</td><td> (8,1)</td><td> (8,2)</td><td> (8,3)</td><td> (8,4)</td><td> (8,5)</td><td> (8,6)</td><td> (8,7)</td><td> (8,8)</td><td> (8,9)</td></tr><tr><td> (9,0)</td><td> (9,1)</td><td> (9,2)</td><td> (9,3)</td><td> (9,4)</td><td> (9,5)</td><td> (9,6)</td><td> (9,7)</td><td> (9,8)</td><td> (9,9)</td></tr></table></td><td> (7,8)</td><td> (7,9)</td></tr><tr><td> (8,0)</td><td> (8,1)</td><td> (8,2)</td><td> (8,3)</td><td> (8,4)</td><td> (8,5)</td><td> (8,6)</td><td> (8,7)</td><td> (8,8)</td><td> (8,9)</td></tr><tr><td> (9,0)</td><td> (9,1)</td><td> (9,2)</td><td> (9,3)</td><td> (9,4)</td><td> (9,5)</td><td> (9,6)</td><td> (9,7)</td><td> (9,8)</td><td> (9,9)</td></tr></table>

</body>
</html>
