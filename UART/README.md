# UART Peripheral
## Block Diagram

```
                            ┌─────────────────────────────────────────────────────────────┐            
                            │                                               ┌────────┐    │            
                            │                                 FIFO          │        │    │            
                            │                             ┌──┬──┬──┬──┐     │        │    │            
                            │    ┌───────────────────┐    │  │  │  │  │     │        │    │            
Rx ─────────────────────────│───►│   Reciever        ├───►┤  │  │  │  ├────►┤        │    │            
                            │    └───────────────────┘    │  │  │  │  │     │        ├────│─────── Data
                            │                   ▲         └──┴──┴──┴──┘     │ Master │    │            
                            │                   │                           │        │    │            
                            │                   │   ┌──────────────────┐    │        │◄───│─────── CLK 
                            │                   ├───┤  Baud Rate Gen.  ├────┤        │    │            
                            │                   │   └──────────────────┘    │        │    │            
                            │                   │                           │        │    │            
                            │                   │             FIFO          │        │    │            
                            │                   ▼         ┌──┬──┬──┬──┐     │        │    │            
                            │    ┌───────────────────┐    │  │  │  │  │     │        │    │            
Tx ◄────────────────────────│────┤  Transmitter      ├◄───┤  │  │  │  ├◄────┤        │    │            
                            │    └───────────────────┘    │  │  │  │  │     │        │    │            
                            │                             └──┴──┴──┴──┘     │        │    │            
                            │                                               │        │    │            
            Interrupt ◄─────│───────────────────────────────────────────────┤        │    │            
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
  - [ ] DMA Support
- [ ] Verification
  - [ ] Code
  - [ ] Toggle
  - [ ] Functional

## Register Mappings

| Register Name   | Offset (Hex) | Permission | Size (Bits) | Reset (Hex) | Description                                                                     |
| --------------- | ------------ | ---------- | ----------- | ----------- | ------------------------------------------------------------------------------- |
| tx_data         | 0x0          | write      | 32          | 0x0         | Holds data that needs to be sent over UART                                      |
| rx_data         | 0x4          | read       | 32          | 0x0         | Hold data that is received over the UART                                        |
| baud            | 0x8          | read-write | 32          | 0xA2C       | Controls the baud-value of the UART                                             |
| status          | 0xc          | read       | 32          | 0x7         | Holds various status fields                                                     |
| control         | 0x10         | read-write | 32          | 0x0         | Various control fields to manipulate communication parameters                   |
| status_clear    | 0x14         | write      | 32          | 0x0         | Register to clear various status bits                                           |
| interrupt_en    | 0x18         | read-write | 32          | 0x0         | Controls which status bit events should raise an interrupt from the UART module |
| dma_tx_baddress | 0x22         | write      | 32          | 0x8000_0000 | Register for base address in memory to fetch tx data from                       |
| dma_rx_baddress | 0x26         | write      | 32          | 0xC000_0000 | Register for base address in memory to store rx data to                         |
| dma_tx_size     | 0x30         | write      | 32          | 0x0         | Size of the data to be taken from memory for transmission                       |
| dma_rx_size     | 0x34         | write      | 32          | 0x0         | Size of the data to be stored in memory after receiving                         |

### status register
Status of the peripheral

| 31 - 10  | 9           | 8           | 7           | 6           | 5             | 4            | 3           | 2          | 1          | 0       |
| -------- | ----------- | ----------- | ----------- | ----------- | ------------- | ------------ | ----------- | ---------- | ---------- | ------- |
| Reserved | DMA_RX_DONE | DMA_TX_DONE | BREAK_ERROR | FRAME_ERROR | OVERRUN_ERROR | PARITY_ERROR | RX_NOTEMPTY | RX_NOTFULL | TX_NOTFULL | TX_DONE |

#### ERROR Signals
- BREAK_ERROR : Indicates if both, the data, and the stop bits received are all zeros
- FRAME_ERROR : Indicates if the stop bit that is received is 0
- OVERRUN_ERROR : Indicates if the receive FIFO is full, and a new character is received
- PARITY_ERROR : Error in parity of the received data

### control register
Controls the behaviour of the UART Protocol

| 31 - 6   | 5         | 4         | 3 - 2       | 1 - 0     |
| -------- | --------- | --------- | ----------- | --------- |
| Reserved | dma_rx_en | dma_tx_en | PARITY_MODE | STOP_BITS |

#### PARITY_MODE
- 0 : 8n*
- 1 : 8o*
- 2 : 8e*
- 3 : Illegal

### status_clear register
The corresponding bits are set to 1 to clear the status register from the errors

| 31 - 4   | 3           | 2          | 1          | 0       |
| -------- | ----------- | ---------- | ---------- | ------- |
| Reserved | RX_NOTEMPTY | RX_NOTFULL | TX_NOTFULL | TX_DONE |

### interrupt_en register
Enables the interrupt causes

| 31 - 8   | 7           | 6           | 5             | 4            | 3           | 2          | 1          | 0       |
| -------- | ----------- | ----------- | ------------- | ------------ | ----------- | ---------- | ---------- | ------- |
| Reserved | BREAK_ERROR | FRAME_ERROR | OVERRUN_ERROR | PARITY_ERROR | RX_NOTEMPTY | RX_NOTFULL | TX_NOTFULL | TX_DONE |


> [!NOTE]
> Adapted from [FPGADude/Digital-Design](https://github.com/FPGADude/Digital-Design/tree/4cb93eeaba434eb02c2e200060921fe0e5aebf03/FPGA%20Projects/UART)
