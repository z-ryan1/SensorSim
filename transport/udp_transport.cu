//
// Created by alex on 7/16/20.
//

#include <cstdio>
#include <arpa/inet.h>
#include <iostream>

#include "udp_transport.cuh"

UpdTransport::UpdTransport(string localAddr, string mcastAddr, eTransportRole role) {

    s_localAddr = localAddr;
    s_mcastAddr = mcastAddr;
    n_mcastPort = 6655; //TODO: does this matter?
    n_localPort = 6655; //TODO: does this matter?

    bzero( &g_localAddr, sizeof( g_localAddr ) );
    bzero( &g_mcastAddr, sizeof( g_mcastAddr ) );

    // Creating socket file descriptor
       if ((sockfd = socket(AF_INET, SOCK_DGRAM, 0)) < 0) {
        cerr << "ERROR UpdTransport - Failed to create socket " << errno << endl;
        exit(EXIT_FAILURE);
    }
    cout << "Created local UDP socket: " << sockfd << endl;

    if(role == eTransportRole::SENSOR)
    {
        memset((char *) &g_mcastAddr, 0, sizeof(g_mcastAddr));
        g_mcastAddr.sin_family = AF_INET;
        g_mcastAddr.sin_addr.s_addr = inet_addr(s_mcastAddr.c_str());
        g_mcastAddr.sin_port = htons(n_mcastPort);

        char loopch=0;

        if (setsockopt(sockfd, IPPROTO_IP, IP_MULTICAST_LOOP,
                (char *)&loopch,
                sizeof(loopch)) < 0) {
            cerr << "ERROR UpdTransport - disable loop back failed set opt " << errno << endl;
            close(sockfd);
            exit(EXIT_FAILURE);
        }

        inet_pton(AF_INET, s_localAddr.c_str(), &this->g_localAddr.sin_addr);
        if (setsockopt(sockfd, IPPROTO_IP, IP_MULTICAST_IF,
                       (char *)&g_localAddr,
                       sizeof(g_localAddr)) < 0) {
            cerr << "ERROR UpdTransport - Setting up local interface " << strerror(errno) << endl;
            exit(1);
        }

    } else if(role == eTransportRole::PROCESSOR) {

        {
            int reuse=1;

            if (setsockopt(sockfd, SOL_SOCKET, SO_REUSEADDR,
                           (char *)&reuse, sizeof(reuse)) < 0) {
                cerr << "ERROR UpdTransport - set option to allow socket reuse " << errno << endl;
                close(sockfd);
                exit(EXIT_FAILURE);
            }
        }

        //Create the SockAddr for the Local System
        memset(&g_localAddr, 0, sizeof(g_localAddr));
        g_localAddr.sin_family = AF_INET;
        g_localAddr.sin_port = htons(n_localPort);
        g_localAddr.sin_addr.s_addr = INADDR_ANY;

        cout << "Bind the socket local address: " << s_localAddr << endl;
        if (bind(sockfd, (const struct sockaddr *) &g_localAddr,
                 sizeof(g_localAddr)) < 0) {
            cerr << "ERROR UpdTransport - failed to bind to local socket " << errno << endl;
            exit(EXIT_FAILURE);
        }

        if (inet_pton(AF_INET, s_mcastAddr.c_str(), &mcastGroup.imr_multiaddr.s_addr) != 1) {
            cerr << "ERROR inet pton can't convert address " << errno << endl;
            close(sockfd);
            exit(1);
        }
        if (inet_pton(AF_INET, s_localAddr.c_str(), &mcastGroup.imr_interface.s_addr) != 1) {
            cerr << "ERROR inet pton can't convert address " << errno << endl;
            close(sockfd);
            exit(1);
        }

        if (setsockopt(sockfd, IPPROTO_IP, IP_ADD_MEMBERSHIP,
                       (char *)&mcastGroup, sizeof(mcastGroup)) < 0) {
            cerr << "ERROR UpdTransport - couldn't join mcast group " << errno << endl;
            close(sockfd);
            exit(1);
        }


    }

}

int UpdTransport::push(Message* m)
{
    if(sendto(sockfd, (const char *)m->buffer, m->bufferSize,0,
            (const struct sockaddr *) &this->g_mcastAddr,
                    sizeof(this->g_mcastAddr)) <= 0)
    {
        cerr << "ERROR UpdTransport Push - failed sendto operation " << errno << endl;
        close(sockfd);
        exit(EXIT_FAILURE);
    }
    DEBUG("To " << inet_ntoa(g_mcastAddr.sin_addr) << endl);
    DEBUG("Sent a Msg: " << *m << endl);
    //m->printBuffer(32);

    return 0;
}

/*
*  Pulls a message from the transport and places it in the buffer
*/
int UpdTransport::pop(Message* m, int numReqMsg, int& numRetMsg, eTransportDest dest)
{
    uint8_t buffer[MSG_MAX_SIZE];    // receive buffer
    int recvlen;                         // num bytes received
    struct sockaddr_in from;             // Sender's address. TODO: Don't need these, just waste perf
    int fromlen;                         // Length of sender's address.

    DEBUG("waiting on socket " << this->n_localPort << endl);

    for(int i = 0; i < numReqMsg; i++)
    {
        //recvlen = sockfd, buffer, MSG_MAX_SIZE);
        recvlen = recvfrom(this->sockfd, buffer, 1000, 0, reinterpret_cast<sockaddr *>(&from),
                 reinterpret_cast<socklen_t *>(&fromlen));

        if (recvlen > 0) {
            //cout << "received " << recvlen << " bytes " << "from " << inet_ntoa(from.sin_addr) << endl;
            m[i] = Message(i,0,recvlen, buffer); //TODO: doing a copy in here, not good.
            numRetMsg = numRetMsg + 1;
        } else if(recvlen == -1) {
            cerr << "ERROR UpdTransport Pop - failed mcast socket read " << errno << endl;
            close(sockfd);
            exit(EXIT_FAILURE);
        }
    }

    return 0;
}

