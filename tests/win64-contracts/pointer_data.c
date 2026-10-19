/* Copyright (c) 2026 Kevin Collins.
SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
*/
const unsigned char NXReadOnlyData[17] = {73,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,99};
#pragma section(".nxguard", read, write)
__declspec(allocate(".nxguard")) unsigned char NXProtectedData[4096] = {5};
