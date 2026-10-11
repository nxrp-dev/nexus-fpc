/* Copyright (c) 2026 Kevin Collins. SPDX-License-Identifier: GPL-2.0-or-later */
/* No CRT dependencies: this DLL exercises the Microsoft C ABI directly. */
int _fltused = 0;
__declspec(dllexport) double call_callback(double (*callback)(double), double value) {
    return callback(value);
}
__declspec(dllexport) double variadic_sum(int count, ...) {
    __builtin_va_list args;
    __builtin_va_start(args, count);
    double result = 0;
    for (int i = 0; i < count; ++i) result += __builtin_va_arg(args, double);
    __builtin_va_end(args);
    return result;
}
