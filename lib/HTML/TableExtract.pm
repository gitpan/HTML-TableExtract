package HTML::TableExtract;

# This package extracts tables from HTML.  Tables of interest may be
# specified using header information, depth, order in a depth, or some
# combination of the three.  See the POD for more information.
#
# Author Matthew P. Sisk. See the POD for copyright information.

use strict;
use Carp;

use vars qw($VERSION @ISA);

$VERSION = '0.01';

use HTML::Parser;
@ISA = qw(HTML::Parser);

use HTML::Entities;

my %Defaults = (
		headers => undef,
		depth   => undef,
		count   => undef,
		automap => 1,
	       );

sub new {
  my $that = shift;
  my $class = ref($that) || $that;

  my(@pass, %parms, $k, $v);
  while (($k,$v) = splice(@_, 0, 2)) {
    if ($k eq 'headers') {
      ref $v eq 'ARRAY' or croak "Headers must be passed in ref to array\n";
      $parms{$k} = $v;
    }
    elsif ($k =~ /^depth|count|automap|debug/) {
      $parms{$k} = $v;
    }
    else {
      push(@pass, $k, $v);
    }
  }

  my $self = new HTML::Parser @pass;
  bless $self, $class;
  foreach (keys %parms) {
    $self->{$_} = exists $parms{$_} ? $parms{$_} : $Defaults{$_};
  }
  if ($self->{headers}) {
    if ($self->{debug}) {
      print STDERR "TE here, headers: ", join(',', @{$self->{headers}}),"\n";
    }
    $self->{_hpat} = join('|', map("($_)", @{$self->{headers}}))
  }
  $self->{_cdepth} = -1;
  $self->{_ccount} = -1;
  $self->{_tablestack}        = [];
  $self->{_tables}            = {};
  $self->{_tables_sequential} = [];
  $self->{_table_coords}      = {};
  $self;
}

#########

sub start {
  my $self = shift;
  if ($_[0] eq 'table') {
    if ($self->{_in_a_table}) {
      $self->{_ccount} = -1;
    }
    ++$self->{_cdepth};
    ++$self->{_ccount};
    ++$self->{_in_a_table};
    push(@{$self->{_tablestack}}, {
				   grab_rows => 1,
				   in_row    => 0,
				   in_cell   => 0,
				   depth     => $self->{_cdepth},
				   count     => $self->{_ccount},
				   rc        => -1,
				   cc        => -1,
				  });
    $self->_reset_hits($self->_current_table_stats);
  }
  if ($self->{_in_a_table}) {
    if ($_[0] eq 'tr') {
      ++$self->_current_table_stats->{in_row};
      ++$self->_current_table_stats->{rc};
    }
    elsif ($_[0] eq 'td' || $_[0] eq 'th') {
      ++$self->_current_table_stats->{in_cell};
      ++$self->_current_table_stats->{cc};
    }
  }
}

sub end {
  my $self = shift;
  if ($self->{_in_a_table}) {
    my $ts = $self->_current_table_stats;
    if ($_[0] eq 'tr') {
      --$ts->{in_row};
      $ts->{cc} = -1;

      if ($ts->{scanning}) {
	# Lost our row whilst still gathering headers
	print STDERR "Lost headers, resetting scan after row $ts->{rc}\n" if $self->{debug};
	$self->_reset_hits($ts);
      }

    }
    elsif ($_[0] eq 'td' || $_[0] eq 'th') {
      --$ts->{in_cell};
    }
    elsif ($_[0] eq 'table') {
      --$self->{_in_a_table};
      if (@{$self->{_tablestack}}) {
	$self->{_cdepth} = $ts->{depth};
	$self->{_ccount} = $ts->{count};
      }
      else {
	$self->{_cdepth} = -1;
	$self->{_ccount} = $ts->{count};
      }
      # Get rid of this table's statistics, we're done with it.
      pop(@{$self->{_tablestack}});
    }
  }
}

