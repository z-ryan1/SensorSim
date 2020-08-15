#include "Sensor.cuh"

#include <iostream>
#include <unistd.h>
#include <chrono>

#include "../common.cuh"
#include "../Message.cuh"
#include "../transport/itransport.cuh"
#include "../transport/udp_transport.cuh"
#include "../transport/rdma_ud_transport.cuh"



void PrintUsage()
{
    cout << "usage: sensorSim [ -s pcap ] [-t mode] [-l local-addr] [-d duration] remote-addr remote-port" << endl;
    cout << "\t remote-addr remote-port - ipv4 address of a processorSim" << endl;
    cout << "\t[-s file] - datafile to use as Sensor flow, accepts pcap format (default: random 256b pattern)" << endl;
    cout << "\t[-t transport mode] - transport mode, PRINT, UDP, RDMA-UD (default: PRINT)" << endl;
    cout << "\t[-d time] - time to run in seconds. (default: 60 sec)" << endl;
    cout << "\t[-l file] - local ip addresss to bind. (default: bind to first address)" << endl;
}

int main(int argc,char *argv[], char *envp[]) {
     /*
     * Parsing the command line and validating the input
     */
    int op;
    string fileName;
    string tmode = "PRINT";
    string dstAddr;
    int dstPort = 0;
    string srcAddr;
    int timeToRun = 60;
    char hostBuffer[256];

    while ((op = getopt(argc, argv, "d:s:l:t:")) != -1) {
        switch (op) {
            case 'l':
                srcAddr = optarg;
                break;
            case 's':
                fileName = optarg;
                break;
            case 't':
                tmode = optarg;
                if (tmode != "PRINT" && tmode != "UDP" && tmode != "RDMA-UD")
                {
                    PrintUsage();
                    return -1;
                }
                break;
            case 'd':
                timeToRun = atoi(optarg);
                break;
            default:
                PrintUsage();
                return -1;
        }
    }

    if(argc <= optind+1)
    {
        PrintUsage();
        return -1;
    }
    else
    {
        dstAddr = argv[optind++];
        dstPort = atoi(argv[optind]);
    }
    gethostname(hostBuffer, sizeof(hostBuffer));
    cout << "********  ********  ********  ********  ********  ********" << endl;
    cout << "Sensor Simulator - Read Data Source and sends data buffers to target" << endl;
    cout << "********  ********  ********  ********  ********  ********" << endl;
    cout << "Running on " << hostBuffer <<endl;
    cout << "Local Address: " << (srcAddr.empty() ? "Default" : srcAddr) << endl;
    cout << "Target Address: " << dstAddr << " Port: " << dstPort << endl;
    cout << "Source: " << (fileName.empty() ? "Random Stream" : fileName) << endl;
    cout << "Transport Mode: " << tmode << endl <<endl;

    //Create the Transport
    ITransport* t;
    if(tmode == "UDP")
        t = new UpdTransport(srcAddr, dstPort, dstAddr, dstPort);
    else if(tmode == "RDMA-UD")
        t = new RdmaUdTransport(srcAddr, dstPort, dstAddr, dstPort, eTransportRole::SENSOR);

    //Create the Sensor
    Sensor s = Sensor(t);

    (fileName.empty()) ? s.createRandomFlow(RAND_FLOW_MSG_SIZE, RAND_FLOW_MSG_COUNT) :  s.createPCAPFlow(fileName);
    cout << "Sensor Flow has " << s.getFlowLength() << " messages of size " << RAND_FLOW_MSG_SIZE << endl;
    cout << "sending flow for " << timeToRun << " seconds" << endl;

    //Transmit or Print the Flow
    if (tmode == "PRINT") {
        s.printFlow();
    } else {
        chrono::time_point<chrono::system_clock> start;
        chrono::duration<double> delta;

        start = chrono::system_clock::now();
        do {
            if (0 != s.sendFlow())
            {
                cout << "Transport Error Sending sensor Flow - Exiting" << endl;
                return -1;
            }
            delta = chrono::system_clock::now() - start;
        } while (delta.count() <= timeToRun);
    }

    return 0;
}
