#include <iostream>
#include <unistd.h>

#include "../Message.cuh"
#include "../transport/iTransport.cuh"

#include "Processor.cuh"
#include "../transport/UDPTransport.cuh"

using namespace std;

#define MIN_MSG_TO_PRINT    10
#define MIN_MSG_TO_PROCESS  10'00'000  //CPU count our GPU count


void PrintUsage()
{
    cout << "usage: processorSim [ -s pcap ] [-m mode] remote-addr remote-port" << endl;
    cout << "\t remote-addr remote-port - ipv4 address of a sensorSim" << endl;
    cout << "\t[-m mode] - run mode: PRINT, CPU-COUNT, GPU-COUNT (default: PRINT)" << endl;
    cout << "\t[-t mode] - transport to use: UDP, UD, UCX (default: UDP)" << endl;
    cout << "\t[-l local-addr] - local ipv4 addresss to bind. (default: bind to first address)" << endl;
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
    char hostBuffer[256];
    string tmode = "UDP";

    while ((op = getopt(argc, argv, "m:s:l:t:")) != -1) {
        switch (op) {
            case 'l':
                srcAddr = optarg;
                break;
            case 'm':
                mode = optarg;
                if (mode != "PRINT" && mode != "CPU-COUNT" && mode != "GPU-COUNT")
                {
                    PrintUsage();
                    return -1;
                }
                break;
            case 't':
                tmode = optarg;
                if (mode != "UDP" && mode != "RDMA-UD")
                {
                    PrintUsage();
                    return -1;
                }
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
    cout << "Processor Simulator - Receive Messages from a sensor and process them" << endl;
    cout << "********  ********  ********  ********  ********  ********" << endl;
    cout << "Running on " << hostBuffer <<endl;
    cout << "Local Address: " << (srcAddr.empty() ? "Default" : srcAddr) << endl;
    cout << "Sensor Address: " << dstAddr << " Port: " << dstPort << endl;
    cout << "Processor Mode: " << mode << endl;
    cout << "Processor Mode: " << tmode << endl;


    //Create the Transport
    iTransport* t;
    if(tmode == "UDP")
        t = new UDPTransport(srcAddr, dstPort, dstAddr, dstPort);
    // else if(tmode == "RDMA-UD")
    //t = new RDMAUDTransport(srcAddr, dstPort, dstAddr, dstPort);

    Processor p = Processor(t);

    if(mode == "PRINT")
    {
        cout << "This processor will print " << MIN_MSG_TO_PRINT << " msg then exit" << endl;
        p.procPrintMessages(MIN_MSG_TO_PRINT);
    }
    else if(mode == "CPU-COUNT")
    {
        cout << "This processor will count zeros in " << MIN_MSG_TO_PROCESS << " msg using the CPU" << endl;
        p.procCountZerosCPU(MIN_MSG_TO_PROCESS);
    }
    else if(mode == "GPU-COUNT")
    {
        cout << "This processor will count zeros in " << MIN_MSG_TO_PROCESS << " msg using the GPU" << endl;
        p.procCountZerosGPU(MIN_MSG_TO_PROCESS);
    }

    return 0;
}
