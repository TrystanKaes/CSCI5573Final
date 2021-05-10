# CSCI5573Final/config.jl
# Licensed under the MIT License. See LICENSE.md file in the project root for
# full license information.

SIM_RUN="SimulationResults"
MAX_TASKS=300
N_BUSSES = 10 # Number of communication buffers
CLOCK_CYCLE = 1
COMM_TIMEOUT = 100
COMM_INTERRUPT_CYCLES = 10 # How many clock cycles to handle IO queueing
PROCESSOR_POWERS = [
    0.51,
    0.5,
    0.49,
    0.3
]
