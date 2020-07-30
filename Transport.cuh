//
// Created by alex on 7/16/20.
//

#ifndef SENSORSIM_TRANSPORT_CUH
#define SENSORSIM_TRANSPORT_CUH

#include <netinet/in.h>
#include <string>
#include <vector>

#include "common.cuh"
#include "Message.cuh"

using namespace std;

class Transport {
public:
    Transport(string srcAddr, int srcPort, string dstAddr, int dstPort);

    int push(Message* msg);
    int pop(Message msg[MSG_BLOCK_SIZE], int numReqMsg, int& numRetMsg);
    //int pop(vector<Message>& msg, int numReqMsg, int& numRetMsg);


private:
    string                      s_dstAddr;
    int 						n_dstPort;
    string                      s_srcAddr;
    int 						n_srcPort;

    struct sockaddr_in			g_srcAddr;
    struct sockaddr_in			g_dstAddr;

    int sockfd;
};


#endif //SENSORSIM_TRANSPORT_CUH
