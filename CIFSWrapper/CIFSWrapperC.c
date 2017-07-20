//
//  CIFSWrapperC.c
//  CIFSWrapperSample
//
//  Created by Atsushi Tanaka on 2015/11/15.
//

#include "CIFSWrapperC.h"

#include <stdbool.h>
#include "talloc_stack.h"

void cifswrapper_PurgeCachedServers(SMBCCTX* ctx)
{
    // fixes warning: no talloc stackframe at libsmb/cliconnect.c:2637, leaking memory
    TALLOC_CTX *frame = talloc_stackframe();
    smbc_getFunctionPurgeCachedServers(ctx)(ctx);
    TALLOC_FREE(frame);
}
