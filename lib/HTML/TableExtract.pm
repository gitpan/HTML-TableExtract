package HTML::TableExtract;

# This package extracts tables from HTML.  Tables of interest may be
# specified using header information, depth, order in a depth, or some
# combination of the three.  See the POD for more information.
#
# Author Matthew P. Sisk. See the POD for copyright information.

use strict;
use Carp;

use vars qw($VERSION @ISA);

$VERSION = '0.05';

use HTML::Parser;
@ISA = qw(HTML::Parser);

use HTML::Entities;

my %Defaults = (
		headers => undef,
		depth   => undef,
		count   => undef,
		decode  => 1,
		automap => 1,
		debug   => 0,
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
    elsif ($k =~ /^depth|count|automap||decode|debug/) {
      $parms{$k} = $v;
    }
    else {
      push(@pass, $k, $v);
    }
  }

  my $self = new HTML::Parser @pass;
  bless $self, $class;
  foreach (keys %parms, keys %Defaults) {
    $self->{$_} = exists $parms{$_} ? $parms{$_} : $Defaults{$_};
  }
  if ($self->{headers}) {
    if ($self->{debug}) {
      print STDERR "TE here, headers: ", join(',', @{$self->{headers}}),"\n";
    }
    my $hstring = '(' . join('|', map("($_)", @{$self->{headers}})) . ')';
    print STDERR "HPAT: /$hstring/\n" if $self->{debug} >= 2;
    $self->{_hpat} = $hstring;
  }
  $self->{_cdepth} = -1;
  $self->{_ccount} = -1;
  $self->{_tablestack}        = [];
  $self->{_tables}            = {};
  $self->{_tables_sequential} = [];
  $self->{_table_mapback}     = {};
  $self->{_counts}            = [];
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
    ++$self->{_in_a_table};
    $self->_increment_count($self->{_cdepth});
    $self->{_ccount} = $self->{_counts}[$self->{_cdepth}];

    my($depth, $count) = ($self->{_cdepth}, $self->{_ccount});
    print STDERR "TABLE: cdepth $depth, ccount $count, it: $self->{_in_a_table}\n" if $self->{debug} >= 2;

    my $ts = {
	      in_row    => 0,
	      in_cell   => 0,
	      depth     => $depth,
	      count     => $count,
	      rc        => -1,
	      cc        => -1,
	      grab      => 1,
	      content   => [],
	      htxt      => '',
	      order     => [],
	      imap      => {},
	     };
    push(@{$self->{_tablestack}}, $ts);
    $self->_reset_hits($ts);

    # Now we decide if we want to ignore this table

    # If depth or count were specified, they get a vote on the grab.
    if (defined $self->{count}) {
      $ts->{grab} = 0 if $ts->{count} != $self->{count};
    }
    if (defined $self->{depth}) {
      $ts->{grab} = 0 if $ts->{depth} != $self->{depth};
    }
  }

  # Rows and cells
  if ($self->{_in_a_table}) {
    my $ts = $self->_current_table_state;
    if ($_[0] eq 'tr') {
      ++$ts->{in_row};
      ++$ts->{rc};
      if ($ts->{grab}) {
	# Add a new row to content if applicable
	push(@{$ts->{content}}, [])
	  unless $self->{headers} && !$ts->{hslurp};
      }
    }
    elsif ($_[0] eq 'td' || $_[0] eq 'th') {
      ++$ts->{in_cell};
      ++$ts->{cc};
      if (!$ts->{in_row}) {
	# We try to be understanding about mangled HTML.
	++$ts->{in_row};
	++$ts->{rc};
	print STDERR "Mangled HTML in table ($ts->{depth},$ts->{count}), inferring <TR> as row $ts->{rc}\n" if $self->{debug};
      }
      # Initialize cell, if appropriate
      if ($ts->{grab}) {
	my $init;
	if ($self->{headers}) {
	  if ($ts->{hslurp} && $ts->{hits}{$ts->{cc}}) {
	    ++$init;
	  }
	}
	else {
	  ++$init;
	}
	if ($init) {
	  my $r = $ts->{content}[$ts->{rc}];
	  $r->[$#$r + 1] = '';
	}	  
      }
    }
  }
}

