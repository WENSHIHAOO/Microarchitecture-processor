# Microarchitecture-processor
This is a RISC-V 64IM processor. It has Super-Scalar, Set-Associative Caches, Branch predictor, and Victim Caches. This microarchitecture processor uses a fake operating system to simulate the behavior of the infrastructure to forge the system call request.

Hardware design process: Conceptual Design --> Behavioral Implementation --> Evaluation --> Structural Implementation --> Layout --> Manufacturing --> Packaging

Due to cost and time reasons, this project can only be completed: Conceptual Design --> Behavioral Implementation --> Evaluation

## Instructions for the project

1. **Building/Running your simulator code**
    ```bash
    make // build code
    make run // run code
    ```

2. **Change the test case**
    - Find other test cases in `/test` file.
    - Change `PROG=/test/...` in `Makefile`.

3. **Generate 'trace.vcd' waveform file**
    - Delete `//NO TRACE` in `main.cpp`.
    - Restore `VM_TRACE` in `main.cpp`.

## Performance Results

**1. 5+ stage, Set-Associative & Victim Caches**

        Number of clk
    prog1: 54,882
    prog2: 42,492
    prog3: 1,196,214
    prog4: 33,612,114

**2. Super-Scalar, Set-Associative & Victim Caches**

        Number of clk | Increase Rate
    prog1: 53,081     | 3.3%
    prog2: 41,477     | 2.4%
    prog3: 999,929    | 16.4%
    prog4: 23,827,055 | 29.1%

**3. Branch predictor, Super-Scalar, Set-Associative & Victim Caches**

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

Although the processor's computational speed has significantly improved, the need for 100 clock cycles for memory access considerably diminishes the overall performance gains, resulting in a relatively modest improvement in effective performance.
