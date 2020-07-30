//
// Created by alex on 7/15/20.
//

#include "Message.cuh"

using namespace std;

Message::Message() {
    this->seqNumber = 0;
    this->interval = 0;
    this->bufferSize = 0;
}

Message::Message(int seqNumber, int interval, int bufferSize, uint8_t *buf) {
    this->seqNumber = seqNumber;
    this->interval = interval;
    this->bufferSize = bufferSize;
    memcpy(buffer, buf, bufferSize); //TODO: This will do a memory copy makes sense for receive?
}

Message::~Message() {

}


ostream& operator<<(ostream& os, const Message& m) {
    os << "[Message Seq #: " << m.seqNumber << "\tsize: " << m.bufferSize << "\tintreval: " << m.interval << "]";
    return os;
}

void Message::printBuffer(int byteCount) {
    cout << *this; //Print the Message Header first

    int lastByte = bufferSize;

    if(byteCount != 0 && byteCount > 0 && byteCount <= bufferSize)
        lastByte = byteCount;

    for (int j=0; (j < lastByte ) ; j++) {
        // Start printing on the next after every 16 octets
        if ((j % 16) == 0)
            cout << endl;

        // Print each octet as hex (x), make sure there is always two characters (.2).
        //cout << std::setfill('0') << std::setw(2) << hex << (0xff & (unsigned int)buffer[j]) << " ";
        printf("%02hhX ", buffer[j]);
    }
    cout << endl;
}





