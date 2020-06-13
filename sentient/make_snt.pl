use strict;
no strict 'vars';
$_ = join('',<>);
s|\[\[\[(.+?)\]\]\]|eval($1);""|ges;
s|{{(.+?)}}|eval($1)|ges;
print;
