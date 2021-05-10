# CSCI5573Final/config.jl
# Licensed under the MIT License. See LICENSE.md file in the project root for
# full license information.

RUN_NAME="SimulationResults"
MAX_TASKS=40
N_BUSSES = 10 # Number of communication buffers
CLOCK_CYCLE = 1
QUANTUM = -1 # -1 is "until done"
COMM_TIMEOUT = 100
COMM_INTERRUPT_CYCLES = 10 # How many clock cycles to handle IO queueing
PROCESSOR_POWERS = [
    1.0,
    0.5,
    0.4,
    0.3,
    0.2,
]
