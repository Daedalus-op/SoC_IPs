include sources.mk
TIMEOUT := 30000
TOP_MODULE := test_master

all: waveform.vcd

waveform.vcd: obj_dir/V$(TOP_MODULE)
	./obj_dir/V$(TOP_MODULE) +trace

obj_dir/V$(TOP_MODULE): $(SRCS) tb.cpp
	verilator -Wno-PINMISSING --cc --timing --top-module $(TOP_MODULE) $(SRCS) -I../src --exe -CFLAGS "-std=c++20" tb.cpp --trace
	make -j -C obj_dir -f V$(TOP_MODULE).mk V$(TOP_MODULE)

sim: waveform.vcd
	surfer waveform.vcd

clean:
	rm -rf obj_dir waveform.vcd
