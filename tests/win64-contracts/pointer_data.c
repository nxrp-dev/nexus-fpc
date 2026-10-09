/* Copyright (c) 2026 Kevin Collins.

This Source Code Form is subject to the terms of the Mozilla Public
License, v. 2.0. If a copy of the MPL was not distributed with this
file, You can obtain one at https://mozilla.org/MPL/2.0/.

This Source Code Form is "Incompatible With Secondary Licenses",
as defined by the Mozilla Public License, v. 2.0.

SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
*/
const unsigned char NXReadOnlyData[17] = {73,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,99};
#pragma section(".nxguard", read, write)
__declspec(allocate(".nxguard")) unsigned char NXProtectedData[4096] = {5};
