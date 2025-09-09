METHOD := VIVADO
TOP_MODULE := test_top

# ---------------------------
include sources.mk
TIMEOUT := 30000

ifeq ($(METHOD),VIVADO)
DEPENDS = test.tcl $(SRCS)
else
DEPENDS = obj_dir/V$(TOP_MODULE)
endif

all: waveform.vcd

ifeq ($(METHOD), VIVADO)
waveform.vcd: $(DEPENDS)
	xvlog --sv $(SRCS)
	xelab $(TOP_MODULE)
	xsim $(TOP_MODULE) -runall
	notify-send "Design Waveform Ready"
else
waveform.vcd: $(DEPENDS)
	./obj_dir/V$(TOP_MODULE) +trace
endif

obj_dir/V$(TOP_MODULE): $(SRCS) tb.cpp
	verilator -Wno-PINMISSING --cc --timing --top-module $(TOP_MODULE) $(SRCS) -I../src --exe -CFLAGS "-std=c++20" tb.cpp --trace
	make -j -C obj_dir -f V$(TOP_MODULE).mk V$(TOP_MODULE)

sim: waveform.vcd
	surfer -c surfer/surfer_commands -s surfer/top_state.ron waveform.vcd &

clean:
	rm -rf obj_dir waveform.vcd *.log *.jou *.pb xsim.dir
