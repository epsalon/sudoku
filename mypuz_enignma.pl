use strict;
use IPC::Open2;
use Data::Dumper;

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

sub write_cnf {
  my $wr = shift;
  print $wr "p cnf $literal_count ", scalar @CNF, "\n";
  for my $c (@CNF) {
    print $wr join(' ', @$c), " 0\n";
  }
  close $wr;
}

sub out_cnf {
  open(OUT, ">cnf");
  write_cnf(\*OUT);
  close(OUT);
}

sub solve {
  local (*rd, *wr);
  my $pid = open2(\*rd, \*wr, $SOLVER);
  write_cnf(\*wr);
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

my $board = add_literals(9*9*9);

sub solve_all {
  my @save = (@CNF);
  my %cache;
  
  sub add_cache {
    for my $l (@_) {
      if ($l > 0 && $board<=$l && $l<$board+9*9*9) {
        $cache{$l}=1;
      }
    }
  }
  
  add_cache(@_);
  my @out = ();
  for my $y (0..8) {
    for my $x (0..8) {
      my $sum=0;
      for my $v (0..8) {
      	my $lit = lit($x,$y,$v);
      	if ($cache{$lit}) {
          add_clause(-lit($x,$y,$v));
          $sum+=$v+1;
        }
      }
      my @sol=$sum < 45 ? solve() : ();
      @CNF = @save;
      if (@sol) {
        add_cache(@sol);
        for my $v (0..8) {
      	  my $lit = lit($x,$y,$v);
      	  if (!$cache{$lit}) {
	      	add_clause($lit);
	      	add_cache(solve());
	      	@CNF = @save;
      	  }
          push @out, ($cache{$lit} ? $lit : -$lit);
          print STDERR $v+1 if $cache{$lit};
        }
      } else {
        for my $v (0..8) {
        	my $lit = lit($x,$y,$v);
        	push @out, ($cache{$lit} ? $lit : -$lit);
        	print STDERR $v+1 if $cache{$lit};
        }
      }
      print STDERR "\t";
    }
    print STDERR "\n";
  }
  return @out;
}

sub lit {
  my $x = shift;
  my $y = shift;
  my $v = shift || 0;
  return $board + $y * 81 + $x * 9 + $v;
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
  my $nc = shift;
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
    
    # hi/lo not adjacent
    add_clause(-lit($_[$i], 0, $lo), -lit($_[$i+1], 0, $hi));
    add_clause(-lit($_[$i], 0, $hi), -lit($_[$i+1], 0, $lo));
  }
  # Nonconsecutive
  if ($nc) {
    for my $i (0..$#_ - 1) {
  	  for my $v (0..7) {
  	    add_clause(-lit($_[$i],0,$v), -lit($_[$i+1],0,$v+1));
  	    add_clause(-lit($_[$i],0,$v+1), -lit($_[$i+1],0,$v));
      }
    }  
  }
}

sub thermo {
  for my $i (0..$#_ - 1) {
    for my $v (0..8) {
      add_clause(-lit($_[$i],0,$v),
      			 map {lit($_[$i+1], 0, $_)} ($v+1..8));
    }
  }
}

sub knight_pairs {
  my @out;
  for my $i (0..7) {
    for my $j (0..6) {
      push @out, [lit($i,$j), lit($i+1,$j+2)];
      push @out, [lit($j,$i), lit($j+2,$i+1)];
      push @out, [lit(8-$i,$j), lit(8-($i+1),$j+2)];
      push @out, [lit(8-$j,$i), lit(8-($j+2),$i+1)];
    }
  }
  return \@out;
}

sub king_pairs {
  my @out;
  for my $i (0..7) {
    for my $j (0..7) {
      push @out, [lit($i,$j), lit($i+1,$j+1)];
      push @out, [lit(8-$i,$j), lit(8-($i+1),$j+1)];
    }
  }
  return \@out;
}

sub queen_pairs {
  my @out;
  for my $i (0..7) {
    for my $j (0..7) {
      for my $k (1..8-($i > $j ? $i : $j)) {
        push @out, [lit($i,$j), lit($i+$k,$j+$k)];
        push @out, [lit(8-$i,$j), lit(8-($i+$k),$j+$k)];
      }
    }
  }
  return \@out;
}

sub ortho_pairs {
  my @out;
  for my $i (0..7) {
    for my $j (0..8) {
      push @out, [lit($i,$j), lit($i+1,$j)];
      push @out, [lit($j,$i), lit($j,$i+1)];
    }
  }
  return \@out;
}

sub pawn_pairs {
  my @out;
  for my $y (1..8) {
    for my $x (0..8) {
      push @out, [lit($x,$y), lit($x-1,$y-1)] if ($x > 0);
      push @out, [lit($x,$y), lit($x+1,$y-1)] if ($x < 8);
    }
  }
  # Promotion
  for my $x (0..8) {
    # Queen
    for my $z (1..8) {
      push @out, [lit($x), lit($x-$z,$z)] if $x - $z >= 0; 
      push @out, [lit($x), lit($x+$z,$z)] if $x + $z <= 8; 
    }
    next;
    # Knight
    push @out, [lit($x), lit($x-2,1)] if $x - 2 >= 0; 
    push @out, [lit($x), lit($x-1,2)] if $x - 1 >= 0; 
    push @out, [lit($x), lit($x+1,2)] if $x + 1 <= 8; 
    push @out, [lit($x), lit($x+2,1)] if $x + 2 <= 8; 
  }
  return \@out;
}

