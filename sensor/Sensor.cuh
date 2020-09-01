//
// Created by alex on 7/15/20.
//

#ifndef SENSORSIM_SENSOR_CUH
#define SENSORSIM_SENSOR_CUH

#include <vector>
#include <iostream>
#include <pcap.h>

#include "../common.cuh"
#include "../transport/itransport.cuh"

class Sensor {
public:
    Sensor(ITransport* t); // Constructor declaration


    //Flow Creation Functions
    int createRandomFlow(int msgLength, int numMsg);
    int createPCAPFlow(std::string fileName);

    int getFlowLength();

    //Flow display
    void printFlow();
    int sendFlow();

private:
    std::vector<Message*> flow;
    ITransport* transport;

};


#endif //SENSORSIM_SENSOR_CUH
