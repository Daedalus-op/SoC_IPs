include sources.mk
TIMEOUT := 30000
TOP_MODULE := kian_sim

all: waveform.vcd

waveform.vcd: obj_dir/Vkian_sim
	./obj_dir/Vkian_sim +timeout_cycles=$(TIMEOUT) +firmware=my.hex +signature=my_sig.signature +sig_start=0x80006110 +sig_end=0x80006a50 +trace

obj_dir/Vkian_sim: $(SRCS) empty.cpp
	verilator -Wno-VARHIDDEN --cc --timing --top-module $(TOP_MODULE) $(SRCS) -I../kianv_harris_edition --exe -CFLAGS "-std=c++20" empty.cpp --trace
	make -j -C obj_dir -f V$(TOP_MODULE).mk V$(TOP_MODULE)

sim: waveform.vcd
	surfer waveform.vcd

clean:
	rm -rf obj_dir waveform.vcd my_sig.signature
