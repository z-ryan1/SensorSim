//
// Created by alex on 7/15/20.
//

#ifndef SENSORSIM_PROCESSOR_CUH
#define SENSORSIM_PROCESSOR_CUH

#include <unistd.h>
#include <chrono>
#include <assert.h>

#include "../Message.cuh"
#include "../Transport.cuh"

__global__ void gpu_count_zeros(Message* flow, int* sum, int flowLength);
void cpu_count_zeros(Message* flow, int* sum, int flowLength);

class Processor {
public:

    // Constructor declaration
    explicit Processor(Transport *t);

    //pop a message and process if you get one.
    int procPrintMessages(int minMsg);
    int procCountZerosCPU(int minMsg);

    void procCountZerosGPU(int i);

private:
    Transport *transport;


};


#endif //SENSORSIM_PROCESSOR_CUH
