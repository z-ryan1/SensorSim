//
// Created by alex on 7/16/20.
//

#include <cstdio>
#include <arpa/inet.h>
#include <iostream>

#include "UDPTransport.cuh"

UDPTransport::UDPTransport(string srcAddr, int srcPort, string dstAddr, int dstPort) {

    s_srcAddr = srcAddr;
    n_srcPort = srcPort;
    s_dstAddr = dstAddr;
    n_dstPort = dstPort;

    // Creating socket file descriptor
   cout << "Creating local UDP socket: " << s_srcAddr << endl;
    if ((sockfd = socket(AF_INET, SOCK_DGRAM, 0)) < 0) {
        perror("socket creation failed");
        exit(EXIT_FAILURE);
    }

    //Create the SockAddr for the Local System
    memset(&this->g_srcAddr, 0, sizeof(this->g_srcAddr));
    this->g_srcAddr.sin_family = AF_INET;
    this->g_srcAddr.sin_port = htons(n_srcPort);
    if(s_srcAddr.empty())
    {
        this->g_srcAddr.sin_addr.s_addr = INADDR_ANY;
    }
    else
    {
        inet_pton(AF_INET, s_srcAddr.c_str(), &this->g_srcAddr.sin_addr);
    }

    memset(&this->g_dstAddr, 0, sizeof(this->g_dstAddr));
    this->g_dstAddr.sin_family = AF_INET;
    this->g_dstAddr.sin_port = htons(n_dstPort);
    inet_pton(AF_INET, s_dstAddr.c_str(), &this->g_dstAddr.sin_addr);

    // Bind the socket with the server address
    cout << "Bind the socket local address: " << s_srcAddr << endl;
    if (bind(sockfd, (const struct sockaddr *) &this->g_srcAddr,
             sizeof(this->g_srcAddr)) < 0) {
        perror("bind failed");
        exit(EXIT_FAILURE);
    }

}

int UDPTransport::push(Message* m)
{
    sendto(this->sockfd, (const char *)m->buffer, m->bufferSize,
           MSG_CONFIRM, (const struct sockaddr *) &this->g_dstAddr, sizeof(this->g_dstAddr));
    DEBUG("To " << inet_ntoa(g_dstAddr.sin_addr) << endl);
    DEBUG("Sent a Msg: " << *m << endl);
    //m->printBuffer(32);

    return 0;
}

/*
*  Pulls a message from the transport and places it in the buffer
*/
int UDPTransport::pop(Message* m, int numReqMsg, int& numRetMsg, eTransportDest dest)
{
    uint8_t buffer[MAX_MESSAGE_SIZE];    // receive buffer
    int recvlen;                         // num bytes received
    struct sockaddr_in from;             // Sender's address. TODO: Don't need these, just waste perf
    int fromlen;                         // Length of sender's address.

    DEBUG("waiting on port " << this->n_srcPort << endl);

    for(int i = 0; i < numReqMsg; i++)
    {
        recvlen = recvfrom(this->sockfd, buffer, MAX_MESSAGE_SIZE, MSG_DONTWAIT, reinterpret_cast<sockaddr *>(&from),
                           reinterpret_cast<socklen_t *>(&fromlen));

        if (recvlen > 0) {
            //cout << "received " << recvlen << " bytes " << "from " << inet_ntoa(from.sin_addr) << endl;
            m[i] = Message(i,0,recvlen, buffer); //TODO: doing a copy in here, not good.
            numRetMsg = numRetMsg + 1;
        } else if(recvlen == -1) {
            //Nothing on Socket
            return 0;
        }
    }

    return 0;
}
