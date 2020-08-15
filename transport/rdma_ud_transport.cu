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
    {
        fprintf(stderr,"DEBUG: Received CM Event(RDMA_CM_EVENT_REJECTED)\n");
        fprintf(stderr,"DEBUG: Status(%u)", event->status);
    }
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


RdmaUdTransport::RdmaUdTransport(string srcAddr, int srcPort, string dstAddr, int dstPort, eTransportRole role) {

    s_srcAddr = srcAddr;
    n_srcPort = srcPort;
    s_dstAddr = dstAddr;
    n_dstPort = dstPort;

    // Creating socket file descriptor
    if(RDMACreateChannel() != 0)
    {
        cerr << "Failed Create the RDMA Channel." << endl;
        exit(EXIT_FAILURE);
    }

    if(role == eTransportRole::SENSOR) { //Sensor
        if (RDMAClientInit() != 0) {
            fprintf(stdout, "Exiting - Failed to initialize the Client Side CM Connection.\n");
            exit(EXIT_FAILURE);
        }

        if(RDMACreateQP() != 0)
        {
            //TODO: We should be able to start the processes in any order. Need things to wait and retry.
            fprintf(stdout, "Exiting - Failed to Create Queue Pair, make sure processor is running\n");
            exit(EXIT_FAILURE);
        }

        if(RDMAClientConnect() != 0)
        {
            fprintf(stdout, "Exiting - Failed to establish connection to client\n");
            exit(EXIT_FAILURE);
        }

        /*
        //Initialize the wqe's used for send
        sendWQEs.resize(MSG_BLOCK_SIZE);
        int i = 0; //wr id
        std::for_each(begin(sendWQEs), end(sendWQEs), [&] (ibv_send_wr &wqe) {
           initSendWqe(&wqe, i++);
        });
        */

        //Register the control plane memory region
        mr_controlBuffer = create_MEMORY_REGION(&controlBuffer, MSG_MAX_SIZE);
        memset(controlBuffer, 0xFF, MSG_MAX_SIZE);

        initSendWqe(&controlSendWqe, 0);
        updateSendWqe(&controlSendWqe, &controlBuffer, MSG_MAX_SIZE, mr_controlBuffer);

        sleep(1); //Wait 1 Second or I get a Completion Error TODO: Fix This CP Error

        post_SEND_WQE(&controlSendWqe);
        cout << "Sending first control message" << endl;

        //Wait For Completion
        ibv_wc wc;
        PollCQ(&wc);

    } else { //Processor
        if (RDMAServerInit() != 0) {
            fprintf(stdout, "Exiting - Failed to initialize the Server Side CM Connection.\n");
            exit(EXIT_FAILURE);
        }

        if(RDMAServerConnect() != 0)
        {
            fprintf(stderr, "Exiting - Failed to establish connection with the client\n");
            exit(EXIT_FAILURE);
        }

        /*
        //Register the rcvBuffer memory region
        mr_rcvBuffer = create_MEMORY_REGION(&rcvBuffer, MSG_MAX_SIZE * MSG_BLOCK_SIZE);
        memset(rcvBuffer, 0x00, MSG_MAX_SIZE * MSG_BLOCK_SIZE);

        //Initialize the wqe's used for receiving and point to the MR
        rcvWQEs.resize(MSG_BLOCK_SIZE);
        int i = 0;
        std::for_each(begin(rcvWQEs), end(rcvWQEs), [&] (ibv_recv_wr &wqe) {
            initRecvWqe(&wqe, i);
            //updateRecvWqe(&wqe, &rcvBuffer[i*MSG_MAX_SIZE], MSG_MAX_SIZE, mr_rcvBuffer);
            updateRecvWqe(&wqe, &rcvBuffer[0], MSG_MAX_SIZE * MSG_BLOCK_SIZE, mr_rcvBuffer);
            if(i < rcvWQEs.size()-1) { wqe.next = &rcvWQEs[i+1];} //connect the WQES so we can post at once.
            i++;
        });
         */

        //Register the control plane memory region
        mr_controlBuffer = create_MEMORY_REGION(&controlBuffer, MSG_MAX_SIZE);
        memset(controlBuffer, 0x00, MSG_MAX_SIZE);

        initRecvWqe(&controlRcvWqe, 0);
        updateRecvWqe(&controlRcvWqe, &controlBuffer, MSG_MAX_SIZE, mr_controlBuffer);

        //Post the Receive WQE
        post_RECEIVE_WQE(&controlRcvWqe);
        cout << "Waiting for first control message" << endl;
        //Wait For Completion - Print the Initial Message
        ibv_wc wc;
        PollCQ(&wc);


        Message* m = new Message(1, 0, MSG_MAX_SIZE, controlBuffer);
        cout << "Established Connection with Sensor printing control message expect all 0xFF" << endl;
        m->printBuffer(32);

    }



}