sub text {
  my $self = shift;
  if ($self->{_in_a_table}) {
    my $ts = $self->_current_table_stats;
    if ($ts->{in_row} && $ts->{in_cell}) {

      if ($self->{headers}) {
	# Scan for headers if they have been provided.
	my $h = $ts->{hits};
	
	if (!$ts->{hslurp}) {
	  if ($_[0] =~ /($self->{_hpat})/i) {
	    my $hit = $1;
	    ++$ts->{scanning};
	    delete $ts->{hits_left}{$hit};
	    $h->{$ts->{cc}} = $hit;
	    if (!%{$ts->{hits_left}}) {
	      # Don't scoop until next row
	      $ts->{scanning} = undef;
	      $ts->{head_found} = $ts->{rc} + 1;
	      # Remember hits for figuring out the order
	      $self->{_hits}{$ts->{depth}}{$ts->{count}} = $h;
	    }
	  }
	}

	# Indicate the slurp once we are on the row after all headers
	# were found.
	if (!$ts->{hslurp} && $ts->{head_found} && $ts->{rc} == $ts->{head_found}) {
	  print STDERR "Slurp initiated on row $ts->{rc}\n" if $self->{debug};
	  ++$ts->{hslurp};
	}
      }

      my $grab = 0;
      # If we've found ALL of our headers, indicate it's time to grab
      # as long as we are in an applicable column.
      if ($ts->{hslurp}) {
	if ($self->{headers} && exists $self->_current_hits->{$ts->{cc}}) {
	  ++$grab unless $grab;
	}
      }
      else {
	--$grab if $grab;
      }
      
      # If depth or count were specified, they get a vote on the grab as
      # well.
      if (defined $self->{count}) {
	if ($ts->{count} ne $self->{_ccount}) {
	  --$grab if $grab;
	}
	else {
	  ++$grab unless $grab;
	}
      }
      if (defined $self->{depth}) {
	if ($ts->{depth} ne $self->{_cdepth}) {
	  --$self->{grab} if $self->{grab};
	}
	else {
	  ++$grab unless $grab;
	}
      }

      # Let the degenerate case have a vote as well -- we take every
      # table in the document in these cases.
      if (!$self->{headers} && ! defined $self->{depth} && ! defined $self->{count}) {
	++$grab;
      }

      if ($grab) {
	# The ayes have it.
	my $table;
	if (!$self->{_tables}{$ts->{depth}}{$ts->{count}}) {
	  $table = [];
	  $self->{_tables}{$ts->{depth}}{$ts->{count}} = $table;
	  push(@{$self->{_tables_sequential}}, $table);
	  $self->{_table_coords}{$table} = [$ts->{depth}, $ts->{count}];
	}
	else {
	  $table = $self->_current_table;
	}
	# At long last, we grab some content.
	my $txt = decode_entities($_[0]);
	$table->[$ts->{rc}][$ts->{cc}] .= $txt;
	return $txt;
      }
    }
  }
}

####################

sub depths {
  # Return all depths where valid tables were located.
  my $self = shift;
  return () unless ref $self->{_tables};
  sort { $a <=> $b } %{$self->{_tables}};
}

sub counts {
  # Given a depth, return the counts of all valid tables found therein.
  my($self, $depth) = @_;
  defined $depth or croak "Depth required\n";
  sort { $a <=> $b } %{$self->{_tables}{$depth}};
}

sub table {
  # Return the table for a particular depth and count
  my($self, $depth, $count) = @_;
  defined $depth or croak "Depth required\n";
  defined $count or croak "Count required\n";
  if (! $self->{_tables}{$depth} || ! $self->{_tables}{$depth}{$count}) {
    return undef;
  }
  $self->{_tables}{$depth}{$count};
}

sub rows {
  # Return the rows for a table.  First table found if no table specified.
  my($self, $table) = @_;
  if (!$table) {
    $table = $self->first_table_found;
  }
  return () unless ref $table;
  if ($self->{automap} && $self->_map_makes_a_difference) {
    my @rows;
    foreach (@$table) {
      push(@rows, [@{$_}[$self->column_map]]);
    }
    $table = \@rows;
  }
  @{$table};
}

sub _map_makes_a_difference {
  my $self = shift;
  my $diff = 0;
  my @order  = $self->column_map;
  my @sorder = sort { $a <=> $b } @order;
  foreach (0 .. $#order) {
    if ($order[$_] != $sorder[$_]) {
      ++$diff;
      last;
    }
  }
  $diff;
}

