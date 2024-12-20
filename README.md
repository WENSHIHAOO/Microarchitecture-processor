# Microarchitecture-Processor

This is a RISC-V 64IMA processor. It has Super-Scalar, Set-Associative Caches, Branch Predictor, Translation Lookaside Buffer (TLB), and Victim Caches. This microarchitecture processor originally used a fake operating system (`fake-os.cpp`) to simulate the behavior of the infrastructure and handle system call requests. Over the course of this project, the fake OS was replaced with a real Linux kernel, enabling full system functionality and transitioning from a simulated environment to a real operating system.

## Features

1. **RISC-V 64IMA Architecture**
2. **Super-Scalar Execution**
3. **Set-Associative & Victim Caches**
4. **Branch Prediction**
5. **Translation Lookaside Buffer (TLB)**

## Development Phases

**Hardware Design Process:**
- Conceptual Design
- Behavioral Implementation
- Evaluation
- Structural Implementation
- Layout
- Manufacturing
- Packaging

Due to cost and time constraints, this project focused on completing:
1. Conceptual Design
2. Behavioral Implementation
3. Evaluation

## Project Progress (Semester Summary)

### 1. Initial State: PreOS-MicroArch
The system initially relied on `fake-os.cpp`, a simulated operating system that managed task scheduling and memory operations. The processor operated in a controlled environment where system calls and memory access were mocked to test the microarchitecture.

### 2. Transition to a Real OS
The goal was to integrate a fully functional Linux kernel as the operating system. Key steps included:

1. **Building and Booting the Linux Kernel:**
   - Successfully loaded `vmlinux` (the ELF binary of the Linux kernel) into the simulated infrastructure.
   - Resolved memory access issues caused by address translation during boot, ensuring proper handling of the `satp` CSR for enabling virtual memory.

2. **Device Tree Integration:**
   - Developed a device tree source (DTS) file, which was compiled into a device tree blob (DTB) using the `dtc` tool.
   - Integrated the DTB into the bootloader payload, allowing the kernel to recognize and initialize hardware components during boot.

3. **Bootloader Development:**
   - Experimented with BBL (Berkeley Boot Loader) and OpenSBI.
   - Successfully built a bootloader payload containing both the kernel and DTB.
   - Addressed issues with bootloader memory layout by adjusting linker scripts to base the payload at `0x80000000`.

4. **Replacing `fake-os.cpp`:**
   - System calls (`do_ecall`) and memory operations (`do_pending_write`) previously handled by `fake-os.cpp` were implemented using kernel APIs.
   - Transitioned from simulated infrastructure to a real operating system, removing dependencies on `fake-os.cpp`.

5. **Debugging and Testing:**
   - Resolved ELF loading issues by correctly configuring memory and interpreting kernel binaries.
   - Validated performance and functionality in the new environment.

### Performance Results (PreOS-MicroArch)

**1. 5+ Stage, Set-Associative & Victim Caches**
```
    Number of clk
prog1: 54,882
prog2: 42,492
prog3: 1,196,214
prog4: 33,612,114
```

**2. Super-Scalar, Set-Associative & Victim Caches**
```
    Number of clk | Increase Rate
prog1: 53,081     | 3.3%
prog2: 41,477     | 2.4%
prog3: 999,929    | 16.4%
prog4: 23,827,055 | 29.1%
```

**3. Branch Predictor, Super-Scalar, Set-Associative & Victim Caches**
```
    Number of clk | Increase Rate
prog1: 52,601     | 0.9%
prog2: 41,111     | 0.9%
prog3: 712,499    | 28.7%
prog4: 19,744,985 | 17.1%

    #Branches    | #Mispredictions | Prediction Rate
prog1: 1,450     | 593             | 59.1%
prog2: 976       | 392             | 59.8%
prog3: 223,618   | 6,086           | 97.3%
prog4: 4,879,941 | 782,347         | 84%
```

(prog5 is a small game, so its performance is not included.)
While computational performance improved significantly, memory access latency (~100 clock cycles) remains a limiting factor, resulting in modest overall performance gains.

## Instructions for Building and Running the Simulator

1. **Building/Running Simulator Code**
    ```bash
    make         # Build code
    make run     # Run code
    ```

2. **Generate `trace.vcd` Waveform File**
    - Change `TRACE?=#--trace` to `TRACE?=--trace` in the `Makefile`.
