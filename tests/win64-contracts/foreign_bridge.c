/* Copyright (c) 2026 Kevin Collins.

This Source Code Form is subject to the terms of the Mozilla Public
License, v. 2.0. If a copy of the MPL was not distributed with this
file, You can obtain one at https://mozilla.org/MPL/2.0/.

This Source Code Form is "Incompatible With Secondary Licenses",
as defined by the Mozilla Public License, v. 2.0.

SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
*/
typedef void (*callback)(void);
__declspec(noinline) void NXForeignFrame(callback invoke) {
    volatile unsigned long long stack[8] = {1,2,3,4,5,6,7,8};
    invoke();
    stack[0] += stack[7];
}
