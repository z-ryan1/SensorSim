//
// Created by alex on 8/7/20.
//

#include "rdma_ud_transport.cuh"

#include <cstdio>
#include <algorithm>
#include <arpa/inet.h>
#include <iostream>
#include <sys/types.h>
#include <sys/socket.h>
#include <netdb.h>


int get_addr(const char *dst, struct sockaddr *addr)
{
    struct addrinfo *res;
    int ret;
    ret = getaddrinfo(dst, NULL, NULL, &res);
    if (ret)
    {
        fprintf(stderr,"ERROR: getaddrinfo failed - invalid hostname or IP address\n");
        return -1;
    }
    memcpy(addr, res->ai_addr, res->ai_addrlen);
    freeaddrinfo(res);
    return ret;
}

void PrintCMEvent(struct rdma_cm_event *event)
{
    if(event->event == RDMA_CM_EVENT_ADDR_RESOLVED)
        fprintf(stderr,"DEBUG: Received CM Event(RDMA_CM_EVENT_ADDR_RESOLVED)\n");
    else if(event->event == RDMA_CM_EVENT_ADDR_RESOLVED)
        fprintf(stderr,"DEBUG: Received CM Event(RDMA_CM_EVENT_ADDR_RESOLVED)\n");
    else if(event->event == RDMA_CM_EVENT_ROUTE_RESOLVED)
        fprintf(stderr,"DEBUG: Received CM Event(RDMA_CM_EVENT_ROUTE_RESOLVED)\n");
    else if(event->event == RDMA_CM_EVENT_ROUTE_ERROR)
        fprintf(stderr,"DEBUG: Received CM Event(RDMA_CM_EVENT_ROUTE_ERROR)\n");
    else if(event->event == RDMA_CM_EVENT_CONNECT_REQUEST)
        fprintf(stderr,"DEBUG: Received CM Event(RDMA_CM_EVENT_CONNECT_REQUEST)\n");
    else if(event->event == RDMA_CM_EVENT_CONNECT_RESPONSE)
        fprintf(stderr,"DEBUG: Received CM Event(RDMA_CM_EVENT_CONNECT_RESPONSE)\n");
    else if(event->event == RDMA_CM_EVENT_CONNECT_ERROR)
        fprintf(stderr,"DEBUG: Received CM Event(RDMA_CM_EVENT_CONNECT_ERROR)\n");
    else if(event->event == RDMA_CM_EVENT_UNREACHABLE)
        fprintf(stderr,"DEBUG: Received CM Event(RDMA_CM_EVENT_UNREACHABLE)\n");
    else if(event->event == RDMA_CM_EVENT_REJECTED)
        fprintf(stderr,"DEBUG: Received CM Event(RDMA_CM_EVENT_REJECTED) Status(%u)", event->status );
    else if(event->event == RDMA_CM_EVENT_ESTABLISHED)
        fprintf(stderr,"DEBUG: Received CM Event(RDMA_CM_EVENT_ESTABLISHED)\n");
    else if(event->event == RDMA_CM_EVENT_DISCONNECTED)
        fprintf(stderr,"DEBUG: Received CM Event(RDMA_CM_EVENT_DISCONNECTED)\n");
    else if(event->event == RDMA_CM_EVENT_DEVICE_REMOVAL)
        fprintf(stderr,"DEBUG: Received CM Event(RDMA_CM_EVENT_DEVICE_REMOVAL)\n");
    else if(event->event == RDMA_CM_EVENT_MULTICAST_JOIN)
        fprintf(stderr,"DEBUG: Received CM Event(RDMA_CM_EVENT_MULTICAST_JOIN)\n");
    else if(event->event == RDMA_CM_EVENT_MULTICAST_ERROR)
        fprintf(stderr,"DEBUG: Received CM Event(RDMA_CM_EVENT_MULTICAST_ERROR)\n");
    else if(event->event == RDMA_CM_EVENT_ADDR_CHANGE)
        fprintf(stderr,"DEBUG: Received CM Event(RDMA_CM_EVENT_ADDR_CHANGE)\n");
    else if(event->event == RDMA_CM_EVENT_TIMEWAIT_EXIT)
        fprintf(stderr,"DEBUG: Received CM Event(RDMA_CM_EVENT_TIMEWAIT_EXIT)\n");
    return;
}

void PrintConnectionInfo(rdma_conn_param cParam)
{
    fprintf(stderr, "DEBUG: QPN(%d)\n", cParam.qp_num);
}

