//
// Created by alex on 8/7/20.
//

#ifndef SENSORSIM_RDMA_UD_TRANSPORT_CUH
#define SENSORSIM_RDMA_UD_TRANSPORT_CUH

#include <netinet/in.h>
#include <string>
#include <vector>

#include </usr/include/infiniband/verbs.h>
#include </usr/include/rdma/rdma_cma.h>

#include "../common.cuh"
#include "../Message.cuh"

#include "itransport.cuh"

#define NUM_OPERATIONS  MSG_BLOCK_SIZE //Set this to same as the block size for other transports.

enum class eTransportRole {SENSOR, PROCESSOR};

class RdmaUdTransport: public ITransport {

public:
    RdmaUdTransport(string localAddr, string mcastAddr, eTransportRole role);
    ~RdmaUdTransport();

private:
    int push(Message* msg);
    int pop(Message msg[MSG_BLOCK_SIZE], int numReqMsg, int& numRetMsg, eTransportDest dest);

    struct rdma_event_channel	*g_CMEventChannel;
    struct rdma_cm_id			*g_CMId;

    struct sockaddr_in6			localAddr_in;
    struct sockaddr_in6			mcastAddr_in;

    //Shared Memory Context
    struct ibv_pd                   *g_pd;                            /* Protection Domain Handle */
    struct ibv_cq                   *g_cq;                            /* Completion Queue Handle */

    // Address Info for the Mutlicast Group
    struct 	ibv_ah 			*AddressHandle;
    uint32_t 				RemoteQpn;
    uint32_t 				RemoteQkey;

    //Shared Memory Regions
    uint8_t                 controlBuffer[MSG_MAX_SIZE];            //Control Messages - Receiver notify sender avail
    ibv_send_wr             controlSendWqe;
    ibv_recv_wr             controlRcvWqe;
    ibv_wc                  controlWc;
    ibv_mr*                 mr_controlBuffer;


    uint8_t                 dataBuffer[MSG_MAX_SIZE];             //Data Path
    ibv_send_wr             dataSendWqe;
    ibv_recv_wr             dataRcvWqe;
    ibv_wc                  dataWc;
    ibv_mr*                 mr_dataBuffer;

    /*
    uint8_t                 rcvBuffer[MSG_BLOCK_SIZE * MSG_MAX_SIZE]; //Used by Processor
    ibv_mr*                 mr_rcvBuffer;
    ibv_wc                  rcvCQEs[MSG_BLOCK_SIZE];
    std::vector<ibv_recv_wr> rcvWQEs;
     */

    int PollCQ(ibv_wc* wc);

    int initSendWqe(ibv_send_wr*, int);
    int updateSendWqe(ibv_send_wr* wqe, void *buffer, size_t bufferlen, ibv_mr *bufferMemoryRegion);

    int initRecvWqe(ibv_recv_wr *wqe, int);
    int updateRecvWqe(ibv_recv_wr* wqe, void *buffer, size_t bufferlen, ibv_mr *bufferMemoryRegion);

    int post_SEND_WQE(ibv_send_wr*);
    int post_RECEIVE_WQE(ibv_recv_wr*);

    ibv_mr *create_MEMORY_REGION(void* , size_t);

    int RDMACreateQP();
    int RDMACreateContext();

    int RdmaMcastConnect();
    int RDMAClientConnect();
    int RDMAServerConnect();

    void DestroyContext();
    void DestroyQP();

    int GetCMEvent(rdma_cm_event_type *EventType);

};

#endif //SENSORSIM_RDMA_UD_TRANSPORT_CUH
