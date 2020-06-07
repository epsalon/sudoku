use strict;
use IPC::Open2;

my $SOLVER=shift || "docker run --rm -i msoos/cryptominisat";

my $literal_count = 0;
my @CNF;

sub add_literals {
	my $c = $literal_count;
	$literal_count += shift;
	return $c + 1;
}

sub add_clause {
  my @c = (@_);
  push @CNF, \@c;
}

sub solve {
  local (*rd, *wr);
  my $pid = open2(\*rd, \*wr, $SOLVER);
  print wr "p cnf $literal_count ", scalar @CNF, "\n";
  for my $c (@CNF) {
    print wr join(' ', @$c), " 0\n";
  }
  close wr;
  waitpid($pid, 0);
  my @out;
  while (<rd>) {
    next unless /^v/;
    chomp;
    my @l = split(' ', $_);
    shift @l;
    push @out, @l;
  }
  pop @out;
  close rd;
  return @out;
}

sub solve_all {
  my @save = (@CNF);
  my @out = ();
  for my $y (0..8) {
    for my $x (0..8) {
      for my $v (0..8) {
      	my $lit = lit($x,$y,$v);
      	add_clause($lit);
      	my $res = solve();
      	push @out, ($res ? $lit : -$lit);
      	print STDERR $v+1 if $res;
      	@CNF = @save;
      }
      print "\t";
    }
    print "\n";
  }
  return @out;
}

my $board = add_literals(9*9*9);

sub lit {
  my $x = shift;
  my $y = shift;
  my $v = shift || 0;
  return $board + $y * 81 + $x * 9 + $v;
}

sub draw_board {
  my %sol = map { abs($_) => ($_ > 0 ? 1 : 0) } @_;

  for my $y (0..8) {
    for my $x (0..8) {
      for my $v (0..8) {
        print $v+1 if $sol{lit($x,$y,$v)};
      }
      print "\t";
    }
    print "\n";
  }
  print "\n";
}

sub another_sol {
  my @sol = @_;
  my @save = (@CNF);
  add_clause(map {$board<=abs($_) && abs($_)<$board+9*9*9 ? - $_ : ()} @sol);
  my @out=solve();
  draw_board(@sol);
  draw_board(@out);
  @CNF=@save;
  return @out;
}

# Param list of board coords in lit form (v = 0)
sub sudoku_excl {
  for my $v (0..8) {
    # Every value must be present
  	add_clause(map {$_ + $v} @_);
  	# Values can't appear twice
  	for my $i (0..$#_ - 1) {
  	  for my $j ($i+1 .. $#_) {
  	    add_clause(-$_[$i]-$v, -$_[$j]-$v);
  	  }
  	}
  }
}

sub shape_order {
  my $lo = shift;
  my $hi = shift;
  my $asc = add_literals($#_);  # One less than shape size
  # Ascending/Descending rule
  for my $i (0..$#_ - 1) {
    # ASC[i] && BOARD[i] = v -> BOARD[i+1] = v+1 .. 8
    # -ASC[i] || -BOARD[i]=v || BOARD[i+1] = v+1 .. || BOARD[i+1] = 8
    # ASC[i] || -BOARD[i]=v || BOARD[i+1] = 0 .. || BOARD[i+1] = v-1
    for my $v (0..8) {
      add_clause(-($asc + $i), -lit($_[$i], 0, $v),
      			 map {lit($_[$i+1], 0, $_)} ($v+1..8));
      add_clause(($asc + $i), -lit($_[$i], 0, $v),
      			 map {lit($_[$i+1], 0, $_)} (0..$v-1));
    }
  }
  # Maintain direction
  for my $i (0..$#_ - 2) {
    # -ASC[i] || ASC[i+1] || BOARD[i+1] == hi    
    # ASC[i] || -ASC[i+1] || BOARD[i+1] == lo
    add_clause(-($asc + $i), $asc + $i + 1, lit($_[$i+1], 0, $hi));
    add_clause($asc + $i, -($asc + $i + 1), lit($_[$i+1], 0, $lo));
  }
  # lo/hi force direction
  for my $i (0..$#_ - 1) {
    # -BOARD[i] == lo || ASC[i]
    # -BOARD[i] == hi || -ASC[i]
    add_clause(-lit($_[$i], 0, $lo), $asc + $i);
    add_clause(-lit($_[$i], 0, $hi), -($asc + $i));
  }
}

# Sudoku rules

# Cells well-defined
for my $x (0..8) {
  for my $y (0..8) {
  	# Every cell must have at least one value
  	add_clause(map {lit($x, $y, $_)} (0..8));
  	# Every cell must have at most one value
  	for my $v1 (0..7) {
  	  for my $v2 ($v1+1..8) {
  	    add_clause(-lit($x, $y, $v1), -lit($x, $y, $v2));
  	  }
  	}
  }
}

# Rows
for my $y (0..8) {
  sudoku_excl(map {lit($_, $y)} (0..8));
}

# Columns
for my $x (0..8) {
  sudoku_excl(map {lit($x, $_)} (0..8));
}

# Boxes
my @BOX_START = (0,3,6,27,30,33,54,57,60);
my @BOX_DELTA = (0,1,2,9,10,11,18,19,20);
for my $b (@BOX_START) {
  sudoku_excl(map {$board + 9*($b + $_)} @BOX_DELTA);
}


# Knight's

#for my $i (0..7) {
#  for my $j (0..6) {
#    for my $v (0..8) {
#      add_clause(-lit($i,$j,$v), -lit($i+1,$j+2,$v));
#      add_clause(-lit($j,$i,$v), -lit($j+2,$i+1,$v));
#      add_clause(-lit(8-$i,$j,$v), -lit(8-($i+1),$j+2,$v));
#      add_clause(-lit(8-$j,$i,$v), -lit(8-($j+2),$i+1,$v));
#    }
#  }
#}

my @SHAPE1 = (9, 0, 1, 2, 3, 4, 5, 6, 7, 16, 17, 26, 35, 44, 53,
			  62, 71, 70, 79, 78, 77, 76, 75, 74, 73, 64, 63, 54,
			  45, 36, 27, 28, 19, 20, 21, 22, 23, 33, 42, 51, 59, 58,
			  57, 47, 39, 40);

shape_order(0,8,@SHAPE1);

my @SHAPE2 = (18, 10, 11, 12, 13, 14, 15, 24, 25, 34, 43, 52, 61,
              60, 69, 68, 67, 66, 65, 56, 55, 46, 37, 38, 29, 30,
              31, 32, 41, 50, 49, 48);
              
shape_order(1,7,@SHAPE2);

### Givens

add_clause(lit(0,1,0));
add_clause(lit(8,0,1));
add_clause(lit(8,8,7));

### SOLVE

my @sol=solve();
unless (@sol) {
  print STDERR "UNSATISFIABLE\n";
  exit;
}

if (another_sol(@sol)) {
  print STDERR "Not unique!\n";
  @sol = solve_all();
  print STDERR "\n\n";
}

draw_board(@sol);

## PRINT OUTPUT
#print "p cnf $literal_count ", scalar @CNF, "\n";
#for my $c (@CNF) {
#  print join(' ', @$c), " 0\n";
#}
