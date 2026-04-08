This repository contains the RTL design and implementation of multiple industry-relevant communication protocols including CAN (Controller Area Network), MMC Host Controller (1-bit mode), and APB (Advanced Peripheral Bus), developed using Verilog and SystemVerilog.

The CAN protocol implementation includes complete transmit and receive paths with modules for frame generation, arbitration handling, bit stuffing/de-stuffing, CRC-based error detection, bus interfacing, register interface, and bit timing unit (BTU) for synchronization and baud rate control. The design ensures robust communication with proper error handling and protocol compliance.

The MMC Host Controller is designed for 1-bit mode operation and includes CRC7 and CRC16 modules for command and data integrity, transmit and receive FIFOs for buffering, command transmitter and receiver modules for handling MMC commands, a dedicated data path for serial data transfer, and an FSM-based controller to manage protocol sequencing and control flow between host and card.

The APB interface is implemented as a low-power peripheral bus with register-mapped communication. It includes address decoding, read/write control logic, and proper handshake signaling using PSEL, PENABLE, and PREADY, enabling efficient integration with peripheral modules.

The overall design follows a modular RTL architecture with clear separation of control and data paths. Key digital design concepts such as finite state machines (FSM), FIFOs, CRC generation/checking, and protocol timing control are extensively used. The repository is suitable for learning, verification, and interview preparation in VLSI front-end roles, showcasing practical implementation of real-world protocols.
