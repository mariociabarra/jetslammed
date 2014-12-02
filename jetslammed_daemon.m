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
#include <mach/mach.h>
#include <mach/task.h>

#include <sys/sysctl.h>
#include <signal.h>

#include <sys/socket.h>
#include <sys/un.h>
#include <netinet/in.h>
#include <fcntl.h>
#include <unistd.h>
#include <sys/stat.h>
#include <launch.h>

#include "kern_memorystatus.h"
#include "jetslammed.h"
#include "jetslammed_private.h"
#include "Debug.h"


#define MAX_PROCESS_NAME 100

static void getProcessName(pid_t pid, char* processName)
{
    uint32_t i;
    size_t length;
    processName[0] = '\0';
    int32_t err, count;
    struct kinfo_proc* process_buffer;
    struct kinfo_proc* kp;
    int mib[ 3 ] = { CTL_KERN, KERN_PROC, KERN_PROC_ALL };
    int loop;

    sysctl(mib, 3, NULL, &length, NULL, 0);

    if (length == 0)
        return;

    process_buffer = (struct kinfo_proc *)malloc(length);

    for ( i = 0; i < 10; ++i )
    {
        // in the event of inordinate system load, transient sysctl() failures are
        // possible.  retry for up to one minute if necessary.
        if ( ! ( err = sysctl( mib, 3, process_buffer, &length, NULL, 0 ) ) ) break;
        sleep( 1 );
    }

    if(err)
    {
        free(process_buffer);
        return;
    }

    count = length / sizeof(struct kinfo_proc);
    kp = process_buffer;

    for(loop = 0; loop < count; loop++)
    {
        if(kp->kp_proc.p_pid == pid)
        {
            strncpy(processName, kp->kp_proc.p_comm, MAX_PROCESS_NAME-1);
            break;
        }
        kp++;
    }

    free(process_buffer);
    return;
}

static memorystatus_priority_entry_t *get_priority_list(int *size)
{
    memorystatus_priority_entry_t *list = NULL;

    *size = memorystatus_control(MEMORYSTATUS_CMD_GET_PRIORITY_LIST, 0, 0, NULL, 0);
    if ( *size <= 0)
    {
        NSLog(@"Can't get list size: %d!", *size);
        goto exit;
    }

    list = (memorystatus_priority_entry_t*)malloc( *size);
    if (!list)
    {
        NSLog(@"Can't allocate list!");
        goto exit;
    }

    *size = memorystatus_control(MEMORYSTATUS_CMD_GET_PRIORITY_LIST, 0, 0, list, *size);
    if ( *size <= 0)
    {
        NSLog(@"Can't retrieve list!");
        goto exit;
    }

exit:
    return list;
}

extern int getCurrentHighwatermark(int pid)
{
    memorystatus_priority_entry_t *entries = NULL;
    int size;
    int64_t currentWater = -1;

    entries = get_priority_list(&size);
    if (!entries)
    {
        goto exit;
    }

    /* Locate */
    for (int i = 0; i < size/sizeof(memorystatus_priority_entry_t); i++ )
    {
        if (entries[i].pid == pid) {
            currentWater = entries[i].limit;
            break;
        }
    }

    free(entries);

exit:
    return (int) currentWater;
}

int jetslammed_updateWaterMarkForPID(int highWatermarkMB, char* requester, int pid)
{
    int response = -1;
    char processName[MAX_PROCESS_NAME];
    getProcessName(pid, processName);

    if (highWatermarkMB > getCurrentHighwatermark(pid))
    {
        if ((response = memorystatus_control(MEMORYSTATUS_CMD_SET_JETSAM_HIGH_WATER_MARK, pid, highWatermarkMB, 0, 0)) != 0)
        {
            NSLog(@"Error setting high watermark to %d (%d) for %s by \"%s\"", highWatermarkMB, response, processName, requester);
        }
        else
        {
            NSLog(@"Updated high watermark to %d for %s by \"%s\"", highWatermarkMB, processName, requester);
        }
    }
    else
    {
        NSLog(@"Process watermark was %d - won't set to (%d) for %s by \"%s\"", getCurrentHighwatermark(pid), highWatermarkMB, processName, requester);
    }

    return response;
}

static void SocketReadCallback(CFSocketRef s, CFSocketCallBackType type, CFDataRef address, const void* data, void *info)
{
    int length = CFDataGetLength((CFDataRef)data);
    struct JetslammedRequest* jetslamRequest;
    if (length == sizeof(struct JetslammedRequest))
    {
        jetslamRequest = (struct JetslammedRequest *) CFDataGetBytePtr((CFDataRef)data);
        if (jetslamRequest->magic == kJetslammedMagic)
        {
            jetslammed_updateWaterMarkForPID(jetslamRequest->memorySize, jetslamRequest->requestor, jetslamRequest->pid);
        }
        else
            DEBUG_MSG(@"****** DATA ERROR");
    }
    else
        DEBUG_MSG(@"****** invalid data length %d (%d)", length,  (int)sizeof(struct JetslammedRequest) );
}


void SocketAcceptCallback(CFSocketRef s, CFSocketCallBackType type, CFDataRef address, const void *data, void *info)
{
    DEBUG_MSG(@"Incoming connection");

    CFSocketNativeHandle csock = *(CFSocketNativeHandle *)data;
    CFSocketRef sn = CFSocketCreateWithNative(NULL, csock, kCFSocketDataCallBack, SocketReadCallback, NULL);
    CFRunLoopSourceRef source = CFSocketCreateRunLoopSource(NULL, sn, 0);
    CFRunLoopAddSource(CFRunLoopGetCurrent(), source, kCFRunLoopDefaultMode);
    CFRelease(source);
    CFRelease(sn);
}

int main(int argc, char** argv)
{
    NSLog(@"Initializing...");
    int sock;
    CFSocketRef listenerCF;

    launch_data_t sockets_dict, checkin_request, launch_dict, listening_fd_array;

    checkin_request = launch_data_new_string(LAUNCH_KEY_CHECKIN);
    launch_dict = launch_msg(checkin_request);
    launch_data_free(checkin_request);

    if(launch_dict == NULL)
    {
        NSLog(@"launchd checkin failed!");
        exit(1);
    }

    launch_data_t socketsDict = launch_data_dict_lookup(launch_dict,LAUNCH_JOBKEY_SOCKETS);
    if (socketsDict == NULL)
    {
        NSLog(@"No socket dict!");
        exit(1);
    }

    launch_data_t fdArray = launch_data_dict_lookup(socketsDict, "ListenerSocket");
    if (fdArray == NULL)
    {
        NSLog(@"No socket data!");
        exit(1);
    }
    launch_data_t  fdData = launch_data_array_get_index(fdArray, 0);
    if (fdData == NULL)
    {
        NSLog(@"No socket data array!");
        exit(1);
    }

    sock = launch_data_get_fd(fdData);

    launch_data_free(launch_dict);

    if (sock >= 0)
    {
        listenerCF = CFSocketCreateWithNative(NULL, (CFSocketNativeHandle) sock, kCFSocketAcceptCallBack, SocketAcceptCallback, NULL);
        CFRunLoopSourceRef source = CFSocketCreateRunLoopSource(NULL, listenerCF, 0);
        CFRunLoopAddSource(CFRunLoopGetCurrent(), source, kCFRunLoopDefaultMode);
        CFRelease(source);
        NSLog(@"Listening...");
        CFRunLoopRun();
        CFSocketInvalidate(listenerCF);
        CFRelease(listenerCF);
    }
    else
    {
        NSLog(@"Invalid socket from launchd");
    }
    return 0;
}