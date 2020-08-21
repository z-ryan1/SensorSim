//
// Created by alex on 7/15/20.
//

#include "Processor.cuh"

inline cudaError_t checkCuda(cudaError_t result)
{
    if (result != cudaSuccess) {
        fprintf(stderr, "CUDA Runtime Error: %s\n", cudaGetErrorString(result));
        assert(result == cudaSuccess);
    }
    return result;
}

__global__ void gpu_count_zeros(Message* flow, int* sum, int flowLength)
{
    int indx = blockDim.x * blockIdx.x + threadIdx.x;
    int stride = blockDim.x * gridDim.x;

    for(int i = indx; i < flowLength; i += stride)
    {
        for(int j = 0; j < flow[i].bufferSize; j++)
        {
            if(flow[i].buffer[j] == 0)
            {
                sum[i] += 1;
                //cout << "found a zero at msg[" << i << "] byte[" << j << "]" << endl;
            }
        }
    }
}


void cpu_count_zeros(Message* flow, int& sum, int flowLength)
{
    for(int i = 0; i < flowLength; i++)
    {
        for(int j = 0; j < flow[i].bufferSize; j++)
        {
            if(flow[i].buffer[j] == 0)
            {
                sum += 1;
                //cout << "found a zero at msg[" << i << "] byte[" << j << "]" << endl;
            }
        }
    }
}


Processor::Processor(ITransport* t) {
    transport = t;
}

void Processor::procCountZerosGPU(int minMessageToProcess) {
    chrono::time_point<chrono::system_clock> start;
    chrono::duration<double> timeToProcess;

    int deviceId;
    int numberOfSMs;

    cudaGetDevice(&deviceId);
    cudaDeviceGetAttribute(&numberOfSMs, cudaDevAttrMultiProcessorCount, deviceId);

    size_t threadsPerBlock;
    size_t numberOfBlocks;

    threadsPerBlock = 256;
    numberOfBlocks = 32 * numberOfSMs;

    int msgCountReturned = 0;
    int processedMessages = 0;
    int sum =0;

    Message* m;//Create array that is max message block size
    size_t msgBlockSize = MSG_BLOCK_SIZE * sizeof(Message);
    checkCuda( cudaMallocManaged(&m, msgBlockSize));

    int* blockSum;   //Array with sum of zeros for this message
    size_t sumArraySize = MSG_BLOCK_SIZE * sizeof(int);
    checkCuda( cudaMallocManaged(&blockSum, sumArraySize));
   // cout << "Processing on GPU using " <<  numberOfBlocks << " blocks with " << threadsPerBlock << " threads per block" << endl;

    start = chrono::system_clock::now();
    while (processedMessages < minMessageToProcess) {

        if (0 != transport->pop(m, MSG_BLOCK_SIZE, msgCountReturned, eTransportDest::DEVICE)) {
            exit(EXIT_FAILURE);
        }

        cudaMemPrefetchAsync(m, msgBlockSize, deviceId);

        if(msgCountReturned > 0) //If there are new messages process them
        {
            cerr << "\rProcessed " << processedMessages << " messages";
            gpu_count_zeros <<< threadsPerBlock, numberOfBlocks >>>(m, blockSum, msgCountReturned);

            checkCuda( cudaGetLastError() );
            checkCuda( cudaDeviceSynchronize() ); //Wait for GPU threads to complete

            cudaMemPrefetchAsync(blockSum, sumArraySize, cudaCpuDeviceId);

            for(int k = 0; k < msgCountReturned; k++)
            {
                sum += blockSum[k]; //Add all the counts to the accumulator
                blockSum[k] = 0;
            }

            processedMessages += msgCountReturned;
        }
        //m.clear();
        msgCountReturned=0;

    }
    timeToProcess = chrono::system_clock::now() - start;

    checkCuda( cudaFree(m));
    checkCuda( cudaFree(blockSum));

    cout << "\n Processing Completed: " << endl;
    cout << "\t processed " << processedMessages << " in " << timeToProcess.count() << " sec" << endl;
    cout << "\t total zero's in messages = " << sum << endl;
    exit(EXIT_SUCCESS);
}

int Processor::procCountZerosCPU(int minMessageToProcess) {
    chrono::time_point<chrono::system_clock> start;
    chrono::duration<double> timeToProcess;

    Message m[MSG_BLOCK_SIZE];
    int msgCountReturned = 0;
    int sum = 0;
    int processedMessages = 0;

    start = chrono::system_clock::now();
    while (processedMessages < minMessageToProcess) {

        if (0 != transport->pop(m, MSG_BLOCK_SIZE, msgCountReturned, eTransportDest::HOST)) {
            exit(EXIT_FAILURE);
        }

        if(msgCountReturned > 0) //If there are new messages process them
        {
            cerr << "\rProcessed " << processedMessages << " messages";
            cpu_count_zeros(m, sum, msgCountReturned);
            processedMessages += msgCountReturned;
        }
        msgCountReturned=0;

    }
    timeToProcess = chrono::system_clock::now() - start;

    cout << "\nProcessing Completed: " << endl;
    cout << "\t processed " << processedMessages << " in " << timeToProcess.count() << " sec" << endl;
    cout << "\t total zero's in messages = " << sum << endl;
    exit(EXIT_SUCCESS);
}

int Processor::procPrintMessages(int minMessageToProcess) {
    Message m[MSG_BLOCK_SIZE];
    int processedCount = 0;
    int r = 0;

    do {

        if (0 != transport->pop(m, MSG_BLOCK_SIZE, r, eTransportDest::HOST)) {
            exit(EXIT_FAILURE);
        }

        processedCount += r;

        cout << "Printing first bytes of " << min(r,minMessageToProcess) << " messages" << endl;
        for(int i = 0; i<min(r,minMessageToProcess); i++)
        {
            m[i].printBuffer(32);
            cout << endl;
        }
    } while (processedCount < minMessageToProcess);

    //Simple process (i.e. print)
    cout << "Processing Completed: found " << processedCount << " messages" << endl;




    exit(EXIT_SUCCESS);
}
