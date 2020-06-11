use strict;

sub parselit {
  my $lit = shift;
  return $lit unless $lit;
  my $x = abs($lit) - 1;
  my @LABELS=qw/1♙ 2♖ 4♘ 6♗ 9♕ 8♔ 7♝ 5♞ 3♜/;
  my $r = int($x/81) + 1;
  my $c = int($x/9) % 9 + 1;
  my $v = $x % 9;
  return ($lit < 0 ? '!':'') ."r${r}c$c=".$LABELS[$v];
}

sub getloc {
  my $lit = shift;
  return int((abs($lit)-1)/9);
}

sub parseclause {
  my $n = shift;
  my @clause = @_;
  my $trivial = 1;
  for my $i (0..$#clause - 1) {
    if (getloc($clause[$i]) != getloc($clause[$i+1])) {
      $trivial = 0; last;
    }
  }
  if ($trivial && @clause > 1) {
    return '';
  }
  
  return "[$n:".join(' ', map {parselit($_)} @clause).']';
}

my %clause;

#while (<>) {
#  chomp;
#  my @line = split;
#  print join(' ', map {parselit($_)} @line), "\n";
#}
#exit;

while (<>) {
  chomp;
  my @line = split;
  my $lit = 1;
  my @c;
  for my $i (1..$#line) {
    if (!$line[$i]) {
      $lit = 0;
      next;
    }
    if ($lit) {
      push @c, $line[$i];
      $line[$i]=parselit($line[$i]);
    } else {
      $line[$i]=$clause{$line[$i]};
    }
  }
  $clause{$line[0]} = parseclause($line[0],@c);
  print join(' ', @line), "\n";
}