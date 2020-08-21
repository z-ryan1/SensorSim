//
// Created by alex on 7/27/20.
//

#ifndef SENSORSIM_COMMON_CUH
#define SENSORSIM_COMMON_CUH

#include <iostream>
#include <chrono>

//#define DEBUG_BUILD

#ifdef DEBUG_BUILD
#define DEBUG(x) cerr << x
#define DEBUG_DETAIL(x) x
#else
#  define DEBUG(x) do {} while (0)
#  define DEBUG_DETAIL(x) do {} while (0)
#endif

#define PRINT_UPDATE_DELAY 1    //Used with timer

#define MSG_MAX_SIZE 1500       //Max size of a message in a flow, must be > RAND_FLOW_MSG_SIZE or max size message from pcap
#define MSG_BLOCK_SIZE 1000     //Number of messages to process in parallel

//Sensor Defines
#define RAND_FLOW_MSG_SIZE 1024     //Size of the Messages in Random Flow
#define RAND_FLOW_MSG_COUNT 1024    //Number of Messages in the Flow

struct timer
{
    typedef std::chrono::steady_clock clock ;
    typedef std::chrono::seconds seconds ;

    void reset() { start = clock::now() ; }

    unsigned long long seconds_elapsed() const
    { return std::chrono::duration_cast<seconds>( clock::now() - start ).count() ; }

private: clock::time_point start = clock::now() ;
};


#endif //SENSORSIM_COMMON_CUH
