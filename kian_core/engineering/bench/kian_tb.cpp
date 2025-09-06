#include <fcntl.h>
#include <stdint.h>
#include <signal.h>
#include "verilated_vcd_c.h"
#include "Vkian_sim.h"
#include <ctime>
#include <iostream>

static bool done = false;
vluint64_t main_time = 0;  // Current simulation time

// Called by $time in Verilog simulation
double sc_time_stamp () {
    return main_time;  // converts to double
}

// Signal handler to catch Ctrl-C and cleanly exit
void INThandler(int signal) {
    std::cout << "\nCaught ctrl-c\n";
    done = true;
}

int main(int argc, char **argv, char **env) {
    Verilated::commandArgs(argc, argv);
    Vkian_sim* top = new Vkian_sim;

    // Setup VCD tracing if enabled by +vcd=1 argument
    VerilatedVcdC * tfp = nullptr;
    const char *vcd = Verilated::commandArgsPlusMatch("vcd=");
    if (vcd[0] && atoi(vcd) != 0) {
        Verilated::traceEverOn(true);
        tfp = new VerilatedVcdC;
        top->trace (tfp, 99);
        tfp->open ("trace.vcd");
    }

    // Setup Ctrl-C handler
    signal(SIGINT, INThandler);

    // Parse timeout argument (simulation max cycles)
    // vluint64_t timeout = 0;
    // const char *arg_timeout = Verilated::commandArgsPlusMatch("timeout=");
    // if (arg_timeout[0]) {
    //     timeout = std::stoull(std::string(arg_timeout + 8));
    // }

    bool dump_vcd = false;
    vluint64_t vcd_start = 0;
    const char *arg_vcd_start = Verilated::commandArgsPlusMatch("vcd_start=");
    if (arg_vcd_start[0]) {
        vcd_start = std::stoull(std::string(arg_vcd_start + 10));
    }

    top->clk = 1;  // Initialize clock

    while (!(done || Verilated::gotFinish())) {
        if (tfp && !dump_vcd && (main_time >= vcd_start)) {
            dump_vcd = true;
        }

        // Reset active for first 100 cycles
        top->rstn = (main_time < 10);

        top->eval();

        if (dump_vcd) {
            tfp->dump(main_time);
        }

        // Check for sim_done signal (wired in Verilog as "done" or "sim_done")
        if (top->sim_done) {  // Replace with your actual done signal name
            std::cout << "Simulation done detected at cycle " << main_time << "\n";
            done = true;
        }

        // Timeout check
        // if (timeout && (main_time >= timeout)) {
        //     std::cout << "Timeout reached at cycle " << main_time << ", exiting...\n";
        //     done = true;
        // }

        // Toggle clock signal
        top->clk = !top->clk;
        // Advance simulation time (use system clock period or desired step)
        main_time += 31;  // Adjust to your clock period accordingly
    }

    if (tfp) {
        tfp->close();
        delete tfp;
    }

    top->final();
    delete top;

    return 0;
}
