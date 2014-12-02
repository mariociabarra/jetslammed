#ifndef DEBUG_H
#define DEBUG_H
#include <syslog.h>

static __attribute__((unused)) void* DebugVar;

#ifdef DEBUG
#ifdef FOUNDATION_EXTERN
#define DEBUG_MSG(...) NSLog(__VA_ARGS__)
#define DEBUG_MSG_SIDEEFFECT(...) NSLog(__VA_ARGS__)
#else
#include <syslog.h>
#define DEBUG_MSG(...) syslog(LOG_ERR, __VA_ARGS__)
#define DEBUG_MSG_SIDEEFFECT(...) syslog(LOG_ERR, __VA_ARGS__)
#endif
#define print_call(a) syslog(LOG_ERR, #a " = %d\n", a)
#else
#define DEBUG_MSG(...)
#define DEBUG_MSG_SIDEEFFECT(message, ...) (__VA_ARGS__)
#define print_call(a) a
#endif

#endif
