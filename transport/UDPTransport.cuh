//
// Created by alex on 7/16/20.
//

#ifndef SENSORSIM_UDPTRANSPORT_CUH
#define SENSORSIM_UDPTRANSPORT_CUH

#include <netinet/in.h>
#include <string>
#include <vector>

#include "../common.cuh"
#include "../Message.cuh"
#include "iTransport.cuh"

using namespace std;

class UDPTransport: public iTransport {

public:
    UDPTransport(string srcAddr, int srcPort, string dstAddr, int dstPort);

private:
    int push(Message* msg);
    int pop(Message msg[MSG_BLOCK_SIZE], int numReqMsg, int& numRetMsg, eTransportDest dest);
};


#endif //SENSORSIM_UDPTRANSPORT_CUH