sub first_table_found {
  my $self = shift;
  $self->{_tables_sequential}[0];
}
  
sub tables {
  # Return all valid tables found, in the order that they were seen.
  my $self = shift;
  @{$self->{_tables_sequential}};
}

sub table_coords {
  # Return the depth and count of a table
  my($self, $table) = @_;
  ref $table or croak "Table reference required\n";
  return () unless ref $self->{_table_coords}{$table};
  @{$self->{_table_coords}{$table}};
}

sub column_map {
  # Return the column numbers of a particular table in the same order
  # as the provided headers.
  my($self, $table) = @_;
  if (! defined $table) {
    $table = $self->first_table_found;
  }
  my($depth, $count) = $self->table_coords($table);
  if ($self->{headers}) {
    my %order;
    foreach (keys %{$self->{_hits}{$depth}{$count}}) {
      $order{$self->{_hits}{$depth}{$count}{$_}} = $_;
    }
    return @order{@{$self->{headers}}};
  }
  else {
    return 0 .. $#{$self->{_tables}{$depth}{$count}[0]};
  }
}

sub _current_table {
  my $self = shift;
  $self->{_tables_sequential}[$#{$self->{_tables_sequential}}];
}

sub _current_table_stats {
  my $self = shift;
  $self->{_tablestack}[$#{$self->{_tablestack}}];
}

sub _current_hits {
  my $self = shift;
  $self->{_hits}{$self->{_cdepth}}{$self->{_ccount}};
}

sub _reset_hits {
  my($self, $table_stats) = @_;
  return unless $self->{headers};
  ref $table_stats or croak "Table stats as ref required\n";
  $table_stats->{hits} = {};
  foreach (@{$self->{headers}}) {
    ++$table_stats->{hits_left}{$_};
  }
}
__END__

=head1 NAME

HTML::TableExtract - Perl extension for extracting the text contained in tables within an HTML document.

=head1 SYNOPSIS

 # Using column header information.  Assume an HTML document
 # with a table which has "Date", "Price", and "Cost"
 # somewhere in a  row. The columns beneath those headings are
 # what you are interested in.

 use HTML::TableExtract;
 $te = new HTML::TableExtract( headers => [qw(Date Price Cost)] );
 $te->parse($html_string);

 # rows() assumes the first table found in the document if no
 # table is provided. Since automap is enabled by default,
 # each row is returned in the same column order as we
 # specified for our headers. Otherwise, we would have to rely
 # on $te->column_order to figure out the column in which each
 # header was found.

 foreach $row ($te->rows) {
    print join(',', @$_),"\n";
 }

 # Using depth and count information.  In this example, our
 # tables must be within two other tables, plus be the third
 # table at that depth within those tables.  In other words,
 # wherever there exists a table within a table that contains
 # a cell with at least three tables in sequence, we grab
 # the third table. Depth and count both begin with 0.

 $te = new HTML::TableExtract( depth => 2, count => 2 );
 $te->parse($html_string);
 foreach ($te->tables) {
    print "Table found at ", join(',', $te->table_coords($_)), ":\n";
    foreach ($te->rows($_)) {
       print "   ", join(',', @$_), "\n";
    }
 }

=head1 DESCRIPTION

HTML::TableExtract is a subclass of HTML::Parser that serves to extract
the textual information from tables of interest contained within an
HTML document. The textual information for each table is stored in
an array of arrays that represent the rows and cells of that table.

There are three ways to specify which tables you would like to extract
from a document: I<Headers>, I<Depth>, and I<Count>.

I<Headers>, the most flexible and adaptive of the techniques, involves
specifying text in an array that you expect to appear above the data
in the tables of interest.  Once all headers have been located in
a row of that table, all further cells beneath the columns that matched
your headers are extracted. All other columns are ignored: think of it
as vertical slices through a table.  In addition, HTML::TableExtract
automatically rearranges each row in the same order as the headers
you provided. If you would like to disable this, set I<automap> to
0 during object creation, and instead rely on the column_map() method
to find out the order in which the headers were found.

I<Depth> and I<Count> are more specific ways to specify tables that have
more dependencies on the HTML document layout.  I<Depth> represents
how deeply a table resides in other tables.  The depth of a top-level table
in the document is 0.  A table within a top-level table has a depth of 1,
and so on.  I<Count> represents which table at a particular depth you are
interested in, starting with 0.

Each of the I<Headers>, I<Depth>, and I<Count> specifications are cumulative
in their effect on the overall extraction.  For instance, if you
specify only a I<Depth>, then you get all tables at that depth (note that
these could very well reside in separate higher-level tables throughout
the document). If you specify only a I<Count>, then the tables at that
I<Count> from all depths are returned.  If you only specify I<Headers>,
then you get all tables in the document matching those header characteristics.
If you have specified multiple characteristics, then each characteristic
has veto power over whether a particular table is extracted.

If no I<Headers>, I<Depth>, or I<Count> are specified, then all
tables are extracted from the document.

The main point of this module was to provide a flexible method of
extracting tabular information from HTML documents without relying
to heavily on the document layout.  For that reason, I suggest using
I<Headers> whenever possible -- that way, you are anchoring your extraction
on what the document is trying to communicate rather than some
feature of the HTML comprising the document (other than the fact that
the data is contained in a table).

HTML::TableExtract is a subclass of HTML::Parser, and as such inherits
all of its basic methods. In particular, C<start()>, C<end()>, and C<text()>
are utilized.  Feel free to override them, but if you do not eventually
invoke them with some content, results are not guaranteed.

Text that is gathered from the tables is decoded with HTML::Entities first.
Also note that text can be chunked, so you are not guaranteed to be dealing
with all of the text in a particular cell when C<text()> is invoked.

=head1 METHODS

=over

=item new()

Return a new HTML::TableExtract object.  Valid attributes are:

=over

=item headers

Passed as an array reference, headers specify strings of interest at the
top of columns within targeted tables.  These header strings will
eventually be passed through a non-anchored, case-insensitive regular
expression, so regexp special characters are allowed. The table row
containing the headers is B<not> returned. Columns that are not beneath
one of the provided headers will be ignored. Columns will, by default,
be rearranged into the same order as the headers you provide (see the
I<automap> parameter for more information).

=item depth

Specify how embedded in other tables your tables of interest should
be.  Top-level tables in the HTML document have a depth of 0, tables
within top-level tables have a depth of 1, and so on.

=item count

Specify which table within each depth you are interested in, beginning
with 0.

=item automap

Automatically applies the ordering reported by column_map() to the
rows returned by rows(). This only makes a difference if you have
specified I<Headers> and they turn out to be in a different order
in the table than what you specified. Automap will rearrange the
column orders. To get the original order, you will need to take
another slice of each row using column_map(). I<automap> is enabled
by default, but only has an affect if you have specified I<headers>.

=item debug

Prints some debugging information to STDOUT.

=back

=item rows()

=item rows($table)

Return all rows within a particular table that matched the search.
Each row is a reference to an array containing the text of each cell.
If no table is provided, then the first table that matched is assumed.

=item column_map()

=item column_map($table)

For a particular table that matched the search, returns the order in
which the provided headers were found.  This information can be used
as a slice on each table row to reaarange the data in the order you
initially specified.  If no table is provided, the first table that
matched is assumed.

=item tables()

Returns all tables in the document that matched the search, in the
order in which they were seen.  This is depth-first order.

=item first_table_found()

Returns the first table that matched the search from the document.

=item table_coords($table)

Returns the depth and count for a particular table.

=item depths()

Returns all depths that contained matched tables in the document.

=item counts($depth)

For a particular depth, returns all counts that contained matched tables.

=item table($depth, $count)

Returns the matched table at a particular depth and count.

=back

=head1 REQUIRES

HTML::Parser(3), HTML::Entities(3)

=head1 AUTHOR

Matthew P. Sisk, E<lt>F<sisk@mojotoad.com>E<gt>

=head1 COPYRIGHT

Copyright (c) 2000 Matthew P. Sisk.
All rights reserved. All wrongs revenged. This program is free
software; you can redistribute it and/or modify it under the
same terms as Perl itself.

=head1 SEE ALSO

HTML::Parser(3), perl(1).

=cut
