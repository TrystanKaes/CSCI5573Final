# CSCI5573Final/config.jl
# Licensed under the MIT License. See LICENSE.md file in the project root for
# full license information.

SIM_RUN = "FCFS"

macro pick_scheduler(NAME)
    quote
        @schedule at 0 $(esc(Symbol(NAME * "Scheduler()")))
    end
end

TRIALS                = 1
N_BUSSES              = 10
MAX_TASKS             = 250
CLOCK_CYCLE           = 1
COMM_TIMEOUT          = 100
COMM_INTERRUPT_CYCLES = 10

PROCESSOR_POWERS = [
    0.51,
    0.5,
    0.49,
    # 0.3
]

DAGS = [
    "1fat0.3100.dag",
    # "2fat0.3100.dag",
    # "3fat0.3100.dag",
    # "4fat0.3100.dag",
    # "5fat0.3100.dag",
    # "1fat0.9100.dag",
    # "2fat0.9100.dag",
    # "3fat0.9100.dag",
    # "4fat0.9100.dag",
    # "5fat0.9100.dag",
    # "1300.dag",
    # "2300.dag",
    # "3300.dag",
    # "4300.dag",
    # "5300.dag",
    # "6300.dag",
]