RdmaUdTransport::RdmaUdTransport(string localAddr, string mcastAddr, eTransportRole role) {

    ibv_wc wc;
    s_localAddr = localAddr;
    s_mcastAddr = mcastAddr;

    // Creating socket file descriptor
    if(RDMACreateContext() != 0)
    {
        cerr << "Failed Create the RDMA Channel." << endl;
        exit(EXIT_FAILURE);
    }

    if(role == eTransportRole::SENSOR) { //Sensor

        if(RDMACreateQP() != 0)
        {
            //TODO: We should be able to start the processes in any order. Need things to wait and retry.
            fprintf(stdout, "Exiting - Failed to Create Queue Pair, make sure processor is running\n");
            exit(EXIT_FAILURE);
        }

    } else { //Processor

        if(RDMACreateQP() != 0)
        {
            fprintf(stderr, "Exiting - Failed to establish connection with the client\n");
            exit(EXIT_FAILURE);
        }

    }

    if(RdmaMcastConnect() != 0)
    {
        fprintf(stdout, "Exiting - Failed to establish connection to MultiCast Group\n");
        exit(EXIT_FAILURE);
    }

    //Initialize the Data Channel
    mr_dataBuffer = create_MEMORY_REGION(&dataBuffer, MSG_MAX_SIZE);
    memset(dataBuffer, 0x00, MSG_MAX_SIZE);
    initSendWqe(&dataSendWqe, 0);
    updateSendWqe(&dataSendWqe, &dataBuffer, MSG_MAX_SIZE, mr_dataBuffer);
    initRecvWqe(&dataRcvWqe, 0);
    updateRecvWqe(&dataRcvWqe, &dataBuffer, MSG_MAX_SIZE, mr_dataBuffer);

    //Register the control plane memory region
    mr_controlBuffer = create_MEMORY_REGION(&controlBuffer, MSG_MAX_SIZE);
    memset(controlBuffer, 0x00, MSG_MAX_SIZE);
    initSendWqe(&controlSendWqe, 0);
    updateSendWqe(&controlSendWqe, &controlBuffer, MSG_MAX_SIZE, mr_controlBuffer);
    initRecvWqe(&controlRcvWqe, 0);
    updateRecvWqe(&controlRcvWqe, &controlBuffer, MSG_MAX_SIZE, mr_controlBuffer);

}

RdmaUdTransport::~RdmaUdTransport() {
    //Clean the RDMA Contexts
    DestroyContext();
    DestroyQP();

    //REmove the Shared MEmory
    delete mr_controlBuffer;
}

int RdmaUdTransport::push(Message* m)
{
    //usleep(200); //TODO: Take this out
    //cerr << "NO PUSH OP" << endl;

    ibv_mr* mr_msg = create_MEMORY_REGION(&m->buffer, m->bufferSize);

    initSendWqe(&dataSendWqe, 42);
    updateSendWqe(&dataSendWqe, &(m->buffer), m->bufferSize, mr_msg);

      post_SEND_WQE(&dataSendWqe);

       DEBUG("DEBUG: Sent Message:\n");
      #ifdef DEBUG_BUILD
          m->printBuffer(32);
      #endif

      //Wait For Completion
      int ret = 0;

      DEBUG("DEBUG: Waiting for CQE\n");
      do {
          ret = ibv_poll_cq(g_cq, 1, &dataWc);
      } while(ret == 0);
      DEBUG("DEBUG: Received " << ret << " CQE Elements\n");
      DEBUG("DEBUG: WRID(" << dataWc.wr_id << ")\tStatus(" << dataWc.status << ")\n");

      if(dataWc.status == IBV_WC_RNR_RETRY_EXC_ERR)
      {
          usleep(50); //wait 50 us and we will try again.
          cerr << "DEBUG: WRID(" << dataWc.wr_id << ")\tStatus(IBV_WC_RNR_RETRY_EXC_ERR)" << endl;
          ibv_dereg_mr(mr_msg);
          return -1;
      }
      if(dataWc.status != IBV_WC_SUCCESS)
      {
          cerr << "DEBUG: WRID(" << dataWc.wr_id << ")\tStatus(" << dataWc.status << ")" << endl;
          ibv_dereg_mr(mr_msg);
          return -1;
      }

    ibv_dereg_mr(mr_msg);



    return 0;
}

