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
    cout << "usage: sensorSim [ -s pcap ] [-t mode] [-l local-addr] [-d duration] mcast-addr" << endl;
    cout << "\t multicast group where sensor publishes data" << endl;
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
    string mcastAddr;
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

    if(argc <= optind)
    {
        PrintUsage();
        return -1;
    }
    else
    {
        mcastAddr = argv[optind++];
    }
    gethostname(hostBuffer, sizeof(hostBuffer));
    cout << "********  ********  ********  ********  ********  ********" << endl;
    cout << "Sensor Simulator - Read Data Source and sends data buffers to target" << endl;
    cout << "********  ********  ********  ********  ********  ********" << endl;
    cout << "Running on " << hostBuffer <<endl;
    cout << "Local Address: " << (srcAddr.empty() ? "Default" : srcAddr) << endl;
    cout << "Mcast Group Address: " << mcastAddr << endl;
    cout << "Source: " << (fileName.empty() ? "Random Stream" : fileName) << endl;
    cout << "Transport Mode: " << tmode << endl <<endl;

    //Create the Transport
    ITransport* t;
    if(tmode == "UDP")
        t = new UpdTransport(srcAddr, mcastAddr, eTransportRole::SENSOR);
    else if(tmode == "RDMA-UD")
        t = new RdmaUdTransport(srcAddr, mcastAddr, eTransportRole::SENSOR);

    //Create the Sensor
    Sensor s = Sensor(t);

    (fileName.empty()) ? s.createRandomFlow(RAND_FLOW_MSG_SIZE, RAND_FLOW_MSG_COUNT) :  s.createPCAPFlow(fileName);
    cout << "Sensor Flow has " << s.getFlowLength() << " messages of size " << RAND_FLOW_MSG_SIZE << endl;
    cout << "sending flow for " << timeToRun << " seconds" << endl;
    cout << "I will print an update every " << PRINT_UPDATE_DELAY << " seconds" << endl;

    //Transmit or Print the Flow
    if (tmode == "PRINT") {
        s.printFlow();
    } else {
        timer t_runTime;
        timer t_nextPrint;

        long long sentMessages = 0;
        long long messageRate = 0;

        do {
            if (0 != s.sendFlow())
            {
                cout << "Transport Error Sending sensor Flow - Exiting" << endl;
                return -1;
            }
            sentMessages += s.getFlowLength();
            messageRate += s.getFlowLength();

            //Print the Progress ever 1 Second
            if(t_nextPrint.seconds_elapsed() > PRINT_UPDATE_DELAY)
            {
                cerr << "\rSent " << sentMessages << " messages\t Rate: " << messageRate << "/" << PRINT_UPDATE_DELAY <<"sec";
                messageRate = 0;
                t_nextPrint.reset();
            }
        } while (t_runTime.seconds_elapsed() <= timeToRun);
    }

    return 0;
}
