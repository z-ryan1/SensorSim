//
// Created by alex on 7/15/20.
//

#ifndef SENSORSIM_PROCESSOR_CUH
#define SENSORSIM_PROCESSOR_CUH

#include <unistd.h>
#include <chrono>

#include "../Message.cuh"
#include "../Transport.cuh"

__global__ void gpu_count_zeros();
void cpu_count_zeros();

class Processor {
public:

    // Constructor declaration
    explicit Processor(Transport *t);

    //pop a message and process if you get one.
    int procPrintMessages(int minMsg);
    int procCountZerosCPU(int minMsg);

private:
    Transport *transport;


};


#endif //SENSORSIM_PROCESSOR_CUH
