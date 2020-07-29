//
// Created by alex on 7/15/20.
//

#ifndef SENSORSIM_MESSAGE_CUH
#define SENSORSIM_MESSAGE_CUH

#include <unistd.h>
#include <stdint.h>
#include <cstdint>
#include <iostream>

using namespace std;

class Message {
public:
    int interval; //Number of us since last Message
    int bufferSize; //Size in bytes of the Message
    int seqNumber; //Position of the Message in the flow
    uint8_t* buffer;

    Message(int seqNumber, int interval, int bufferSize, uint8_t* buffer);
    ~Message();

    void printBuffer(int byteCount);
    friend ostream& operator<<(ostream& os, const Message& m);
};

#endif //SENSORSIM_MESSAGE_CUH