sub not_same {
  my $groups = shift;
  my $digits = shift || [0..8];
  my $others = shift;
  my $rev = shift;
  $rev = $others if (!defined($rev));
  for my $group (@$groups) {
    for my $i (0..$#$group-1) {
      for my $j ($i+1..$#$group) {
        for my $v (@$digits) {
          for my $v2 ($others ? @$others : ($v)) {
            add_clause (-${$group}[$i]-$v, -${$group}[$j]-$v2);
            if ($rev) {
              add_clause (-${$group}[$i]-$v2, -${$group}[$j]-$v);
            }
          }
        }
      }
    }
  }
}

sub not_conseq {
  my $groups = shift;
  for my $group (@$groups) {
    for my $i (0..$#$group-1) {
      my ($a, $b) = @{$group}[$i,$i+1];
      for my $v (0..7) {
        add_clause (-$a-$v, -$b-$v-1);
        add_clause (-$a-$v-1, -$b-$v);
      }
    }
  }
}

sub diff5 {
  my $group = shift;
  for my $i (0..$#$group-1) {
    my ($a, $b) = @{$group}[$i,$i+1];
    for my $v1 (0..8) {
	for my $v2 ($v1..$v1+4) {
	    last if ($v2 > 8);
	    add_clause(-$a-$v1,-$b-$v2);
	    add_clause(-$a-$v2,-$b-$v1);
	    print STDERR "a=$a b=$b v1=$v1 v2=$v2\n";
	}
    }
  }
}

sub symmetry {
  for my $x (0..8) {
    for my $y (0..8) {
      for my $v (0..8) {
        add_clause(-lit($x,$y,$v), lit(8-$x,8-$y,8-$v));
      }
    }
  }
}

sub bishop {
  my $digits = shift;
  my @white = map {lit($_ * 2 + 1)} (0..39);
  my @black = map {lit($_ * 2)} (0..40);
  for my $d (@$digits) {
    for my $c (@white) {
      add_clause(-$c-$d);
    }
  }
}

sub clones {
    my $groups = shift;
    # Same within each group
    for my $g (@$groups) {
	for my $i (0..$#$g-1) {
	    my ($a, $b) = ($g->[$i], $g->[$i+1]);
	    for my $v (0..8) {
		add_clause(-$a - $v,  $b + $v);
		add_clause( $a + $v, -$b - $v);
	    }
	}
    }
    # Different between groups
    #my @reps = map {$_->[0]} @$groups;
    #not_same([\@reps]);
}

sub sudoku {
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
}

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

sudoku();

# Manhattan
#for my $c1 (0..79) {
#  for my $c2 ($c1+1..80) {
#    my $dx = abs($c1%9 - $c2%9);
#    my $dy = int($c2/9) - int($c1/9);
#    my $d = $dx + $dy;
#    next if ($d > 9 || !$dx || !$dy);
#    add_clause(-lit($c1,0,$d-1),-lit($c2,0,$d-1));
#  }
#}

# Diagonals
sudoku_excl(map {lit($_,$_)} (0..8));
sudoku_excl(map {lit($_,8-$_)} (0..8));

#clones(
#    [
#     [lit(2,0), lit(5,7)], # Yellow
#     [lit(5,0), lit(1,6)], # Orange
#     [lit(3,1)], # Grey
#     [lit(4,1), lit(4,3), lit(6,3)], # Blue
#     [lit(3,2)], # Pink
#     [lit(7,2), lit(4,7)], # Red
#     [lit(2,5), lit(4,5), lit(3,8), lit(6,8)] # Green
#    ]);

# Givens
add_clause(lit(0,0,3));
add_clause(lit(6,0,4));
add_clause(lit(8,0,8));
add_clause(lit(0,3,1));
add_clause(lit(3,3,4));
add_clause(lit(7,3,7));
add_clause(lit(1,5,3));
add_clause(lit(5,5,8));
add_clause(lit(8,5,5));
add_clause(lit(0,8,7));
add_clause(lit(2,8,2));
add_clause(lit(8,8,6));

# Sanke -> Green
add_clause(lit(2,5,0));
add_clause(lit(4,5,7));
add_clause(lit(3,8,1));
add_clause(lit(6,8,5));

# Diadem -> Blue
add_clause(lit(4,1,3));
add_clause(lit(4,3,0));
add_clause(lit(6,3,3));

# Ring -> Purple
add_clause(lit(3,2,8));

# Enigma -> Grey
add_clause(lit(3,1,0));

# Locket -> Orange
add_clause(lit(5,0,7));
add_clause(lit(1,6,1));

# Cup -> Yellow
add_clause(lit(2,0,6));
add_clause(lit(5,7,3));

# Diary -> Red
add_clause(lit(7,2,5));
add_clause(lit(4,7,8));

sub draw_board {
  my @LABELS=qw/1 2 3 4 5 6 7 8 9/;
  my %sol = map { abs($_) => ($_ > 0 ? 1 : 0) } @_;

  for my $y (0..8) {
    for my $x (0..8) {
      for my $v (0..8) {
        print $LABELS[$v] if $sol{lit($x,$y,$v)};
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
  draw_board(@sol);
  add_clause(map {$board<=abs($_) && abs($_)<$board+9*9*9 ? - $_ : ()} @sol);
  my @out=solve();
  draw_board(@out) if @out;
  @CNF=@save;
  return @out;
}


### SOLVE

out_cnf();

my @sol=solve();
unless (@sol) {
  print STDERR "UNSATISFIABLE\n";
  exit;
}

if (my @sol2 = another_sol(@sol)) {
  print STDERR "Not unique!\n";
  @sol = solve_all(@sol, @sol2);
  print STDERR "\n\n";
}

draw_board(@sol);

## PRINT OUTPUT
#print "p cnf $literal_count ", scalar @CNF, "\n";
#for my $c (@CNF) {
#  print join(' ', @$c), " 0\n";
#}
