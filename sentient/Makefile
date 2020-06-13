MACHINE=lingeling
NUM=5

.PRECIOUS: %.compiled.json %.optimized.json %.solution.json

%.snt: %.snt.in make_snt.pl
	perl make_snt.pl < $< > $@

%.compiled.json: %.snt
	sentient -c < $< > $@

%.optimized.json: %.compiled.json
	sentient -o < $< > $@

%.solution.json: %.optimized.json
	sentient --run --machine $(MACHINE) -n $(NUM) < $< > $@

%.solution.out: %.solution.json show_aqua.pl
	perl show_aqua.pl < $< > $@
