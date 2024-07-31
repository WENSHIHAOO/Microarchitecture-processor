# Microarchitecture-processor
This is a RISC-V 64IM processor. It has Super-Scalar, Set-Associative Caches, Branch predictor, and Victim Caches. This microarchitecture processor uses a fake operating system to simulate the behavior of the infrastructure to forge the system call request.

Hardware design process: Conceptual Design --> Behavioral Implementation --> Evaluation --> Structural Implementation --> Layout --> Manufacturing --> Packaging

Due to cost and time reasons, this project can only be completed: Conceptual Design --> Behavioral Implementation --> Evaluation

--------------------------------------------------------------------------
Some instructions for the project

1. Building/Running your simulator code

> make // build code
> make run // run code

2. Change the test case

i.  Find other test cases in /test file
ii. Change PROG=/test/... in Makefile

3. If you want to generate 'trace.vcd' waveform file, You can view it using 'gtkwave'

i.  Delete //NO TRACE in main.cpp.
ii. Restore VM_TRACE in main.cpp.

--------------------------------------------------------------------------
Here are the performance results (expressed in clock cycles (clk)) of running the test cases at different stages of the project:

1. 5+ stage, Set-Associative & Victim Caches
    Number of clk
prog1: 54882
prog2: 42492
prog3: 1196214
prog4: 33612114

2. Super-Scalar, Set-Associative & Victim Caches
    Number of clk |  Increase Rate
prog1: 53081      |  3.3%
prog2: 41477      |  2.4%
prog3: 999929     |  16.4%
prog4: 23827055   |  29.1%

3. Branch predictor, Super-Scalar, Set-Associative & Victim Caches
    Number of clk |  Increase Rate
prog1: 52601      |  0.9%
prog2: 41111      |  0.9%
prog3: 712499     |  28.7%
prog4: 19744985   |  17.1%

       #Branches  |  #Mispredictions |  Prediction Rate
prog1: 1450       |  593             |  59.1%
prog2: 976        |  392             |  59.8%
prog3: 223618     |  6086            |  97.3%
prog4: 4879941    |  782347          |  84%

In fact, the processor's computing speed has increased a lot. But it takes 100 clock cycles to access the memory, which greatly reduces the effective performance improvement, making the actual performance improvement particularly low.