/*
*  Pulls messages from the transport and places it in the buffer
*/
int RdmaUdTransport::pop(Message* m, int numReqMsg, int& numRetMsg, eTransportDest dest)
{
    numRetMsg = 0;

    do {

        //Post the RcvWQE
        post_RECEIVE_WQE(&dataRcvWqe);

        int r = 0;
        DEBUG("DEBUG: Waiting for CQE\n");
        do {
            r = ibv_poll_cq(g_cq, 1, &dataWc);
        } while (r == 0);
        DEBUG("DEBUG: Received " << r << " CQE Elements\n");

        numRetMsg += r;

        for (int j = 0; j < r; j++) {
            DEBUG ("test");
            DEBUG("DEBUG: WRID(" << dataWc.wr_id <<
                                 ")\tStatus(" << dataWc.status << ")" <<
                                 ")\tSize(" << dataWc.byte_len << ")\n");
        }

        m[numRetMsg-1] = Message(numRetMsg-1, 0, dataWc.byte_len, dataBuffer); //we can reuse the buffer now.
        //TODO: Choose to create message buffer in GPU vs CPU Memory.

        DEBUG ("DEBUG: Received Message:\n");
        #ifdef DEBUG_BUILD
        m[numRetMsg-1].printBuffer(32);
        #endif

    } while(numRetMsg < numReqMsg);

    return 0;
}

/*
 * Returns -1 for error otherwise return Number of Completions Received
 */
int RdmaUdTransport::PollCQ(ibv_wc* wc)
{
    int ret = 0;

    DEBUG("DEBUG: Waiting for CQE\n");
    do {
        ret = ibv_poll_cq(g_cq, 1, wc);
    } while(ret == 0);
    DEBUG("DEBUG: Received " << ret << " CQE Elements\n");
    DEBUG("DEBUG: WRID(" << wc->wr_id << ")\tStatus(" << wc->status << ")\n");
    return ret;
}

int RdmaUdTransport::initSendWqe(ibv_send_wr* wqe, int i)
{
    struct ibv_sge *sge;

    //wqe = (ibv_send_wr *)malloc(sizeof(ibv_send_wr));
    sge = (ibv_sge *)malloc(sizeof(ibv_sge));

    //memset(wqe, 0, sizeof(ibv_send_wr));
    memset(sge, 0, sizeof(ibv_sge));

    wqe->wr_id = i;
    wqe->opcode = IBV_WR_SEND;
    wqe->sg_list = sge;
    wqe->num_sge = 1;
    wqe->send_flags = IBV_SEND_SIGNALED;

    wqe->wr.ud.ah = AddressHandle;
    wqe->wr.ud.remote_qpn = RemoteQpn;
    wqe->wr.ud.remote_qkey = RemoteQkey;

    return 0;
}

int RdmaUdTransport::updateSendWqe(ibv_send_wr* wqe, void* buffer, size_t bufferlen, ibv_mr* bufferMemoryRegion)
{
    wqe->sg_list->addr = (uintptr_t)buffer;
    wqe->sg_list->length = bufferlen;
    wqe->sg_list->lkey = bufferMemoryRegion->lkey;
    return 0;
}

int RdmaUdTransport::initRecvWqe(ibv_recv_wr* wqe, int id)
{
    struct ibv_sge *sge;

    sge = (ibv_sge *)malloc(sizeof(ibv_sge));

    memset(sge, 0, sizeof(ibv_sge));

    wqe->wr_id = id;
    wqe->next = NULL;
    wqe->sg_list = sge;
    wqe->num_sge = 1;

    return 0;
}

int RdmaUdTransport::updateRecvWqe(ibv_recv_wr *wqe, void *buffer, size_t bufferlen, ibv_mr *bufferMemoryRegion) {

    wqe->sg_list->addr = (uintptr_t)buffer;
    wqe->sg_list->length = bufferlen;
    wqe->sg_list->lkey = bufferMemoryRegion->lkey;
    return 0;
}

int RdmaUdTransport::post_SEND_WQE(ibv_send_wr* ll_wqe)
{
    int err;
    int ret = 0;
    struct ibv_send_wr *bad_wqe = NULL;

    err = ibv_post_send(g_CMId->qp, ll_wqe, &bad_wqe);
    while(err != 0)
    {
        fprintf(stderr,"ERROR: post_SEND_WQE Error %u\n", err);
        if(err == ENOMEM && ret++ < 10) //Queue Full Wait for CQ Polling Thread to Clear
        {
            fprintf(stderr,"ERROR: Send Queue Full Retry %u of 10\n", ret);
            usleep(100); //Wait 100 Microseconds, max of 1 msec
        }
        else
        {
            fprintf(stderr, "ERROR: Unrecoverable Send Queue, aborting\n");
            return -1;
        }
    }

    return 0;
}

