# UART Peripheral
## Block Diagram

```
                            ┌─────────────────────────────────────────────────────────────┐            
                            │                                               ┌────────┐    │            
                            │                                               │        │    │            
                            │                                               │        │    │            
                            │    ┌───────────────────┐                      │        │    │            
Rx ─────────────────────────│───►│   Reciever        ├─────────────────────►┤        │    │            
                            │    └───────────────────┘                      │        ├────│─────── Data (Bus)
                            │                   ▲                           │  APB   │    │            
                            │                   │                           │ Logic  │    │            
                            │                   │   ┌──────────────────┐    │        │◄───│─────── CLK 
                            │                   ├───┤  Baud Rate Gen.  ├────┤        │    │            
                            │                   │   └──────────────────┘    │        │    │            
                            │                   │                           │        │    │            
                            │                   │                           │        │    │            
                            │                   ▼                           │        │    │            
                            │    ┌───────────────────┐                      │        │    │            
Tx ◄────────────────────────│────┤  Transmitter      ├◄─────────────────────┤        │    │            
                            │    └───────────────────┘                      │        │    │            
                            │                                               │        │    │            
                            │                                               │        │    │            
                            │                                               │        │    │                      
                            │                                               │        │    │            
                            │                                               └────────┘    │            
                            └─────────────────────────────────────────────────────────────┘            
```

## Components
- [ ] Design
  - [x] Transmitter
  - [x] Reciever
  - [x] FIFO
  - [x] Interrupt
  - [x] Baud Rate Generator
  - [x] Registers
- [ ] Verification
  - [ ] Code
  - [ ] Toggle
  - [x] Functional
    - [x] [Simple testbench](./verif/test_top.sv)
    - [ ] UVM Testbench

## Register Mappings

| Register Name   | Offset (Hex) | Permission | Size (Bits) | Reset (Hex) | Description                                                                     |
| --------------- | ------------ | ---------- | ----------- | ----------- | ------------------------------------------------------------------------------- |
| tx_data         | 0x0          | write      | 32          | 0x0         | Holds data that needs to be sent over UART                                      |
| rx_data         | 0x4          | read       | 32          | 0x0         | Hold data that is received over the UART                                        |

## Module Parameters and Ports
```verilog
module apb_uart_top #(
    parameter integer DATA_WIDTH     = 32,               // number of data bits from the apb bus
                      ADDR_WIDTH    = 32,                // width of address of apb bus
                      PARITY_MODE   = 0,                 // Parity mode ()
                      STOP_BITS     = 1,                 // Number of stop Bits
                      BAUD          = 9600,              // Baud rate
                      CLK_FREQ      = 100_000_000,       // 100 MHz - Input clock frequency for Baud rate generation
                      BASE_MMR_ADDRESS  = 32'h0000_0000  // Base APB Address for UART Peripheral
) (
    output                        probe_tick, // For testing

    // uart ports
    input                         rx,
    output                        tx,

    // APB ports
    input                         PCLK,
    input                         PRESETn, // System bus equivalent Reset

    input      [ADDR_WIDTH - 1:0] PADDR,   // Address
    input                         PSELx,   // Select
    input                         PENABLE, // Enable
    input                         PWRITE,  // Direction
    input      [DATA_WIDTH - 1:0] PWDATA,  // Write data
    input                  [ 3:0] PSTRB,   // Write strobes

    output                        PREADY,  // Slave interface Ready
    output reg [DATA_WIDTH - 1:0] PRDATA,  // Slave interface Read Data
    output                        PSLVERR  // Slave interface Transfer error
);
```

> [!NOTE]
> Parity Configurations:
>   0 : 8n*
>   1 : 8o*
>   2 : 8e*
>   3 : Illegal

> [!NOTE]
> Only the last 8 bits [7:0] of tx_data will be will be transferred at a time

> [!NOTE]
> Credits
> - UART logic adapted from [FPGADude/Digital-Design](https://github.com/FPGADude/Digital-Design/tree/4cb93eeaba434eb02c2e200060921fe0e5aebf03/FPGA%20Projects/UART)
> - UVM testbench from [Lampro-Mellon/apb-uart-uvm-env](https://github.com/Lampro-Mellon/apb-uart-uvm-env)
