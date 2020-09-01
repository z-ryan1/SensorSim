//
// Created by alex on 7/15/20.
//

#include "Sensor.cuh"

Sensor::Sensor(ITransport* t) {
    transport = t;
}

int Sensor::createPCAPFlow(std::string fileName)
{
    //Get the Message count
    pcap_t *handle;
    char errbuf[PCAP_ERRBUF_SIZE];
    struct pcap_pkthdr *header;
    const u_char *data;

    handle = pcap_open_offline(fileName.c_str(), errbuf);

    if (handle == nullptr) {
        std::cout << "Couldn't open pcap file "<< fileName << ":" << errbuf << std::endl;
        return(2);
    }

    //Create the Flow, allocated the memory
    Message* m;

    //double lastMsgSec = 0, deltaSec = 0;
    double lastMsgUsec = 0, deltaUSec = 0;
    int i = 0;
    while (int returnValue = pcap_next_ex(handle, &header, &data) >= 0) {

        // Set the size of the Message in bytes
        DEBUG(printf("Packet size: %d bytes\n", header->caplen));

        // Set an interval time since last Message
        //printf("Epoch Time: %l:%l seconds\n", header->ts.tv_sec, header->ts.tv_usec);

        //deltaSec = (header->ts.tv_sec) - lastMsgSec; //TODO: Calculating Message interval factor in > 1 Second delays
        deltaUSec = (header->ts.tv_usec) - lastMsgUsec;

        m = transport->createMessage();
        m->seqNumber = i++;
        m->interval = deltaUSec;
        m->bufferSize = header->caplen;
        memcpy(m->buffer, data, header->caplen);

        std::cout << "Adding to flow: ";
        transport->printMessage(m, 0);
        std::cout << std::endl;

        flow.push_back(m);
    }

    return 0;
}

/*
 * Create a flow of messages to be sent from the sensor. The messages will be alocated in an appropriate message buffer
 * depending on the transport. The flow will be sent multiple times. The number of messages in the flow shouldn't exceed
 * the MSG_BLOCK_SIZE for this simulator.
 */
int Sensor::createRandomFlow(int msgLength, int numMsg) {

    if(numMsg > MSG_BLOCK_SIZE)
    {
        std::cerr << "ERROR - Requesting to create a flow longer than the Message Buffer.";
        return -1;
    }

    for(int i=0; i<numMsg; ++i)
    {
       DEBUG("FLOW Creation: Message # " << i << "\n");
       Message* m = NULL;
       m = transport->createMessage();
       m->seqNumber = i;
       m->interval = 100;
       m->bufferSize = msgLength;
        for(int j = 0; j < msgLength; ++j)
        {
            int r = (uint8_t)((rand()%256)+1);
            m->buffer[j]= r;
        }
        flow.push_back(m);

    }

    return 0;
}

void Sensor::printFlow() {
    // loop through the messages and print as hexidecimal representations of octets
    for (int i=0; (i < flow.size() ) ; i++) {
      transport->printMessage(flow[i], 32);
      printf("\n\n ");
    }

    return;
}

int Sensor::getFlowLength() {
    return flow.size();
}

int Sensor::sendFlow() {
    for(int i = 0; i < flow.size() ; i++)
    {
        if(0 != transport->push(flow[i]))
        {
            return -1;
        }
    }
    return 0;
}


