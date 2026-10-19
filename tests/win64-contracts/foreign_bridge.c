/* Copyright (c) 2026 Kevin Collins.
SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
*/
typedef void (*callback)(void);
__declspec(noinline) void NXForeignFrame(callback invoke) {
    volatile unsigned long long stack[8] = {1,2,3,4,5,6,7,8};
    invoke();
    stack[0] += stack[7];
}
