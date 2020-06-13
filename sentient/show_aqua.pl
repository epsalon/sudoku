use strict;

use JSON;
use Term::ANSIColor;
use Data::Dumper;

my @HORIZ_BORDER = (' ', '─');
my @VERT_BORDER = (' ', '│');
my @CORNER = (' ','╷','╶', '┌', '╴', '┐', '─', '┬', '╵', '│', '└', '├', '┘', '┤', '┴', '┼');

sub corner {
    my ($v1,$h1,$h2,$v2) = @_;
    return $CORNER[$v1*8 + $h1*4 + $h2*2 + $v2];

}


while (<>) {
  my $sol = decode_json($_);
  my %sol = %$sol;

  my @BOX_COLORS=qw/on_red on_green on_yellow on_magenta on_cyan on_bright_black on_bright_red/;
  my $NOBOX_COLOR="on_white";
  my $WATER_COLOR="blue";
  my $NOWATER_COLOR="black";

  my @bx;
  my @boxboard;
  my $i=0;
  for my $b (@{$sol{boxes}}) {
      my $color = shift @BOX_COLORS;
      for my $coord (@$b) {
	  $boxboard[$coord->[0]][$coord->[1]] = $color;
	  $bx[$coord->[0]][$coord->[1]]=$i+1;
      }
      $i++;
  }

  # corner(0,0,1,1) - corner(0,1,1,bx[0][0] != bx[0][1]) - corner(0,1,1,bx[0][1] != bx[0][2]) .. corner(0,1,1,bx[0][$# - 1] != bx[0][$#]) - corner(0,1,0,1)
  # | (0,0) x0 (0,1) x1 ... (0,$#) | xn = bx[0][n] != bx[0][n+1]
  # corner(1,0,bx[0][0]!=bx[0][1],1) y corner(box[0][0]!=bx[1][0],bx[0][0]!=bx[0][1],bx[0][1]!=bx[0][2],bx[1][0] != bx[2][0]) y corner(0,1,1,bx[0][1] != bx[0][2]) .. 
  
  my (@vert_borders, @horiz_borders);
  for my $r (0..$#bx) {
      for my $c (0..$#bx) {
	  if ($bx[$r][$c] != $bx[$r][$c+1]) {
	      $vert_borders[$r+1][$c+1] = 1;
	  }
	  if ($bx[$r][$c] != $bx[$r+1][$c]) {
	      $horiz_borders[$r+1][$c+1] = 1;
	  }
      }
  }
  $horiz_borders[0] = [0, (1) x $#bx, 0];
  for my $r (0..$#bx) {
      $vert_borders[$r+1][0] = 1;
  }

  sub box_row {
      my $r = shift;
      my $vb = shift;
      my $hb = shift;
      for my $c (0..$#bx + 1) {
	  print corner($vb->[$r][$c], $hb->[$r][$c], $hb->[$r][$c+1],$vb->[$r+1][$c]);
	  my $border = $HORIZ_BORDER[$hb->[$r][$c+1]];
	  print $border x 11 unless ($c > $#bx);
      }
      print "\n";
  }

  for my $r (0..$#{$sol{board}}) {
      box_row($r, \@vert_borders, \@horiz_borders);
      for my $c (0..$#{$sol{board}->[0]}) {
	  my $water = $sol{water}[$r][$c];
	  my $wch = $water ? '~' : ' ';
	  my $fg_color = $water ? $WATER_COLOR : $NOWATER_COLOR;
	  my $bg_color = $boxboard[$r][$c] || $NOBOX_COLOR;
	  print $VERT_BORDER[$vert_borders[$r+1][$c]];
	  print colored(" $wch ".$sol{board}[$r][$c]." [".($bx[$r][$c] || ' ')."] $wch ", $fg_color, $bg_color);
      }
      print $VERT_BORDER[$vert_borders[$r+1][$#{$sol{board}->[0]}+1]];
      print "\n";
  }
  box_row(scalar(@{$sol{board}}), \@vert_borders, \@horiz_borders);
  print "\n\n";
}
