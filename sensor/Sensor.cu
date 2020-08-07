//
// Created by alex on 7/15/20.
//

#include "Sensor.cuh"

Sensor::Sensor(iTransport* t) {
    transport = t;
}

int Sensor::createPCAPFlow(string fileName)
{
    //Get the Message count
    pcap_t *handle;
    char errbuf[PCAP_ERRBUF_SIZE];
    struct pcap_pkthdr *header;
    const u_char *data;

    handle = pcap_open_offline(fileName.c_str(), errbuf);

    if (handle == nullptr) {
        cout << "Couldn't open pcap file "<< fileName << ":" << errbuf << endl;
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

        m = new Message(i++, deltaUSec, header->caplen, (uint8_t*)data); //Cast from uchar
        cout << "Adding to flow: " << *m << endl;

        flow.push_back(m);
    }

    return 0;
}

int Sensor::createRandomFlow(int msgLength, int numMsg) {

    for(int i=0; i<numMsg; ++i)
    {
        //Create Random Message
        auto* buffer = new uint8_t[msgLength];
        for(int j = 0; j < msgLength; ++j)
        {
            int r = (uint8_t)((rand()%256)+1);
            buffer[j]= r;

        }
        Message* m = new Message(i, 100, msgLength, buffer);
        flow.push_back(m);
    }

    return 0;
}

void Sensor::printFlow() {
    // loop through the messages and print as hexidecimal representations of octets
    for (int i=0; (i < flow.size() ) ; i++) {
      flow[i]->printBuffer(32);
      printf("\n\n ");
    }

    return;
}

int Sensor::getFlowLength() {
    return flow.size();
}

void Sensor::sendFlow() {
    for(int i = 0; i < flow.size() ; i++)
        transport->push(flow[i]);
}


