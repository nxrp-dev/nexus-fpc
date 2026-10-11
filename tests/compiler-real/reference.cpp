// Copyright (c) 2026 Kevin Collins. SPDX-License-Identifier: GPL-2.0-or-later
// Independent test oracle; Boost is not a compiler build dependency.
#define BOOST_MP_STANDALONE
#include <boost/multiprecision/cpp_bin_float.hpp>
#include <iostream>
#include <iomanip>
#include <random>
#include <cstdint>
using namespace boost::multiprecision;
using Ref = number<cpp_bin_float<256, digit_base_2>>;
using WideRef = number<cpp_bin_float<17024, digit_base_2>>;

template<class F> void emit(unsigned op, uint16_t exp, uint64_t sig) {
    F x = ldexp(F(sig), (exp & 0x7fff ? int(exp & 0x7fff)-16383 : -16382)-63);
    if (exp & 0x8000) x = -x;
    F y;
    switch (op) {
    case 0: y=sin(x); break;
    case 1: y=cos(x); break;
    case 2: y=atan(x); break;
    case 3: y=log(x); break;
    default: y=boost::multiprecision::exp(x); break;
    }
    uint16_t outExp = y < 0 ? 0x8000 : 0;
    y = abs(y);
    int e=0;
    frexp(y,&e);
    F scaled=ldexp(y, 63-std::max(e-1,-16382));
    F integer=floor(scaled), fraction=scaled-integer;
    if (fraction>F(0.5) || (fraction==F(0.5) && fmod(integer,F(2))!=0)) ++integer;
    if (integer>=ldexp(F(1),64)) { integer/=2; ++e; }
    uint64_t outSig=integer.template convert_to<uint64_t>();
    if (e>16384) { outExp|=0x7fff; outSig=UINT64_C(0x8000000000000000); }
    else if (outSig>=UINT64_C(0x8000000000000000)) outExp|=std::max(e+16382,1);
    std::cout << std::dec << op << ' ' << std::hex << exp << ' ' << sig
              << ' ' << outExp << ' ' << outSig << '\n';
}

int main() {
    std::mt19937_64 rng(0x51f80);
    for (unsigned op=0; op<5; ++op)
        for (int i=0; i<512; ++i) {
            int e;
            if (op==4) e=int(rng()%30)-16;
            else if (op<2) e=int(rng()%180)-90;
            else e=int(rng()%32765)-16382;
            uint16_t exp=e+16383;
            if (op!=3 && (rng()&1)) exp|=0x8000;
            emit<Ref>(op,exp,rng()|UINT64_C(0x8000000000000000));
        }
    for (unsigned op=0; op<5; ++op) {
        emit<Ref>(op,0,1);
        emit<Ref>(op,0,UINT64_C(0x7fffffffffffffff));
        emit<Ref>(op,1,UINT64_C(0x8000000000000000));
        emit<Ref>(op,0x3fff,UINT64_C(0x8000000000000001));
        emit<Ref>(op,0x3ffe,UINT64_C(0xffffffffffffffff));
    }
    // These inputs require more than 16384 bits of argument reduction.
    for (int i=0; i<16; ++i)
        for (unsigned op=0; op<2; ++op)
            emit<WideRef>(op,0x7ffe-i*997,rng()|UINT64_C(0x8000000000000000));
}
