//
// Created by alex on 7/27/20.
//

#ifndef SENSORSIM_COMMON_CUH
#define SENSORSIM_COMMON_CUH

#include <iostream>

//#define DEBUG_BUILD

#ifdef DEBUG_BUILD
#define DEBUG(x) cout << x
#define DEBUG_DETAIL(x) x
#else
#  define DEBUG(x) do {} while (0)
#  define DEBUG_DETAIL(x) do {} while (0)
#endif


#define MAX_MESSAGE_SIZE 4096       //Max size of a message in a flow, must be > RAND_FLOW_MSG_SIZE

//Sensor Defines
#define RAND_FLOW_MSG_SIZE 1024     //Size of the Messages in Random Flow
#define RAND_FLOW_MSG_COUNT 1024    //Number of Messages in the Flow

//Processor Defines
#define MSG_BLOCK_SIZE 1000     //Number of messages to process in parallel

#endif //SENSORSIM_COMMON_CUH
