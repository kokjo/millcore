demo.bin: demo.asc
	icetime -d hx8k -c 12 -mtr demo.rpt demo.asc
	icepack demo.asc demo.bin

demo.asc: demo.pcf demo.blif
	arachne-pnr -d 8k -o demo.asc -p demo.pcf demo.blif

demo.blif: demo.v soc.v cpu.v
	yosys -ql soc.log -p 'synth_ice40 -top demo -blif demo.blif' $^

soc.test: testbench_soc.v soc.v cpu.v
	iverilog -o soc.test $^

soc.vcd: soc.test
	./soc.test

clean:
	rm -f *.asc *.blif *.bin *.test *.vcd *.rpt *.log
