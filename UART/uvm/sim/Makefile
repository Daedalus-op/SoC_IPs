GREEN  := \033[0;32m
YELLOW := \033[0;33m
RED    := \033[0;31m
RESET  := \033[0m

TEST=apbuart_data_compare_test
SCALE=1ns
FILE = testname.f
TEST_NAMES =`cat $(FILE)`
SRCS := $(shell cat flist)

test-list:
			@for i in $(TEST_NAMES); do \
				echo $$i; \
			done

compile: $(SRCS)
			@echo "$(GREEN)\nCompiling Design ---------------------------\n$(RESET)"
			xvlog --sv -L uvm $(SRCS)

run-test: compile
			@echo "$(YELLOW)\nRunning $(TEST) Test ---------------------------\n$(RESET)"
			@echo "$(YELLOW)\nStep :Elaboration$(RESET)"
			xelab -L uvm -top tbench_top -snapshot tbench_top_sim 
			@echo "$(YELLOW)\nStep :Simulation$(RESET)"
			xsim tbench_top_sim -testplusarg UVM_TIMEOUT=900000000 -testplusarg UVM_TESTNAME=$(TEST) -runall;\

run-test-cov: compile
			@echo "$(GREEN)\nRunning $(TEST) Test ---------------------------\n$(RESET)"
			@echo "$(YELLOW)\nStep :Elaboration$(RESET)"
			xelab -L uvm -top tbench_top -snapshot tbench_top_sim -cc_type sbct -cov_db_dir ./cov_db -cov_db_name cov_dir
			@echo "$(YELLOW)\nStep :Simulation$(RESET)"
			xsim tbench_top_sim -testplusarg UVM_TIMEOUT=900000000 -testplusarg UVM_TESTNAME=$(TEST) -runall
			@echo "$(YELLOW)\nStep :Coverage Reports$(RESET)"
			xcrg -cov_db_dir ./cov_db -report_dir ./cov_report -cov_db_name cov_dir -report_format html

run: compile
			@echo "$(GREEN)\nRunning Tests ---------------------------\n$(RESET)"
			xelab -L uvm -top tbench_top -snapshot tbench_top_sim 
			@for i in $(TEST_NAMES); do \
				xsim tbench_top_sim -testplusarg UVM_TIMEOUT=900000000 -testplusarg UVM_TESTNAME=$$i -runall;\
			done

run-cov: compile
			@echo "$(GREEN)\nRunning Tests with Coverage ---------------------------\n$(RESET)"
			@echo "$(YELLOW)\nStep :Elaboration$(RESET)"
			xelab -L uvm -top tbench_top -snapshot tbench_top_sim -cc_type sbct -cov_db_dir ./cov_db -cov_db_name cov_dir
			@for i in $(TEST_NAMES); do \
				@echo "$(YELLOW)\nStep :Simulation for $(TEST_NAMES)$(RESET)"
				xsim tbench_top_sim -testplusarg UVM_TIMEOUT=900000000 -testplusarg UVM_TESTNAME=$$i -runall;\
			done
			@echo "$(YELLOW)\nStep :Coverage Reports$(RESET)"
			xcrg -cov_db_dir ./cov_db -report_dir ./cov_report -cov_db_name cov_dir -report_format html

cov-gui:
			@echo "$(GREEN)\nOpening coverage reports ---------------------------\n$(RESET)"

clean:
			@echo "$(RED)\nCleaning up.... ---------------------------\n$(RESET)"
			rm -rf *.log *.pb *.jou *.wdb xsim.dir *.vcd cov_db