int RdmaUdTransport::post_RECEIVE_WQE(ibv_recv_wr* ll_wqe)
{
    DEBUG("DEBUG: Enter post_RECEIVE_WQE\n");
    int ret = 0;
    struct ibv_recv_wr *bad_wqe = NULL;

    ret = ibv_post_recv(g_CMId->qp, ll_wqe, &bad_wqe);
    if(ret != 0)
    {
        fprintf(stderr, "ERROR: post_RECEIVE_WQE - Couldn't Post Receive WQE\n");
        return -1;
    }

    DEBUG("DEBUG: Exit post_RECEIVE_WQE\n");
    return 0;
}

ibv_mr* RdmaUdTransport::create_MEMORY_REGION(void* buffer, size_t bufferlen)
{
    ibv_mr* tmpmr = (ibv_mr*)malloc(sizeof(ibv_mr));
    //int mr_flags = IBV_ACCESS_LOCAL_WRITE | IBV_ACCESS_REMOTE_READ | IBV_ACCESS_REMOTE_WRITE;
    int mr_flags = IBV_ACCESS_LOCAL_WRITE;
    tmpmr = ibv_reg_mr(g_pd, buffer, bufferlen, mr_flags);
    if(!tmpmr)
    {
        fprintf(stderr, "ERROR: create_MEMORY_REGION: Couldn't Register memory region\n");
        return NULL;
    }

#ifdef DEBUG_BUILD
    fprintf(stderr, "DEBUG: Memory Region was registered with addr=%p, lkey=0x%x, rkey=0x%x, flags=0x%x\n",
            buffer, tmpmr->lkey, tmpmr->rkey, mr_flags);
#endif

    return tmpmr;
}

int RdmaUdTransport::GetCMEvent(rdma_cm_event_type* EventType)
{
    int ret;
    struct rdma_cm_event *CMEvent;

    ret = rdma_get_cm_event(g_CMEventChannel, & CMEvent);
    if(ret != 0)
    {
        fprintf(stderr,"ERROR: No CM Event Received in Time Out\n");
        return -1;
    }
    *EventType = CMEvent->event;
    PrintCMEvent(CMEvent);

    /*
     * Release the Event now that we are done with it
     */
    ret=rdma_ack_cm_event(CMEvent);
    if(ret != 0)
    {
        fprintf(stderr,"ERROR: CM couldn't release CM Event\n");
        return -1;
    }

    return 0;

}

/*
 * Create the CM Event Channel, the Connection Identifier, Bind the application to a local address
 */
int RdmaUdTransport::RDMACreateContext()
{
    int ret = 0;
    struct rdma_cm_event *CMEvent;

    // Open a Channel to the Communication Manager used to receive async events from the CM.
    g_CMEventChannel = rdma_create_event_channel();
    if(!g_CMEventChannel)
    {
        fprintf(stderr,"ERROR - RDMACreateContext: Failed to Create CM Event Channel");
        DestroyContext();
        return -1;
    }

    ret = rdma_create_id(g_CMEventChannel, &g_CMId, NULL, RDMA_PS_UDP);
    if(ret != 0)
    {
        fprintf(stderr,"ERROR - RDMACreateContext: Failed to Create CM ID");
        DestroyContext();
        return -1;
    }

    if(get_addr(s_localAddr.c_str(), (struct sockaddr*)&localAddr_in) != 0)
    {
        fprintf(stderr, "ERROR - RDMACreateContext: Failed to Resolve Local Address\n");
        DestroyContext();
        return -1;
    }

    if(get_addr(s_mcastAddr.c_str(), (struct sockaddr*)&mcastAddr_in) != 0)
    {
        fprintf(stderr, "ERROR - RDMACreateContext: Failed to Resolve Multicast Address Address\n");
        DestroyContext();
        return -1;
    }

    ret = rdma_bind_addr(g_CMId, (struct sockaddr*)&localAddr_in);
    if(ret != 0 )
    {
        fprintf(stderr, "ERROR - RDMACreateContext: Couldn't bind to local address\n");
        fprintf(stderr, "ERROR - errno %s\n", strerror(errno));
        return -1;
    }

    ret = rdma_resolve_addr(g_CMId,
                            (struct sockaddr*)&localAddr_in,
                            (struct sockaddr*)&mcastAddr_in,
                            2000);
    if(ret != 0 )
    {
        fprintf(stderr, "ERROR - RDMACreateContext: Couldn't resolve local address and or mcast address.\n");
        fprintf(stderr, "ERROR - errno %s\n", strerror(errno));
        return -1;
    }

    ret = rdma_get_cm_event(g_CMEventChannel, &CMEvent);
    if(ret != 0)
    {
        fprintf(stderr, "ERROR - RDMACreateContext: No Event Received Time Out\n");
        return -1;
    }
    if(CMEvent->event != RDMA_CM_EVENT_ADDR_RESOLVED)
    {
        fprintf(stderr, "ERROR - RDMACreateContext: Expected Multicast Joint Event\n");
        return -1;
    }


    return 0;
}

