//
// Created by alex on 7/27/20.
//

#ifndef SENSORSIM_UTIL_CUH
#define SENSORSIM_UTIL_CUH

#ifdef DEBUG_BUILD
#  define DEBUG(x) cerr << x
#else
#  define DEBUG(x) do {} while (0)
#endif

#endif //SENSORSIM_UTIL_CUH