RdmaUdTransport::~RdmaUdTransport() {
    //Clean the RDMA Contexts
    CleanUpCMContext();
    CleanUpQPContext();

    //REmove the Shared MEmory
    delete mr_controlBuffer;
}

int RdmaUdTransport::push(Message* m)
{
    DEBUG("Sent a Msg: " << *m << endl);

    ibv_mr* mr_msg = create_MEMORY_REGION(&m->buffer, m->bufferSize);
    initSendWqe(&controlSendWqe, 42);
    updateSendWqe(&controlSendWqe, &(m->buffer), m->bufferSize, mr_msg);
    post_SEND_WQE(&controlSendWqe);

    DEBUG("DEBUG: Sent Message:\n");
    #ifdef DEBUG_BUILD
        m->printBuffer(32);
    #endif

    //Wait For Completion
    ibv_wc wc;
    int ret = 0;

    DEBUG("DEBUG: Waiting for CQE\n");
    do {
        ret = ibv_poll_cq(g_cq, 1, &wc);
    } while(ret == 0);
    DEBUG("DEBUG: Received " << ret << " CQE Elements\n");
    DEBUG("DEBUG: WRID(" << wc->wr_id << ")\tStatus(" << wc->status << ")\n");

    if(wc.status == IBV_WC_RNR_RETRY_EXC_ERR)
    {
        usleep(50); //wait 50 us and we will try again.
        cerr << "DEBUG: WRID(" << wc.wr_id << ")\tStatus(IBV_WC_RNR_RETRY_EXC_ERR)" << endl;
        return -1;
    }
    if(wc.status != IBV_WC_SUCCESS)
    {
        cerr << "DEBUG: WRID(" << wc.wr_id << ")\tStatus(" << wc.status << ")" << endl;
        return -1;
    }

   usleep(1000); //wait 50 us and we will try again.

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
        post_RECEIVE_WQE(&controlRcvWqe);

        int r = 0;
        DEBUG("DEBUG: Waiting for CQE\n");
        do {
            r = ibv_poll_cq(g_cq, 1, &controlWc);
        } while (r == 0);
        DEBUG("DEBUG: Received " << r << " CQE Elements\n");

        numRetMsg += r;

        for (int j = 0; j < r; j++) {
            DEBUG ("test");
            DEBUG("DEBUG: WRID(" << controlWc.wr_id <<
                                 ")\tStatus(" << controlWc.status << ")" <<
                                 ")\tSize(" << controlWc.byte_len << ")\n");
        }

        m[numRetMsg-1] = Message(numRetMsg-1, 0, controlWc.byte_len, controlBuffer); //we can reuse the buffer now.
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
    int mr_flags = IBV_ACCESS_LOCAL_WRITE | IBV_ACCESS_REMOTE_READ | IBV_ACCESS_REMOTE_WRITE;
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

int RdmaUdTransport::RDMACreateChannel()
{
    int ret = 0;
    g_CMEventChannel = NULL;

    // Open a Channel to the Communication Manager used to receive async events from the CM.
    g_CMEventChannel = rdma_create_event_channel();
    if(!g_CMEventChannel)
    {
        fprintf(stderr,"ERROR: Failed to Open CM Event Channel");
        CleanUpCMContext();
        return -1;
    }

    ret = rdma_create_id(g_CMEventChannel,&g_CMId, NULL, RDMA_PS_TCP);
    if(ret != 0)
    {
        fprintf(stderr,"ERROR: Failed to Create CM ID");
        CleanUpCMContext();
        return -1;
    }

    return 0;
}

int RdmaUdTransport::RDMAClientInit()
{
    int ret;
    rdma_cm_event_type et;

    if(get_addr(s_srcAddr.c_str(), (struct sockaddr*)&g_srcAddr) != 0)
    {
        fprintf(stderr,"ERROR: Failed to Resolve Local Address\n");
        CleanUpCMContext();
        return -1;
    }


    if(get_addr(s_dstAddr.c_str(),(struct sockaddr*)&g_dstAddr) != 0)
    {
        fprintf(stderr,"ERROR: Failed to Resolve Destination Address\n");
        CleanUpCMContext();
        return -1;
    }
    g_dstAddr.sin_port = n_dstPort;
    char str[INET_ADDRSTRLEN];
    inet_ntop(AF_INET, &(g_dstAddr.sin_addr), str, INET_ADDRSTRLEN);
    fprintf(stderr,"Processor address(%s) port(%u)\n", str, g_dstAddr.sin_port);

    /*
     * Resolve the IP Addresses to GIDs.
     */
    fprintf(stderr,"DEBUG: Resolving IP addresses to GIDS ...\n");
    ret = rdma_resolve_addr(g_CMId, (struct sockaddr*)&g_srcAddr, (struct sockaddr*)&g_dstAddr,2000);
    if(ret != 0)
    {
        fprintf(stderr,"ERROR: CM couldn't resolve IP addresses to GIDS\n");
        return -1;
    }

    fprintf(stderr,"DEBUG: Waiting for CM to resolve IP Addresses ...\n");
    do
    {
        ret = GetCMEvent(&et);
        if(ret != 0)
        {
            fprintf(stderr,"ERROR: Failed processing CM Events\n");
        }
    } while(et != RDMA_CM_EVENT_ADDR_RESOLVED);

    return 0;
}

int RdmaUdTransport::RDMAServerInit()
{
    int ret;

    if(get_addr(s_srcAddr.c_str(),(struct sockaddr*)&g_srcAddr) != 0)
    {
        fprintf(stderr, "ERROR: Failed to Resolve Local Address\n");
        CleanUpCMContext();
        return -1;
    }
    g_srcAddr.sin_port = n_srcPort;

    ret = rdma_bind_addr(g_CMId, (struct sockaddr*)&g_srcAddr);
    if(ret != 0 )
    {
        fprintf(stderr, "ERROR: RDMAServerInit - Couldn't bind to local address\n");
    }

    rdma_listen(g_CMId, 10);

    uint16_t port = 0;
    port = rdma_get_src_port(g_CMId);
    fprintf(stderr, "DEBUG: Listening on port %d.\n", port);
    return 0;
}

int RdmaUdTransport::RDMACreateQP()
{
    int ret;
    struct ibv_qp_init_attr qp_init_attr;

    //Create a Protection Domain
    g_pd = ibv_alloc_pd(g_CMId->verbs);
    if(!g_pd)
    {
        fprintf(stderr,"ERROR: - RDMACreateQP: Couldn't allocate protection domain\n");
        return -1;
    }

    /*Create a completion Queue */
    g_cq = ibv_create_cq(g_CMId->verbs, NUM_OPERATIONS, NULL, NULL, 0);
    if(!g_cq)
    {
        fprintf(stderr, "ERROR: RDMACreateQP - Couldn't create completion queue\n");
        return -1;
    }

    /* create the Queue Pair */
    memset(&qp_init_attr, 0, sizeof(qp_init_attr));

    qp_init_attr.qp_type = IBV_QPT_RC;
    qp_init_attr.sq_sig_all = 0;
    qp_init_attr.send_cq = g_cq;
    qp_init_attr.recv_cq = g_cq;
    qp_init_attr.cap.max_send_wr = NUM_OPERATIONS;
    qp_init_attr.cap.max_recv_wr = NUM_OPERATIONS;
    qp_init_attr.cap.max_send_sge = 1;
    qp_init_attr.cap.max_recv_sge = 1;


    ret = rdma_create_qp(g_CMId, g_pd, &qp_init_attr);
    if(ret != 0)
    {
        fprintf(stderr, "ERROR: RDMACreateQP: Couldn't Create Queue Pair Error(%d)\n", errno);
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

void RdmaUdTransport::CleanUpCMContext()
{
    if(g_CMEventChannel != NULL)
    {
        rdma_destroy_event_channel(g_CMEventChannel);
    }

    if(g_CMId != NULL)
    {
        if(rdma_destroy_id(g_CMId) != 0)
        {
            fprintf(stderr, "ERROR: CleanUpCMContext - Failed to destroy Connection Manager Id\n");
        }
    }
}

void RdmaUdTransport::CleanUpQPContext()
{
    if(g_pd != NULL)
    {
        if(ibv_dealloc_pd(g_pd) != 0)
        {
            fprintf(stderr, "ERROR: CleanUpQPContext - Failed to destroy Protection Domain\n");
        }
    }

    if(g_cq != NULL)
    {
        ibv_destroy_cq(g_cq);
        {
            fprintf(stderr, "ERROR: CleanUpQPContext - Failed to destroy Completion Queue\n");
        }
    }

    rdma_destroy_qp(g_CMId);

}


