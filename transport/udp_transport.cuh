//
// Created by alex on 7/16/20.
//

#ifndef SENSORSIM_UDP_TRANSPORT_CUH
#define SENSORSIM_UDP_TRANSPORT_CUH

#include <netinet/in.h>
#include <string>
#include <vector>

#include "../common.cuh"
#include "../Message.cuh"
#include "itransport.cuh"

using namespace std;

class UpdTransport: public ITransport {

public:
    UpdTransport(string srcAddr, int srcPort, string dstAddr, int dstPort);

private:
    int push(Message* msg);
    int pop(Message msg[MSG_BLOCK_SIZE], int numReqMsg, int& numRetMsg, eTransportDest dest);
};


#endif //SENSORSIM_UDP_TRANSPORT_CUH
