soc.bin: soc.asc
	icetime -d hx8k -c 12 -mtr soc.rpt soc.asc
	icepack soc.asc soc.bin

soc.asc: soc.pcf soc.blif
	arachne-pnr -d 8k -o soc.asc -p soc.pcf soc.blif

soc.blif: soc.v cpu.v belt.v ram.v
	yosys -ql soc.log -p 'synth_ice40 -top soc -blif soc.blif' $^

soc_syn.v: soc.blif
	yosys -p 'read_blif -wideports soc.blif; write_verilog soc_syn.v'

soc.test: testbench_soc.v soc.v cpu.v belt.v ram.v
	iverilog -o soc.test $^

soc.vcd: soc.test
	./soc.test

