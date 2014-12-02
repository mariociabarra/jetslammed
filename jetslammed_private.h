
#include <signal.h>


#define MAX_REQUEST_NAME 1024

// Client/Daemon
#define SOCK_PATH "/var/tmp/jetslammed.sock"

enum {
    kJetslammedMagic = 'jsla'
};


struct JetslammedRequest {
    OSType          magic;                          // must be kJetslammedMagic
    int             memorySize;
    char            requestor[MAX_REQUEST_NAME];
    pid_t           pid;
};

