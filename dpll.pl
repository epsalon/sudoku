use strict;

my @cnf;

my @font = map {my $x=$_; $x=~s/\./ /go;$x} qw/
..┐ ╶─┐ ╶─┐ ╷.╷ ┌─╴ ┌─╴ ╶─┐ ┌─┐ ┌─┐
..│ ┌─┘ ╶─┤ └─┤ └─┐ ├─┐ .─┤ ├─┤ └─┤
..╵ └─╴ ╶─┘ ..╵ ╶─┘ └─┘ ..╵ └─┘ ╶─┘/;

open (CNF, "cnf") or die;

scalar(<CNF>); # Ignore hdr

while (<CNF>) 
{
  chomp;
  my @line = split();
  pop @line;
  @line = sort {abs($a) <=> abs($b)} @line;
  push @cnf, \@line;
}

close(CNF);

my %all_lits = map {map {$_ => 1} @$_} @cnf;

sub assert_vars {
  my $lits = shift; #sorted by abs
  my $clause = shift; # sorted by abs
  my @lits = @$lits;
  push @lits, 'inf';
  my $al = 0;
  my @out;
  for my $cl (@$clause) {
    while (abs($al) < abs($cl)) {
      $al = shift(@lits);
    }
    if (abs($cl) == abs($al)) {
      if ($cl == $al) {
        return ();
      }
    } else {
      push @out, $cl;
    }
  }
  return \@out;  
}

sub pure_literals {
  my %lits;
  for my $cl (@cnf) {
    for my $l (@$cl) {
	  if ($lits{abs($l)} && $lits{abs($l)} != $l) {
	    $lits{abs($l)} = 'x';
	  } else {
	    $lits{abs($l)} = $l;
	  }
    }
  }
  return grep { $_ ne 'x' } values(%lits);
}

sub lit {
  my $x = shift;
  my $y = shift;
  my $v = shift || 0;
  return 1 + $y * 81 + $x * 9 + $v;
}

sub draw_board {
  my %sol = map { $_ => 1} @_;
  my %solved = map {$_ > 0?(int(($_-1)/9) => ($_-1) % 9 + 1):()} @_;

  for my $y (0..8) {
    for my $sr (0..2) {
      for my $x (0..8) {
        if (my $s = $solved{$x+$y*9}) {
          print $font[$s + $sr*9 - 1],"\t";
          next;
        }
        for my $vv (0..2) {
          my $v = $sr * 3 + $vv;
          print ($sol{-lit($x,$y,$v)}?'.':$v+1);
        }
        print "\t";
      }
      print "\n";
    }
    print "\n";
  }
  print "\n";
}

my %assertions;

my @undo;

sub assert{
  my @lits = @_;
  @lits = sort {abs($a) <=> abs($b)} @lits;
  for my $l (@lits) {
    $assertions{$l} = $l;
  }
  @cnf = map {assert_vars(\@lits, $_)} @cnf;
}

sub assume {
  my $lit = shift;
  my @c = @cnf;
  my %a = %assertions;
  push @undo, [\@c, \%a, $lit];
  assert($lit);
}

sub pop_state {
  return undef unless @undo;
  my $u = pop @undo;
  my ($c, $a, $l) = @$u;
  @cnf = @$c;
  %assertions = %$a;
  return $l;
}

sub propagate {
  if (grep {@$_ == 0} @cnf) {
    return 0;
  }
  my @unit_literals = map {@$_ == 1? @$_ : ()} @cnf;
  if (@unit_literals) {
    #print "UNIT LITERALS: ",(join(' ', @unit_literals)), "\n";
    assert(@unit_literals);
  }
  #my @pure_literals = pure_literals();
  #if (@pure_literals) {
  #  print "PURE LITERALS: ",(join(' ', @pure_literals)), "\n";
  #  assert(@pure_literals);
  #}
  return propagate() if (@unit_literals);
  return 1;
}

while (@cnf) {
  print "looping\n";
  while (!propagate()) {
    if (@undo) {
      print "Contradiction -- unwinding.\n";
      assert(-pop_state());
    } else {
      print "UNSATISFIABLE!\n";
      exit;
    }
  }
  # Try short chains
  for my $l (keys %all_lits) {
    next if ($l < 0);
    unless ($assertions{$l}) {
      assume($l);
      my $p = propagate();
      pop_state();
      unless ($p) {
        print "SHORT CHAIN: ",-$l,"\n";
        assert(-$l);
        draw_board(keys %assertions);
      }
    }
  }
  draw_board(keys %assertions);
  last unless (@cnf);
  print "Which literal to try?\n";
  my $line = <>;
  chomp $line;
  while ($line =~ /pop/) {
    pop_state();
    draw_board(keys %assertions);
    print "Which literal to try?\n";
    my $line = <>;
  }
  next if $line =~ /go/;
  my ($r, $c, $v) = split(' ', $line);
  my $lit = lit($c-1,$r-1,abs($v)-1);
  if ($v < 0) {
    $lit = -$lit;
  }
  assume($lit);
}

