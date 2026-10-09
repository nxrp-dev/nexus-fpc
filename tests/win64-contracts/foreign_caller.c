/* Copyright (c) 2026 Kevin Collins.

This Source Code Form is subject to the terms of the Mozilla Public
License, v. 2.0. If a copy of the MPL was not distributed with this
file, You can obtain one at https://mozilla.org/MPL/2.0/.

This Source Code Form is "Incompatible With Secondary Licenses",
as defined by the Mozilla Public License, v. 2.0.

SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
*/
/* Clang emits this CRT marker when floating-point expressions are present. */
int _fltused = 0;
typedef unsigned long DWORD;
typedef unsigned long long SIZE_T;
typedef long long I64;
typedef void *HANDLE;
typedef int BOOL;
#define IMPORT __declspec(dllimport)
IMPORT char *GetCommandLineA(void);
IMPORT HANDLE LoadLibraryA(const char *);
IMPORT void *GetProcAddress(HANDLE, const char *);
IMPORT BOOL FreeLibrary(HANDLE);
IMPORT void *VirtualAlloc(void *, SIZE_T, DWORD, DWORD);
IMPORT BOOL VirtualFree(void *, SIZE_T, DWORD);
IMPORT HANDLE CreateEventA(void *, BOOL, BOOL, const char *);
IMPORT BOOL SetEvent(HANDLE);
IMPORT DWORD WaitForSingleObject(HANDLE, DWORD);
IMPORT HANDLE CreateThread(void *, SIZE_T, DWORD (*)(void *), void *, DWORD, DWORD *);
IMPORT BOOL CloseHandle(HANDLE);
IMPORT HANDLE GetStdHandle(DWORD);
IMPORT BOOL WriteFile(HANDLE, const void *, DWORD, DWORD *, void *);
IMPORT __declspec(noreturn) void ExitProcess(DWORD);
struct pair { I64 first, second; };
struct module { HANDLE handle; I64 (*exchange)(I64); int final_order; };
static struct module modules[2];
static HANDLE start_event, ready_event;
static void write(const char *message) {
    DWORD length = 0, written;
    while (message[length]) ++length;
    WriteFile(GetStdHandle((DWORD)-11), message, length, &written, 0);
}
static void write_address(HANDLE address) {
    const char digits[] = "0123456789abcdef";
    char text[19];
    text[0] = '0'; text[1] = 'x'; text[18] = 0;
    for (int i = 0; i < 16; ++i) text[17-i] = digits[((SIZE_T)address >> (i*4)) & 15];
    write(text);
}
static void require(int condition, const char *message) {
    if (!condition) { write("FAIL "); write(message); write("\r\n"); ExitProcess(1); }
}
static void *symbol(HANDLE module, const char *name) {
    void *result = GetProcAddress(module, name);
    require(result != 0, name);
    return result;
}
static I64 callback(I64 value) { return value * 7; }
static DWORD worker(void *parameter) {
    I64 value = (I64)parameter;
    SetEvent(ready_event);
    require(WaitForSingleObject(start_event, 10000) == 0, "worker start timeout");
    for (int i = 0; i < 2; ++i) {
        require(modules[i].exchange(value+i) == 0, "foreign thread TLS initially zero");
        require(modules[i].exchange(value+i+10) == value+i, "foreign thread TLS retains value");
    }
    return 0;
}
/* Controlled child argument; no CRT is linked into this host. */
static int pointer_case(void) {
    const char *command = GetCommandLineA();
    const char prefix[] = "--pointer-case=";
    for (; *command; ++command) {
        int i = 0;
        while (prefix[i] && command[i] == prefix[i]) ++i;
        if (!prefix[i]) {
            int value = 0;
            command += i;
            while (*command >= '0' && *command <= '9') {
                value = value * 10 + *command++ - '0';
                require(value <= 10, "pointer child case range");
            }
            require(value >= 1, "pointer child case range");
            return value;
        }
    }
    return 0;
}
void mainCRTStartup(void) {
    void *preferred = (void *)0x180000000ULL;
    void *reservation = VirtualAlloc(preferred, 0x1000000, 0x2000, 1);
    require(reservation == preferred, "reserve preferred DLL base");
    int invalid_case = pointer_case();
    if (invalid_case) {
        HANDLE pointer_module = LoadLibraryA("nxPointerLibrary.dll");
        require(pointer_module != 0 && pointer_module != preferred, "load relocated pointer child DLL");
        int (*validate_pointers)(void *) = symbol(pointer_module, "ValidatePointers");
        require(validate_pointers(&modules[0].final_order) == 1, "pointer child positive control");
        write("PASS pointer child DLL relocated to "); write_address(pointer_module); write("\r\n");
        int (*reject_pointer)(int) = symbol(pointer_module, "RejectPointer");
        reject_pointer(invalid_case);
        require(0, "invalid DLL pointer check unexpectedly returned");
    }
    start_event = CreateEventA(0, 1, 0, 0);
    ready_event = CreateEventA(0, 0, 0, 0);
    require(start_event && ready_event, "create thread barriers");
    /* The worker must predate DLL loading and wait while the loader progresses:
       this exercises foreign-thread lazy TLS without DLL_THREAD_ATTACH. */
    HANDLE before = CreateThread(0, 0, worker, (void *)100, 0, 0);
    require(before != 0, "create pre-load foreign thread");
    require(WaitForSingleObject(ready_event, 10000) == 0, "pre-load thread ready");
    const char *names[2] = {"nxContractOne.dll", "nxContractTwo.dll"};
    for (int i = 0; i < 2; ++i) {
        struct module *m = &modules[i];
        m->handle = LoadLibraryA(names[i]);
        require(m->handle != 0, "load relocated Pascal DLL");
        require(m->handle != preferred, "DLL actually relocated");
        write(names[i]); write(" relocated from "); write_address(preferred);
        write(" to "); write_address(m->handle); write("\r\n");
        int (*storage)(void) = symbol(m->handle, "StaticStorage");
        require(storage() == i+1, "DLL static/BSS/resource/module initialization");
        require(GetProcAddress(m->handle, (const char *)7) == (void *)storage, "ordinal export");
        I64 *exported = symbol(m->handle, "ExportedValue");
        require(*exported == 123456789, "data export");
        double (*mixed)(I64,double,I64,double,I64) = symbol(m->handle, "MixedArguments");
        require(mixed(11,2.5,13,4.5,17) == 158.0, "mixed registers and stack argument ABI");
        struct pair (*pair_result)(I64) = symbol(m->handle, "PairResult");
        struct pair pair = pair_result(91);
        require(pair.first == 91 && pair.second == 108, "aggregate return ABI");
        I64 (*invoke)(I64 (*)(I64),I64) = symbol(m->handle, "InvokeCallback");
        require(invoke(callback, 9) == 64, "Pascal to C callback ABI");
        int (*unwind)(void) = symbol(m->handle, "ExceptionUnwind");
        require(unwind() == 1, "DLL exception finally unwinding");
        void (*set_final)(int *) = symbol(m->handle, "SetFinalDestination");
        set_final(&m->final_order);
        m->exchange = symbol(m->handle, "ExchangeThread");
        require(m->exchange(500+i) == 0, "main thread TLS initially zero");
    }
    HANDLE after = CreateThread(0, 0, worker, (void *)200, 0, 0);
    require(after != 0, "create post-load foreign thread");
    require(WaitForSingleObject(ready_event, 10000) == 0, "post-load thread ready");
    require(SetEvent(start_event), "release workers");
    require(WaitForSingleObject(before, 10000) == 0, "pre-load thread exit");
    require(WaitForSingleObject(after, 10000) == 0, "post-load thread exit");
    CloseHandle(before); CloseHandle(after);
    for (int i = 0; i < 2; ++i) {
        require(modules[i].exchange(0) == 500+i, "thread and module TLS isolation");
        require(FreeLibrary(modules[i].handle), "unload DLL");
        require(modules[i].final_order == 21, "reverse DLL unit finalization");
    }
    for (int i = 0; i < 2; ++i) {
        struct module *m = &modules[i];
        m->final_order = 0;
        m->handle = LoadLibraryA(names[i]);
        require(m->handle != 0 && m->handle != preferred, "reload relocated DLL");
        int (*storage)(void) = symbol(m->handle, "StaticStorage");
        require(storage() == i+1, "reload resets static storage and initialization");
        m->exchange = symbol(m->handle, "ExchangeThread");
        require(m->exchange(0) == 0, "reload resets module TLS");
        void (*set_final)(int *) = symbol(m->handle, "SetFinalDestination");
        set_final(&m->final_order);
        require(FreeLibrary(m->handle), "unload reloaded DLL");
        require(m->final_order == 21, "reloaded DLL finalization");
    }
    CloseHandle(start_event); CloseHandle(ready_event);
    HANDLE pointer_module = LoadLibraryA("nxPointerLibrary.dll");
    require(pointer_module != 0 && pointer_module != preferred, "load relocated HeapTrc DLL");
    int (*validate_pointers)(void *) = symbol(pointer_module, "ValidatePointers");
    require(validate_pointers(&modules[0].final_order) == 1, "DLL HeapTrc static storage and cross-module data");
    require(FreeLibrary(pointer_module), "unload HeapTrc DLL");
    write("PASS HeapTrc pointer classification in relocated DLL, including foreign EXE static data\r\n");
    require(VirtualFree(reservation, 0, 0x8000), "release reservation");
    write("PASS C caller: relocation, module storage/resources, TLS, ABI, exports, exceptions, finalization\r\n");
    ExitProcess(0);
}