int RdmaUdTransport::RDMACreateQP()
{
    int ret;
    struct ibv_qp_init_attr qp_init_attr;

    //g_CMId->qp_type = IBV_QPT_UD;
    //g_CMId->ps = RDMA_PS_UDP;

    //Create a Protection Domain
    g_pd = ibv_alloc_pd(g_CMId->verbs);
    if(!g_pd)
    {
        fprintf(stderr,"ERROR: - RDMACreateQP: Couldn't allocate protection domain\n");
        fprintf(stderr, "ERROR - errno %s\n", strerror(errno));
        return -1;
    }

    /*Create a completion Queue */
    //g_cq = ibv_create_cq(g_CMId->verbs, NUM_OPERATIONS, NULL, NULL, 0);
    g_cq = ibv_create_cq(g_CMId->verbs, 5, NULL, NULL, 1);
    if(!g_cq)
    {
        fprintf(stderr, "ERROR: RDMACreateQP - Couldn't create completion queue\n");
        fprintf(stderr, "ERROR - errno %s\n", strerror(errno));
        return -1;
    }

    /* create the Queue Pair */
    memset(&qp_init_attr, 0, sizeof(qp_init_attr));

    qp_init_attr.qp_type = IBV_QPT_UD;
    //qp_init_attr.sq_sig_all = 0;
    qp_init_attr.send_cq = g_cq;
    qp_init_attr.recv_cq = g_cq;
    qp_init_attr.cap.max_send_wr = NUM_OPERATIONS;
    qp_init_attr.cap.max_recv_wr = NUM_OPERATIONS;
    qp_init_attr.cap.max_send_sge = 1;
    qp_init_attr.cap.max_recv_sge = 1;

    ret = rdma_create_qp(g_CMId, g_pd, &qp_init_attr);
    if(ret != 0)
    {
        fprintf(stderr, "ERROR: RDMACreateQP: Couldn't Create Queue Pair Error\n");
        fprintf(stderr, "ERROR - errno %s\n", strerror(errno));
        return -1;
    }
    return 0;
}

int RdmaUdTransport::RdmaMcastConnect()
{
    int ret = 0;
    struct rdma_cm_event *CMEvent;

    ret = rdma_join_multicast(g_CMId, (struct sockaddr*)&mcastAddr_in, NULL);
    if(ret)
    {
        fprintf(stderr, "RDMA multicast join Failed\n");
        fprintf(stderr, "ERROR - errno %s\n", strerror(errno));
        return -1;
    }

    ret = rdma_get_cm_event(g_CMEventChannel, &CMEvent);
    if(ret != 0)
    {
        fprintf(stderr, "ERROR: No Event Received Time Out\n");
        fprintf(stderr, "ERROR - errno %s\n", strerror(errno));
        return -1;
    }
    if(CMEvent->event == RDMA_CM_EVENT_MULTICAST_JOIN)
    {
        rdma_ud_param *param;
        param = &CMEvent->param.ud;

        RemoteQpn = param->qp_num;
        RemoteQkey = param->qkey;
        AddressHandle = ibv_create_ah(g_pd, &param->ah_attr);
        if (!AddressHandle)
        {
            fprintf(stderr, "ERROR OnMulticastJoin - Failed to create the Address Handle\n");
            return -1;
        }
        fprintf(stderr, "Joined Multicast Group QPN(%d) QKey(%d)\n", RemoteQpn, RemoteQkey);
    } else {

        fprintf(stderr, "Expected Multicast Joint Event\n");
        return -1;
    }



    return 0;
}

