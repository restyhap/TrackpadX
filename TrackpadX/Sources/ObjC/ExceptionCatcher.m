#import "ExceptionCatcher.h"

void txCatchObjCException(void (NS_NOESCAPE ^tryBlock)(void),
                          void (^catchHandler)(NSException * _Nonnull exception)) {
    @try {
        tryBlock();
    } @catch (NSException *exception) {
        catchHandler(exception);
    }
}