sub end {
  my $self = shift;
  if ($self->{_in_a_table}) {
    my $ts = $self->_current_table_state;
    if ($_[0] eq 'td' || $_[0] eq 'th') {
      # Scan for headers if they have been provided and this
      # table has not been vetoed by depth/count specifications,
      # we're not already slurping, and we have not found all headers.
      if ($self->{headers} && $ts->{grab} &&
	  !$ts->{hslurp} && !$ts->{head_found}) {
	my $h = $ts->{hits};
	if ($ts->{htxt} =~ /$self->{_hpat}/imo) {
	  my $hit = $1;
	  print STDERR "HIT on '$hit'\n" if $self->{debug} >= 4;
	  ++$ts->{scanning};
	  # Git rid of the pattern that matched so we
	  # can tell when we're through with all patterns.
	  foreach (keys %{$ts->{hits_left}}) {
	    if ($hit =~ /$_/im) {
	      delete $ts->{hits_left}{$_};
	      $hit = $_;
	      last;
	    }
	  }
	  $h->{$ts->{cc}} = $hit;
	  push(@{$ts->{order}}, $ts->{cc});
	  $ts->{imap}{$ts->{cc}} = $#{$ts->{order}};
	  if (!%{$ts->{hits_left}}) {
	    # We have found all headers, but we won't
	    # start slurping until this row has ended
	    ++$ts->{head_found};
	    $ts->{scanning} = undef;
	    # Since we don't return the header row, we
	    # pretend we never saw it. (and rc will inc
	    # once we start the next row).
	    $ts->{rc} = -1;
	  }
	}
	# Reset buffer for next cell
	$ts->{htxt} = '';
      }
      # Done with this cell
      --$ts->{in_cell};
    }
    elsif ($_[0] eq 'tr') {
      --$ts->{in_row};
      $ts->{cc} = -1;
      if ($self->{headers}) {
	if ($ts->{scanning}) {
	  # Lost our row whilst still gathering headers
	  print STDERR "Incomplete header match in row $ts->{rc}, resetting scan\n" if $self->{debug};
	  $self->_reset_hits($ts);
	}
	# Initiate slurp if we are ending the header row
	if ($ts->{head_found} && !$ts->{hslurp}) {
	  ++$ts->{hslurp};
	  print STDERR "Slurp initiated on row ",$ts->{rc}+2,"\n"
	    if $self->{debug};
	}
      }
    }
    elsif ($_[0] eq 'table') {
      if ($ts->{grab}) {
	# Add our newly captured table, if we actually bothered with it.
	unless ($self->{headers} && !$ts->{hslurp}) {
	  $self->_add_table_state($ts);
	  print STDERR "Captured table ($ts->{depth},$ts->{count})\n"
	    if $self->{debug} >= 2;
	}
      }
      # Restore last table state
      pop(@{$self->{_tablestack}});
      --$self->{_in_a_table};
      my $lts = $self->_current_table_state;
      if (ref $lts) {
	$self->{_cdepth} = $lts->{depth};
	$self->{_ccount} = $self->{_counts}[$lts->{depth}];
      }
      else {
	$self->{_cdepth} = -1;
	$self->{_ccount} = $ts->{count};
      }
      print STDERR "LEAVE: cdepth: $self->{_cdepth}, ccount: $self->{_ccount}, it: $self->{_in_a_table}\n" if $self->{debug} >= 2;
    }
  }
}

