//
// Created by alex on 7/15/20.
//

#include "Processor.cuh"

#define MSG_BLOCK_SIZE 1000

/*
__global__ void count_zeros(Message* msg, int* sum)
{
    int i = threadIdx.x;

    for(int j = 0; j < msg->bufferSize; i++)
    {
        if(msg->buffer[j] == 0)
            sum++;
    }
}
 */

void cpu_count_zeros(vector<Message*>& flow, int& sum)
{
    for(int i = 0; i < flow.size(); i++)
    {
        for(int j = 0; j < flow[i]->bufferSize; j++)
        {
            if(flow[i]->buffer[j] == 0)
            {
                sum += 1;
                //cout << "found a zero at msg[" << i << "] byte[" << j << "]" << endl;
            }
        }
    }
}


Processor::Processor(Transport* t) {
    transport = t;
}

int Processor::procCountZerosCPU(int minMessageToProcess) {
    chrono::time_point<chrono::system_clock> start;
    chrono::duration<double> timeToProcess;

    vector<Message> m;
    int r = 0;
    int sum = 0;
    int processedMessages = 0;

    start = chrono::system_clock::now();
    while (processedMessages < minMessageToProcess) {

        if (0 != transport->pop(m, MSG_BLOCK_SIZE, r)) {
            exit(EXIT_FAILURE);
        }

        if(r > 0) //If there are new messages process them
        {
            //cpu_count_zeros(m, sum);
            processedMessages += r;
        }
        //m.clear();
        r=0;

    }
    timeToProcess = chrono::system_clock::now() - start;

    cout << "Processing Completed: " << endl;
    cout << "\t processed " << processedMessages << " in " << timeToProcess.count() << " sec" << endl;
    cout << "\t total zero's in messages = " << sum << endl;
    exit(EXIT_SUCCESS);
}

int Processor::procPrintMessages(int minMessageToProcess) {
    vector<Message> m;
    int r = 0;

    while (r < minMessageToProcess) {
        if (0 != transport->pop(m, MSG_BLOCK_SIZE, r)) {
            exit(EXIT_FAILURE);
        }
    }

    //Simple process (i.e. print)
    cout << "Processing Completed: found " << r << "messages" << endl;
    for(int i = 0; i<r; i++)
    {
        m[i].printBuffer(32);
    }

    exit(EXIT_SUCCESS);
}
