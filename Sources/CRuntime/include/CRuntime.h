#ifndef cruntime_h
#define cruntime_h

#import <stdbool.h>

const void * _Nullable swift_getTypeByMangledNameInContext(
                        const char * _Nullable typeNameStart,
                        int typeNameLength,
                        const void * _Nullable context,
                        const void * _Nullable const * _Nullable genericArgs);

const void * _Nullable swift_getTypeByMangledNameInEnvironment(
                        const char * _Nullable typeNameStart,
                        int typeNameLength,
                        const void * _Nullable environment,
                        const void * _Nullable const * _Nullable genericArgs);

const void * _Nullable swift_allocObject(
                    const void * _Nullable type,
                    int requiredSize,
                    int requiredAlignmentMask);

void const * _Nullable swift_conformsToProtocol(void const * _Nonnull type, void const * _Nonnull protocol);

void const * _Nonnull runtime_getHashableProtocolDescriptor();
bool runtime_equalityHelper(
                    void const * _Nonnull lhs,
                    void const * _Nonnull rhs,
                    void const * _Nonnull type,
                    void const * _Nonnull hashableWitnessTable);



#endif
