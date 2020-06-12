use strict;

use JSON;
use Term::ANSIColor;
use Data::Dumper;

my $sol = decode_json(join('',<>));
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
	$bx[$coord->[0]][$coord->[1]].="$i";
    }
    $i++;
}

for my $r (0..$#{$sol{board}}) {
    for my $c (0..$#{$sol{board}->[0]}) {
	my $fg_color = $sol{water}[$r][$c] ? $WATER_COLOR : $NOWATER_COLOR;
	my $bg_color = $boxboard[$r][$c] || $NOBOX_COLOR;
	print colored("  ".$sol{board}[$r][$c]." [".$bx[$r][$c]."]  \t", $fg_color, $bg_color);
    }
    print "\n";
}
