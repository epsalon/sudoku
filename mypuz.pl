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
  return @out;
}

sub king_pairs {
  my @out;
  for my $i (0..7) {
    for my $j (0..7) {
      push @out, [lit($i,$j), lit($i+1,$j+1)];
      push @out, [lit(8-$i,$j), lit(8-($i+1),$j+1)];
    }
  }
  return @out;
}

sub ortho_pairs {
  my @out;
  for my $i (0..7) {
    for my $j (0..8) {
      push @out, [lit($i,$j), lit($i+1,$j)];
      push @out, [lit($j,$i), lit($j,$i+1)];
    }
  }
  return @out;
}

sub not_same {
  for my $group (@_) {
    for my $i (0..$#$group-1) {
      for my $j ($i+1..$#$group) {
        for my $v (0..8) {
          add_clause (-${$group}[$i]-$v, -${$group}[$j]-$v)
        }
      }
    }
  }
}

sub not_conseq {
  for my $pair (@_) {
  	my ($a, $b) = @$pair;
    for my $v (0..7) {
      add_clause (-$a-$v, -$b-$v-1);
      add_clause (-$a-$v-1, -$b-$v);
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

my $snake = add_literals(9*9);
my $snake_head = add_literals(9*9);

sub neighbors {
  my ($x) = @_;
  my @out;
  push @out, $x-1 if ($x % 9 > 0);
  push @out, $x+1 if ($x % 9 < 8);
  push @out, $x+9 if ($x + 9 < 81);
  push @out, $x-9 if ($x - 9 >= 0);
  return @out;
}

#Snake rules
for my $c (0..80) {
  my @n = neighbors($c);
  # snake -> at least one neighbor is snake
  add_clause(-$snake-$c, map {$snake+$_} @n);
  # snake -> at most two neighbors are snake
  # snake -> at least n-2 neighbors are not snake
  if (@n==3) {
    add_clause(-$snake-$c, map {-$snake-$_} @n);
  } elsif (@n==4) {
    for my $i (0..$#n) {
      add_clause(-$snake-$c, map {-$snake-$_} @n[0..$i-1, $i+1..$#n]);
    }
  }
  # snake head -> snake
  add_clause(-$snake_head-$c, $snake+$c);
  # snake head -> at most one neighbor is snake
  # snake_head && neighbor is snake -> other neighbor is not snake
  for my $i (0..$#n-1) {
    for my $j ($i+1..$#n) {
      add_clause(-$snake_head-$c, -$snake-$n[$i], -$snake-$n[$j]);
    }
  }
  # snake and not head -> at least two neighbors are snake
  for my $i (0..$#n) {
    add_clause(-$snake-$c, $snake_head+$c, map {$snake+$_} @n[0..$i-1, $i+1..$#n]);
  }
  # no 2x2 snake
  for my $x (0..7) {
    for my $y (0..7) {
      $c = $x + $y * 9;
      add_clause(-$snake-$c, -$snake-$c-1, -$snake-$c-9, -$snake-$c-10);
    }
  }
}

# No Headless snakes
my $HEAD_LITERAL_COUNT = 40;
my $snake_head_dist = add_literals(9*9*$HEAD_LITERAL_COUNT);
for my $c (0..80) {
  for my $d (1..$HEAD_LITERAL_COUNT-1) {
    # d_i -> snake
  	add_clause(-$snake_head_dist-$c*$HEAD_LITERAL_COUNT-$d, $snake+$c);
  	# d_i _> some neighbor is d_(i-1)
  	add_clause(-$snake_head_dist-$c*$HEAD_LITERAL_COUNT-$d, map {$snake_head_dist+$_*$HEAD_LITERAL_COUNT+$d-1} neighbors($c));
  	for my $d2 (0..$d-1) {
  	  # d_i -> not d_(i-1), d_(i-2), ..
  	  add_clause(-$snake_head_dist-$c*$HEAD_LITERAL_COUNT-$d, -$snake_head_dist-$c*$HEAD_LITERAL_COUNT-$d2);
  	}
  }
  # d_0 -> head
  add_clause(-$snake_head_dist-$c*$HEAD_LITERAL_COUNT, $snake_head+$c);
  add_clause($snake_head_dist+$c*$HEAD_LITERAL_COUNT, -$snake_head-$c);
  
  # snake -> d_0 || d_1 || ...
  add_clause(-$snake-$c, map {$snake_head_dist+$c*$HEAD_LITERAL_COUNT+$_} (0..$HEAD_LITERAL_COUNT-1))
}

# At most two snake heads
#for my $c1 (0..78) {
#  for my $c2 ($c1+1..79) {
#    for my $c3 ($c2+1..80) {
#      add_clause(-$snake_head-$c1,-$snake_head-$c2,-$snake_head-$c3)
#    }
#  }
#}

# map snake to grid
for my $c (0..80) {
  # Snake -> Odd
  add_clause($snake+$c, map {lit($c,0,$_)} (0,2,4,6,8)); 
  # Not Snake -> even
  add_clause(-$snake-$c, map {lit($c,0,$_)} (1,3,5,7)); 
}

sudoku();

### Givens


sub draw_board {
  my %sol = map { abs($_) => ($_ > 0 ? 1 : 0) } @_;

  for my $y (0..8) {
    for my $x (0..8) {
      for my $v (0..8) {
        print $v+1 if $sol{lit($x,$y,$v)};
      }
      for my $d (0..$HEAD_LITERAL_COUNT-1) {
        print "($d)" if $sol{$snake_head_dist+$y*9*$HEAD_LITERAL_COUNT+$x*$HEAD_LITERAL_COUNT+$d};
      }
      print "S" if $sol{$snake+$y*9+$x};
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
