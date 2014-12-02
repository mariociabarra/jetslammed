/* jetslammed) - Ability to adjust jetsam memory limits for iOS tweaks
 *
 * From within the target process (ie, SpringBoard), use:
 *      jetslammed_updateWaterMark(350, "mytweakname");
 *
 * Default watermark levels are in /System/Library/LaunchDaemons/com.apple.jetsamproperties.<device id>.plist
 *  ie, com.apple.SpringBoard on iOS 8 for iPhone6 is JetsamMemoryLimit=240
 *
 * Copyright (C) 2014 @mariociabarra
*/

/* GNU Lesser General Public License, Version 3 {{{ */
/* This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
**/
/* }}} */

#include <Foundation/Foundation.h>

#include <sys/socket.h>
#include <sys/un.h>

#include "Debug.h"
#include "jetslammed.h"
#include "jetslammed_private.h"

static int maxRequestedWatermark;
static char maxRequestor[MAX_REQUEST_NAME];

#define SOCK_PATH "/var/tmp/jetslammed.sock"

int jetslammed_updateWaterMarkForPID(int highWatermarkMB, char* requester, int pid);

extern int jetslammed_updateWaterMark(int highWatermarkMB, char* requester)
{
    return jetslammed_updateWaterMarkForPID(highWatermarkMB, requester, getpid());
}

int sendDaemon(int highWatermarkMB, char* requester, int pid)
{
    // write to daemon
    struct sockaddr_un addr;
    int fd,rc;

    if ( (fd = socket(AF_UNIX, SOCK_STREAM, 0)) == -1)
    {
        NSLog(@"jetslammed: socket error");
        return -1;
    }

    memset(&addr, 0, sizeof(addr));
    addr.sun_family = AF_UNIX;
    strncpy(addr.sun_path, SOCK_PATH, sizeof(addr.sun_path)-1);

    if (connect(fd, (struct sockaddr*)&addr, sizeof(addr)) == -1)
    {
        NSLog(@"jetslammed: socket connect error");
        return -1;
    }

    struct JetslammedRequest jetslamRequest;
    jetslamRequest.magic = kJetslammedMagic;
    jetslamRequest.pid = pid;
    jetslamRequest.memorySize = highWatermarkMB;
    strncpy(jetslamRequest.requestor, requester, MAX_REQUEST_NAME-1);
    int writeLength = write(fd, &jetslamRequest, sizeof(jetslamRequest));
    if (writeLength != sizeof(jetslamRequest))
    {
      if (writeLength > 0)
        NSLog(@"jetslammed: partial write: %d", writeLength);
      else
      {
        NSLog(@"jetslammed: write error");
      }
    }
    else
        DEBUG_MSG(@"jetslammed: Sent command to daemon");
    close(fd);
    return 0;
}

int jetslammed_updateWaterMarkForPID(int highWatermarkMB, char* requester, int pid)
{
    if (highWatermarkMB < 1)
    {
        NSLog(@"jetslammed: high watermark requested below 1 (%d) ", highWatermarkMB);
        return -3;
    }
    else if (highWatermarkMB > 1024)
    {
        NSLog(@"jetslammed: high watermark is in MB. %d too high", highWatermarkMB);
        return -2;
    }
    else if (highWatermarkMB < maxRequestedWatermark)
    {
        NSLog(@"jetslammed: not updating high watermark to %d, previous requestor %s already updated to %d mb", highWatermarkMB, maxRequestor, maxRequestedWatermark);
    }
    else
    {
        if (sendDaemon(highWatermarkMB, requester, pid) == 0)
        {
            strncpy(maxRequestor, requester, MAX_REQUEST_NAME-1);
            maxRequestedWatermark = highWatermarkMB;
        }
    }

    return 0;
}
