#include <rfb/rfbclient.h>

#include "cdecl.h"

cdecl_struct(z_stream_s)
cdecl_struct(rfbClientData)
cdecl_type(rfbClient)
cdecl_type(rfbBool)
cdecl_struct(_rfbClient)
cdecl_func(rfbGetClient)
cdecl_func(rfbInitClient)
cdecl_func(rfbClientLog)
cdecl_func(SendKeyEvent)
cdecl_func(SendPointerEvent)
cdecl_func(SendFramebufferUpdateRequest)
cdecl_func(SendIncrementalFramebufferUpdateRequest)
cdecl_func(SendScaleSetting)
cdecl_func(SetFormatAndEncodings)
cdecl_func(rfbClientCleanup)
cdecl_func(HandleRFBServerMessage)
