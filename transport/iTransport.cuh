//
// Created by alex on 8/7/20.
//

#ifndef SENSORSIM_ITRANSPORT_CUH
#define SENSORSIM_ITRANSPORT_CUH

#include <netinet/in.h>

enum class eTransportDest {HOST, DEVICE};
enum class eTransportType {UDP, RDMA_UD};

class iTransport {

public:


    virtual int push(Message* msg) = 0;
    virtual int pop(Message msg[MSG_BLOCK_SIZE], int numReqMsg, int& numRetMsg, eTransportDest dest ) = 0;

    eTransportType getType()
    {
        return transportType;
    }

    string printType() {
        if(transportType == eTransportType::UDP)
            return "UDP";
        else
            return "RDMA-UD";
    }

protected:
    string                      s_dstAddr;
    int 						n_dstPort;
    string                      s_srcAddr;
    int 						n_srcPort;

    struct sockaddr_in			g_srcAddr;
    struct sockaddr_in			g_dstAddr;

    int sockfd;

    eTransportType              transportType;
};


#endif //SENSORSIM_ITRANSPORT_CUH