int RdmaUdTransport::RDMAClientConnect()
{
    int ret;
    rdma_cm_event_type et;

    //rdma resolve route
    ret = rdma_resolve_route(g_CMId, 2000);
    if(ret != 0)
    {
        fprintf(stderr, "ERROR: RDMAClientConnect: Couldn't resolve the Route\n");
        return -1;
    }

    fprintf(stderr, "DEBUG: Waiting for Resolve Route CM Event ...\n");
    do
    {
        ret = GetCMEvent(&et);
        if(ret != 0)
        {
            fprintf(stderr, "ERROR: Processing CM Events\n");
        }
    } while(et != RDMA_CM_EVENT_ROUTE_RESOLVED);

    fprintf(stderr, "DEBUG: Waiting for Connection Established Event ...\n");

    struct rdma_conn_param ConnectionParams;

    memset(&ConnectionParams, 0, sizeof(ConnectionParams));
    ret = rdma_connect(g_CMId, &ConnectionParams);
    if(ret != 0)
    {
        fprintf(stderr, "ERROR: Client Couldn't Establish Connection\n");
        return -1;
    }

    PrintConnectionInfo(ConnectionParams);

    do
    {
        ret = GetCMEvent(&et);
        if(ret != 0)
        {
            fprintf(stderr, "ERROR: Processing CM Events\n");
        }
    } while(et != RDMA_CM_EVENT_ESTABLISHED);



    return 0;
}

int RdmaUdTransport::RDMAServerConnect()
{
    int ret;
    struct rdma_cm_event *CMEvent;
    rdma_cm_event_type et;

    /*
     * Wait for the Connect REquest to Come From the Client
     */
    do
    {
        ret = rdma_get_cm_event(g_CMEventChannel, & CMEvent);
        if(ret != 0)
        {
            fprintf(stderr, "ERROR: No Event Received Time Out\n");
            return -1;
        }

        PrintCMEvent(CMEvent);
    } while(CMEvent->event != RDMA_CM_EVENT_CONNECT_REQUEST);

    /*
     * Get the CM Id from the Event
     */

    g_CMId = CMEvent->id;
    /*
     * Now we can create the QP
     */
    ret = RDMACreateQP();
    if(ret != 0)
    {
        fprintf(stderr, "ERROR: RDMAServerConnect - Couldn't Create QP\n");
        return -1;
    }

    struct rdma_conn_param ConnectionParams;
    memset(&ConnectionParams, 0, sizeof(ConnectionParams));
    ret = rdma_accept(g_CMId, &ConnectionParams);
    if(ret != 0)
    {
        fprintf(stderr, "ERROR: Client Couldn't Establish Connection\n");
        return -1;
    }

    PrintConnectionInfo(ConnectionParams);

    /*
     * Release the Event now that we are done with it
     */
    ret=rdma_ack_cm_event(CMEvent);
    if(ret != 0)
    {
        fprintf(stderr, "ERROR: couldn't release CM Event\n");
        return -1;
    }

    fprintf(stderr, "DEBUG: Waiting for Connection Established Event ...\n");
    do
    {
        ret = GetCMEvent(&et);
        if(ret != 0)
        {
            fprintf(stderr, "ERROR: Processing CM Events\n");
        }
    } while(et != RDMA_CM_EVENT_ESTABLISHED);

    return 0;
}

void RdmaUdTransport::DestroyContext()
{
    if(g_CMEventChannel != NULL)
    {
        rdma_destroy_event_channel(g_CMEventChannel);
    }

    if(g_CMId != NULL)
    {
        if(rdma_destroy_id(g_CMId) != 0)
        {
            fprintf(stderr, "ERROR: DestroyContext - Failed to destroy Connection Manager Id\n");
        }
    }
}

void RdmaUdTransport::DestroyQP()
{
    if(g_pd != NULL)
    {
        if(ibv_dealloc_pd(g_pd) != 0)
        {
            fprintf(stderr, "ERROR: DestroyQP - Failed to destroy Protection Domain\n");
        }
    }

    if(g_cq != NULL)
    {
        ibv_destroy_cq(g_cq);
        {
            fprintf(stderr, "ERROR: DestroyQP - Failed to destroy Completion Queue\n");
        }
    }

    rdma_destroy_qp(g_CMId);

}


