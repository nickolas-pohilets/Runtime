#include "CRuntime.h"

extern struct SwiftProtocolDescriptor $sSHMp;
extern bool $s7Runtime18equalityHelperImplySbSPyxG_ACtSHRzlF(void const * lhs, void const * rhs, void const * type, void const * hashableWitnessTable);


void const * _Nonnull runtime_getHashableProtocolDescriptor() {
	return &$sSHMp;
}

bool runtime_equalityHelper(void const * lhs, void const * rhs, void const * type, void const * hashableWitnessTable) {
	return $s7Runtime18equalityHelperImplySbSPyxG_ACtSHRzlF(lhs, rhs, type, hashableWitnessTable);
}
