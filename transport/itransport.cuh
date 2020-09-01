//
// Created by alex on 8/7/20.
//

#ifndef SENSORSIM_ITRANSPORT_CUH
#define SENSORSIM_ITRANSPORT_CUH

#include <netinet/in.h>

enum class eTransportDest {HOST, DEVICE};
enum class eTransportType {UDP, RDMA_UD};
enum class eTransportRole {SENSOR, PROCESSOR};

typedef struct
{
    int interval; //Number of us since last Message
    int bufferSize; //Size in bytes of the Message
    int seqNumber; //Position of the Message in the flow
    uint8_t buffer[MSG_MAX_SIZE];
} Message;


class ITransport {

public:
    virtual int push(Message* msg) = 0;
    virtual int pop(Message** m, int numReqMsg, int& numRetMsg, eTransportDest dest ) = 0;

    virtual Message* createMessage() = 0;
    virtual int freeMessage(Message* msg) = 0;

    eTransportType getType()
    {
        return transportType;
    }

    std::string printType() {
        if(transportType == eTransportType::UDP)
            return "UDP Multicast";
        else if(transportType == eTransportType::RDMA_UD)
            return "RDMA Unreliable Datagram (UD) Multicast";
        else
            return "transport unknown";
    }

    static void printMessage(Message* m, int byteCount) {
        std::cout << "[Message Seq #: " << m->seqNumber << "\tsize: " << m->bufferSize << "\tintreval: " << m->interval << "]";

        int lastByte = m->bufferSize;

        if (byteCount != 0 && byteCount > 0 && byteCount <= m->bufferSize)
            lastByte = byteCount;

        for (int j = 0; (j < lastByte); j++) {
            // Start printing on the next after every 16 octets
            if ((j % 16) == 0)
                std::cout << std::endl;

            // Print each octet as hex (x), make sure there is always two characters (.2).
            //cout << std::setfill('0') << std::setw(2) << hex << (0xff & (unsigned int)buffer[j]) << " ";
            printf("%02hhX ", m->buffer[j]);
        }
        std::cout << std::endl;
    }


protected:
    //All Transports will use basic IPoX as a control plane to establish a connection.
    std::string                 s_mcastAddr;
    int                         n_mcastPort;
    std::string                 s_localAddr;
    int                         n_localPort;
    struct sockaddr_in			g_localAddr;
    struct sockaddr_in			g_mcastAddr;
    int                         sockfd;

    eTransportType              transportType;
};



#endif //SENSORSIM_ITRANSPORT_CUH
