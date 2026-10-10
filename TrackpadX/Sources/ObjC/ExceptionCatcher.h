#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// ObjC 异常捕获垫片：Swift 无法 catch ObjC 异常（如 NSTouch.normalizedPosition
/// 对 Universal Control 间接触摸抛出的 NSInternalInconsistencyException），
/// 统一经此包装兜住。
FOUNDATION_EXPORT void txCatchObjCException(void (NS_NOESCAPE ^tryBlock)(void),
                                            void (^catchHandler)(NSException * _Nonnull exception));

NS_ASSUME_NONNULL_END
