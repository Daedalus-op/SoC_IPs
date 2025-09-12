METHOD := VIVADO
TOP_MODULE := test_top

# ---------------------------
include sources.mk
TIMEOUT := 30000

ifeq ($(METHOD),VIVADO)
DEPENDS = $(SRCS)
else
DEPENDS = verif/obj_dir/V$(TOP_MODULE)
endif

all: waveform.vcd

synth: $(SRCS)
	yosys -l synth.log synth/synth.ys
	cd ..

ifeq ($(METHOD), VIVADO)
waveform.vcd: $(DEPENDS)
	xvlog --sv $(SRCS)
	xelab $(TOP_MODULE)
	xsim $(TOP_MODULE) -runall
	notify-send "Design Waveform Ready"
else
waveform.vcd: $(DEPENDS)
	./verif/obj_dir/V$(TOP_MODULE) +trace
endif

verif/obj_dir/V$(TOP_MODULE): $(SRCS) verif/tb.cpp
	verilator -Wno-PINMISSING --cc --timing --top-module $(TOP_MODULE) $(SRCS) -Isrc --exe -CFLAGS "-std=c++20" tb.cpp --trace --Mdir verif/obj_dir
	make -j -C verif/obj_dir -f V$(TOP_MODULE).mk V$(TOP_MODULE)

sim: waveform.vcd
	surfer -s verif/surfer/state.ron waveform.vcd &

clean:
	rm -rf verif/obj_dir waveform.vcd *.log *.jou *.pb xsim.dir work.test_top.wdb synthesized_netlist.v
