use strict;
no strict 'vars';
use POSIX;

sub bits {
    my $v = shift;
    return ceil(log($v)/log(2)) + 1;
}

$_ = join('',<>);
s|\[\[\[(.+?)\]\]\]|eval($1);""|ges;
s|{{(.+?)}}|eval($1)|ges;
print;
