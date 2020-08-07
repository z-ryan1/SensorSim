#include <iostream>
#include <unistd.h>
#include <chrono>

#include "../common.cuh"
#include "../Message.cuh"
#include "../transport/iTransport.cuh"
#include "../transport/UDPTransport.cuh"

#include "Sensor.cuh"

using namespace std;

void PrintUsage()
{
    cout << "usage: sensorSim [ -s pcap ] [-m mode] remote-addr remote-port" << endl;
    cout << "\t remote-addr remote-port - ipv4 address of a processorSim" << endl;
    cout << "\t[-s file] - datafile to use as Sensor flow, accepts pcap format (default: random 256b pattern)" << endl;
    cout << "\t[-m mode] - run mode, PRINT, UDP (default: PRINT)" << endl;
    cout << "\t[-t time] - time to run in seconds. (default: 60 sec)" << endl;
    cout << "\t[-l file] - local ip addresss to bind. (default: bind to first address)" << endl;
}

int main(int argc,char *argv[], char *envp[]) {
     /*
     * Parsing the command line and validating the input
     */
    int op;
    string fileName;
    string mode = "PRINT";
    string dstAddr;
    int dstPort = 0;
    string srcAddr;
    int timeToRun = 60;
    char hostBuffer[256];

    while ((op = getopt(argc, argv, "m:s:l:t:")) != -1) {
        switch (op) {
            case 'l':
                srcAddr = optarg;
                break;
            case 's':
                fileName = optarg;
                break;
            case 'm':
                mode = optarg;
                if (mode != "PRINT" && mode != "UDP")
                {
                    PrintUsage();
                    return -1;
                }
                break;
            case 't':
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
    cout << "Mode: " << mode << endl;
    cout << "Source: " << (fileName.empty() ? "Random Stream" : fileName) << endl << endl;

    //Create the Sensor
    iTransport* t = new UDPTransport(srcAddr, dstPort, dstAddr, dstPort);
    Sensor s = Sensor(t);

    (fileName.empty()) ? s.createRandomFlow(RAND_FLOW_MSG_SIZE, RAND_FLOW_MSG_COUNT) :  s.createPCAPFlow(fileName);
    cout << "Sensor Flow has " << s.getFlowLength() << " messages of size " << RAND_FLOW_MSG_SIZE << endl;
    cout << "sending flow for " << timeToRun << " seconds" << endl;

    //Transmit or Print the Flow
    if (mode == "UDP")
    {
        //UDP Send
        chrono::time_point<chrono::system_clock> start;
        start = chrono::system_clock::now();
        chrono::duration<double> delta;

        do {
            s.sendFlow();
            delta = chrono::system_clock::now() - start;
            } while(delta.count() <= timeToRun);
       // }while(true);
    }
    else
    {
        s.printFlow();
    }

    return 0;
}
