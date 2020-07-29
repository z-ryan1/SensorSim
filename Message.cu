//
// Created by alex on 7/15/20.
//

#include "Message.cuh"

using namespace std;

Message::Message(int seqNumber, int interval, int bufferSize, uint8_t *buffer) {
    seqNumber = seqNumber;
    interval = interval;
    bufferSize = bufferSize;
    buffer = new uint8_t[bufferSize];

    memcpy(buffer, buffer, bufferSize); //TODO: This will do a memory copy makes sense for receive?
}

Message::~Message() {
    delete[] buffer;
}


ostream& operator<<(ostream& os, const Message& m) {
    os << "[Message Seq #: " << m.seqNumber << "\tsize: " << m.bufferSize << "\tintreval: " << m.interval << "]";
    return os;
}

void Message::printBuffer(int byteCount) {
    cout << *this; //Print the Message Header first

    int lastByte = this->bufferSize;

    if(byteCount != 0 && byteCount > 0 && byteCount <= this->bufferSize)
        lastByte = byteCount;

    for (int j=0; (j < lastByte ) ; j++) {
        // Start printing on the next after every 16 octets
        if ((j % 16) == 0)
            cout << endl;

        // Print each octet as hex (x), make sure there is always two characters (.2).
        printf("%02X ", this->buffer[j]);
    }

}





