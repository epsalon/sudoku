use strict;

use JSON;

while (<>) {
    my $sol = decode_json($_);
    delete $sol->{board};
    delete $sol->{water};
    delete $sol->{boxWaterTotal};
    open(ASS, ">assign") or die;
    print STDERR encode_json($sol),"\n";
    print ASS encode_json($sol),"\n";
    close(ASS);
    print STDERR "TESTING: $_";
    open(SOL,"sentient --run --machine lingeling -n 2 --assign-file assign an9.optimized.json|") or die;
    my $s1 = <SOL>;
    # Another solution?
    my $s2 = <SOL>;
    close(SOL);
    if ($s2 =~ /{}/) {
	print STDERR "SINGLE SOLUTION: $s1\n\n";
	print $s1;
    } else {
	print STDERR "Too many solutions:\n$s1$s2\n\n";
    }
}