sub text {
  my $self = shift;
  if ($self->{_in_a_table}) {
    my $ts = $self->_current_table_state;
    if ($ts->{in_row} && $ts->{in_cell}) {

      # Just add this text to header scan if using headers and
      # they haven't all been found.
      if ($self->{headers}) {
	if (!$ts->{head_found}) {
	  $ts->{htxt} .= $self->{decode} ? decode_entities($_[0]) : $_[0];
	  return;
	}
	elsif (!$ts->{hslurp}) {
	  # In this case we've found our headers but need to
	  # finish the header row since there are columns
	  # we don't want.
	  print STDERR "Skipping column $ts->{cc}\n" if $self->{debug} > 1;
	  return;
	}
      }

      # Initialize grab status
      my $grab = $ts->{grab};

      if ($self->{headers} && $ts->{hslurp}) {
	# Indicate it's time to grab only if we are in an
	# applicable column.	  
	$grab = 0 unless exists $ts->{hits}{$ts->{cc}};
      }

      if ($grab) {
	# The ayes have it, we grab some content.
	my $r = $ts->{content}[$ts->{rc}];
	my $txt = $self->{decode} ? decode_entities($_[0]) : $_[0];
	$r->[$#$r] .= $txt;
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
  shift->table_state(@_)->{content};
}

sub table_state {
  # Return the table content for a particular depth and count
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
  my @tc;
  if (!$table) {
    $table = $self->first_table_found;
  }
  return () unless ref $table;
  if ($self->{automap} && $self->_map_makes_a_difference) {
    my @cm = $self->column_map;
    foreach (@$table) {
      my $r = [@{$_}[@cm]];
      # since there could have been non-existent <TD> we need
      # to double check initilization to appease -w
      foreach (0 .. $#$r) {
	$r->[$_] = '' unless defined $r->[$_];
      }
      push(@tc, $r);
    }
  }
  else {
    @tc = @$table;
  }
  @tc;
}

sub _add_table_state {
  my($self, $ts) = @_;
  croak "Table state ref required\n" unless ref $ts;
  # Preliminary init sweep to appease -w
  # These undefs would exist for empty <TD> since text()
  # never got called. Don't want to blindly do this
  # in a start('td') because headers might have vetoed.
  foreach my $r (@{$ts->{content}}) {
    foreach (0 .. $#$r) {
      $r->[$_] = '' unless defined $r->[$_];
    }
  }
  $self->{_tables}{$ts->{depth}}{$ts->{count}} = $ts;
  $self->{_table_mapback}{$ts->{content}} = $ts;
  push(@{$self->{_tables_sequential}}, $ts);
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

sub _increment_count {
  my($self, $depth) = @_;
  defined $depth or croak "Depth required\n";
  if ($#{$self->{_counts}} < $depth) {
    $self->{_counts}[$depth] = 0;
  }
  else {
    ++$self->{_counts}[$depth];
  }
}

sub first_table_found {
  shift->first_table_state_found(@_)->{content};
}

sub first_table_state_found {
  my $self = shift;
  $self->{_tables_sequential}[0];
}

sub tables {
  # Return content of all valid tables found, in the order that
  # they were seen.
  map($_->{content}, shift->table_states(@_));
}
  
sub table_states {
  # Return all valid table records  found, in the order that
  # they were seen.
  my $self = shift;
  @{$self->{_tables_sequential}};
}

sub table_coords {
  # Return the depth and count of a table
  my($self, $table) = @_;
  ref $table or croak "Table reference required\n";
  my $ts = $self->{_table_mapback}{$table};
  return () unless ref $ts;
  ($ts->{depth}, $ts->{count});
}

sub column_map {
  # Return the column numbers of a particular table in the same order
  # as the provided headers.
  my($self, $table) = @_;
  if (! defined $table) {
    $table = $self->first_table_found;
  }
  my $ts = $self->{_table_mapback}{$table};
  return () unless ref $ts;
  if ($self->{headers}) {
    # First we order the original column counts by taking
    # a hash slice based on the original header order.
    # The resulting original column numbers are mapped to the
    # actual content indicies since we could have a sparse slice.
    my %order;
    foreach (keys %{$ts->{hits}}) {
      $order{$ts->{hits}{$_}} = $_;
    }
    return map($ts->{imap}{$_}, @order{@{$self->{headers}}});
  }
  else {
    return 0 .. $#{$ts->{content}[0]};
  }
}

sub _current_table_state {
  my $self = shift;
  $self->{_tablestack}[$#{$self->{_tablestack}}];
}

sub _reset_hits {
  my($self, $table_state) = @_;
  return unless $self->{headers};
  ref $table_state or croak "Table stats as ref required\n";
  $table_state->{hits} = {};
  foreach (@{$self->{headers}}) {
    ++$table_state->{hits_left}{$_};
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
 # least three non-nested tables, we grab the third table.
 # Depth and count both begin with 0.

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
to find out the order in which the headers were found. HTML is stripped
from the entire textual content of a cell before header matches are
attempted.

I<Depth> and I<Count> are more specific ways to specify tables that have
more dependencies on the HTML document layout.  I<Depth> represents
how deeply a table resides in other tables.  The depth of a top-level table
in the document is 0.  A table within a top-level table has a depth of 1,
and so on.  I<Count> represents which table at a particular depth you are
interested in, starting with 0. It might help to picture this as an
HTML page with a z-axis. Each time you enter a nested table, you go
down to another layer -- the count represents the ordering of tables
on that layer.

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

Text that is gathered from the tables is decoded with HTML::Entities by
default.

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

=item decode

Automatically decode retrieved text with HTML::Entities::decode_entities().
Enabled by default.

=item debug

Prints some debugging information to STDOUT, more for higher values.

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
