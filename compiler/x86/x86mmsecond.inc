in_x86_movss
,in_x86_movapd
,in_x86_movhpd
,in_x86_movlpd
,in_x86_movupd
,in_x86_movsd_from_mem
,in_x86_movd_from_mem
,in_x86_pmovsxbd_from_mem
,in_x86_pmovzxbd_from_mem
,in_x86_pmovsxwq_from_mem
,in_x86_pmovzxwq_from_mem
: //out r0:xmm;r1:ptr32;
  begin
    case InlineNumber of
      in_x86_pmovzxwq_from_mem: begin lOp:=A_pmovzxwq end;
      in_x86_pmovsxwq_from_mem: begin lOp:=A_pmovsxwq end;
      in_x86_pmovzxbd_from_mem: begin lOp:=A_pmovzxbd end;
      in_x86_pmovsxbd_from_mem: begin lOp:=A_pmovsxbd end;
      in_x86_movd_from_mem: begin lOp:=A_movd end;
      in_x86_movsd_from_mem: begin lOp:=A_movsd end;
      in_x86_movupd: begin lOp:=A_movupd end;
      in_x86_movlpd: begin lOp:=A_movlpd end;
      in_x86_movhpd: begin lOp:=A_movhpd end;
      in_x86_movapd: begin lOp:=A_movapd end;
      in_x86_movss: begin lOp:=A_movss; end;
      else
        InternalError(2020010201);
    end;

    GetParameters(1);

    for lIndex := 1 to 1 do SecondPass(lParaArray[lIndex]);

    LocationMakeRef(lParaArray[1].Location);
    Location_Reset(Location,LOC_MMREGISTER,OS_M128);
    Location.Register:=cg.GetMMRegister(CurrentAsmData.CurrAsmList, OS_M128);
    CurrentAsmData.CurrAsmList.concat(TAICPU.op_ref_reg(lOp,S_NO,lParaArray[1].Location.Reference,Location.Register));
  end;
in_x86_movaps
,in_x86_movups
,in_x86_sqrtpd_from_mem
,in_x86_movdqa_from_mem
,in_x86_movdqu_from_mem
,in_x86_movsldup_from_mem
,in_x86_movshdup_from_mem
,in_x86_lddqu
,in_x86_pabsb_from_mem
,in_x86_pabsw_from_mem
,in_x86_pabsd_from_mem
,in_x86_movntdqa
: //out r0:xmm;r1:ptr128;
  begin
    case InlineNumber of
      in_x86_movntdqa: begin lOp:=A_movntdqa end;
      in_x86_pabsd_from_mem: begin lOp:=A_pabsd end;
      in_x86_pabsw_from_mem: begin lOp:=A_pabsw end;
      in_x86_pabsb_from_mem: begin lOp:=A_pabsb end;
      in_x86_lddqu: begin lOp:=A_lddqu end;
      in_x86_movshdup_from_mem: begin lOp:=A_movshdup end;
      in_x86_movsldup_from_mem: begin lOp:=A_movsldup end;
      in_x86_movdqu_from_mem: begin lOp:=A_movdqu end;
      in_x86_movdqa_from_mem: begin lOp:=A_movdqa end;
      in_x86_sqrtpd_from_mem: begin lOp:=A_sqrtpd end;
      in_x86_movups: begin lOp:=A_movups end;
      in_x86_movaps: begin lOp:=A_movaps; end;
      else
        InternalError(2020010201);
    end;

    GetParameters(1);

    for lIndex := 1 to 1 do SecondPass(lParaArray[lIndex]);

    LocationMakeRef(lParaArray[1].Location);
    Location_Reset(Location,LOC_MMREGISTER,OS_M128);
    Location.Register:=cg.GetMMRegister(CurrentAsmData.CurrAsmList, OS_M128);
    CurrentAsmData.CurrAsmList.concat(TAICPU.op_ref_reg(lOp,S_NO,lParaArray[1].Location.Reference,Location.Register));
  end;
in_x86_movss_to_mem
,in_x86_movapd_to_mem
,in_x86_movntpd_to_mem
,in_x86_movhpd_to_mem
,in_x86_movlpd_to_mem
,in_x86_movupd_to_mem
,in_x86_movsd_to_mem
,in_x86_movd_to_mem
: //r0:ptr32;r1:xmm;
  begin
    case InlineNumber of
      in_x86_movd_to_mem: begin lOp:=A_movd end;
      in_x86_movsd_to_mem: begin lOp:=A_movsd end;
      in_x86_movupd_to_mem: begin lOp:=A_movupd end;
      in_x86_movlpd_to_mem: begin lOp:=A_movlpd end;
      in_x86_movhpd_to_mem: begin lOp:=A_movhpd end;
      in_x86_movntpd_to_mem: begin lOp:=A_movntpd end;
      in_x86_movapd_to_mem: begin lOp:=A_movapd end;
      in_x86_movss_to_mem: begin lOp:=A_movss; end;
      else
        InternalError(2020010201);
    end;

    GetParameters(2);

    for lIndex := 1 to 2 do SecondPass(lParaArray[lIndex]);

    LocationMakeRef(lParaArray[1].Location);
    Location_Force_MMReg(CurrentAsmData.CurrAsmList, lParaArray[2].Location, true);
    CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_ref(lOp,S_NO,lParaArray[2].Location.Register,lParaArray[1].Location.Reference));
  end;
in_x86_movaps_to_mem
,in_x86_movups_to_mem
,in_x86_movdqa
,in_x86_movdqu
,in_x86_movntdq
: //r0:ptr128;r1:xmm;
  begin
    case InlineNumber of
      in_x86_movntdq: begin lOp:=A_movntdq end;
      in_x86_movdqu: begin lOp:=A_movdqu end;
      in_x86_movdqa: begin lOp:=A_movdqa end;
      in_x86_movups_to_mem: begin lOp:=A_movups end;
      in_x86_movaps_to_mem: begin lOp:=A_movaps; end;
      else
        InternalError(2020010201);
    end;

    GetParameters(2);

    for lIndex := 1 to 2 do SecondPass(lParaArray[lIndex]);

    LocationMakeRef(lParaArray[1].Location);
    Location_Force_MMReg(CurrentAsmData.CurrAsmList, lParaArray[2].Location, true);
    CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_ref(lOp,S_NO,lParaArray[2].Location.Register,lParaArray[1].Location.Reference));
  end;
in_x86_movss_to_val
: //out r0:f32;r1:xmm;
  begin
    case InlineNumber of
      in_x86_movss_to_val: begin lOp:=A_movss; end;
      else
        InternalError(2020010201);
    end;

    GetParameters(1);

    for lIndex := 1 to 1 do SecondPass(lParaArray[lIndex]);

    Location_Force_MMReg(CurrentAsmData.CurrAsmList, lParaArray[1].Location, true);
    Location_Reset(Location,LOC_MMREGISTER,OS_M128);
    Location.Register:=cg.GetMMRegister(CurrentAsmData.CurrAsmList, OS_M128);
    CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg(lOp,S_NO,lParaArray[1].Location.Register,Location.Register));
  end;
in_x86_movss_from_val
: //out r0:xmm;r1:f32;
  begin
    case InlineNumber of
      in_x86_movss_from_val: begin lOp:=A_movss; end;
      else
        InternalError(2020010201);
    end;

    GetParameters(1);

    for lIndex := 1 to 1 do SecondPass(lParaArray[lIndex]);

    Location_Force_MMReg(CurrentAsmData.CurrAsmList, lParaArray[1].Location, true);
    Location_Reset(Location,LOC_MMREGISTER,OS_M128);
    Location.Register:=cg.GetMMRegister(CurrentAsmData.CurrAsmList, OS_M128);
    CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg(lOp,S_NO,lParaArray[1].Location.Register,Location.Register));
  end;
in_x86_movlps
,in_x86_movhps
,in_x86_cvtpi2ps_from_mem
,in_x86_maxsd_from_mem
,in_x86_cvtdq2pd_from_mem
,in_x86_cvtpi2pd_from_mem
,in_x86_cvtps2pd_from_mem
,in_x86_cvtsd2ss_from_mem
: //var r0:xmm;r1:ptr64;
  begin
    case InlineNumber of
      in_x86_cvtsd2ss_from_mem: begin lOp:=A_cvtsd2ss end;
      in_x86_cvtps2pd_from_mem: begin lOp:=A_cvtps2pd end;
      in_x86_cvtpi2pd_from_mem: begin lOp:=A_cvtpi2pd end;
      in_x86_cvtdq2pd_from_mem: begin lOp:=A_cvtdq2pd end;
      in_x86_maxsd_from_mem: begin lOp:=A_maxsd end;
      in_x86_cvtpi2ps_from_mem: begin lOp:=A_cvtpi2ps end;
      in_x86_movhps: begin lOp:=A_movhps end;
      in_x86_movlps: begin lOp:=A_movlps; end;
      else
        InternalError(2020010201);
    end;

    GetParameters(2);

    for lIndex := 1 to 2 do SecondPass(lParaArray[lIndex]);

    Location_Force_MMReg(CurrentAsmData.CurrAsmList, lParaArray[1].Location, false);
    LocationMakeRef(lParaArray[2].Location);
    Location:=lParaArray[1].Location;
    CurrentAsmData.CurrAsmList.concat(TAICPU.op_ref_reg(lOp,S_NO,lParaArray[2].Location.Reference,lParaArray[1].Location.Register));
  end;
in_x86_movlps_to_mem
,in_x86_movhps_to_mem
,in_x86_movq_to_mem
: //r0:ptr64;r1:xmm;
  begin
    case InlineNumber of
      in_x86_movq_to_mem: begin lOp:=A_movq end;
      in_x86_movhps_to_mem: begin lOp:=A_movhps end;
      in_x86_movlps_to_mem: begin lOp:=A_movlps; end;
      else
        InternalError(2020010201);
    end;

    GetParameters(2);

    for lIndex := 1 to 2 do SecondPass(lParaArray[lIndex]);

    LocationMakeRef(lParaArray[1].Location);
    Location_Force_MMReg(CurrentAsmData.CurrAsmList, lParaArray[2].Location, true);
    CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_ref(lOp,S_NO,lParaArray[2].Location.Register,lParaArray[1].Location.Reference));
  end;
in_x86_movlhps
,in_x86_movhlps
,in_x86_addps
,in_x86_subps
,in_x86_mulps
,in_x86_divps
,in_x86_rcpps
,in_x86_sqrtps
,in_x86_maxps
,in_x86_minps
,in_x86_rsqrtps
,in_x86_andps
,in_x86_orps
,in_x86_xorps
,in_x86_andnps
,in_x86_unpckhps
,in_x86_unpcklps
,in_x86_addpd
,in_x86_divpd
,in_x86_maxpd
,in_x86_minpd
,in_x86_mulpd
,in_x86_subpd
,in_x86_andpd
,in_x86_andnpd
,in_x86_orpd
,in_x86_xorpd
,in_x86_unpckhpd
,in_x86_unpcklpd
,in_x86_cvtdq2pd
,in_x86_cvtdq2ps
,in_x86_cvtpd2dq
,in_x86_cvtpd2ps
,in_x86_cvtps2dq
,in_x86_cvtps2pd
,in_x86_cvtsd2ss
,in_x86_cvttpd2dq
,in_x86_cvttps2dq
,in_x86_packssdw
,in_x86_packsswb
,in_x86_packuswb
,in_x86_paddb
,in_x86_paddw
,in_x86_paddd
,in_x86_paddq
,in_x86_paddsb
,in_x86_paddsw
,in_x86_paddusb
,in_x86_paddusw
,in_x86_pand
,in_x86_pandn
,in_x86_por
,in_x86_pxor
,in_x86_pcmpeqb
,in_x86_pcmpeqw
,in_x86_pcmpeqd
,in_x86_pcmpgtb
,in_x86_pcmpgtw
,in_x86_pcmpgtd
,in_x86_pmullw
,in_x86_pmulhw
,in_x86_pmulhuw_sse2
,in_x86_pmuludq
,in_x86_psllw_sse2
,in_x86_pslld_sse2
,in_x86_psllq_sse2
,in_x86_psrad_sse2
,in_x86_psraw_sse2
,in_x86_psrlw_sse2
,in_x86_psrld_sse2
,in_x86_psrlq_sse2
,in_x86_psubb
,in_x86_psubw
,in_x86_psubd
,in_x86_psubq
,in_x86_psubsb
,in_x86_psubsw
,in_x86_pmaddwd
,in_x86_psubusb
,in_x86_psubusw
,in_x86_punpckhbw
,in_x86_punpckhwd
,in_x86_punpckhdq
,in_x86_punpcklbw
,in_x86_punpcklwd
,in_x86_punpckldq
,in_x86_pavgb_sse2
,in_x86_pavgw_sse2
,in_x86_pminub_sse2
,in_x86_pminsw_sse2
,in_x86_pmaxsw_sse2
,in_x86_pmaxub_sse2
,in_x86_psadbw_sse2
,in_x86_punpckhqdq
,in_x86_punpcklqdq
,in_x86_addsubps
,in_x86_addsubpd
,in_x86_haddps
,in_x86_haddpd
,in_x86_hsubps
,in_x86_hsubpd
,in_x86_psignb
,in_x86_psignw
,in_x86_psignd
,in_x86_pshufb
,in_x86_pmulhrsw
,in_x86_pmaddubsw
,in_x86_phsubw
,in_x86_phsubsw
,in_x86_phsubd
,in_x86_phaddsw
,in_x86_phaddw
,in_x86_phaddd
,in_x86_phminposuw
,in_x86_pmulld
,in_x86_pmuldq
,in_x86_pminsb
,in_x86_pminuw
,in_x86_pminsd
,in_x86_pminud
,in_x86_pmaxsb
,in_x86_pmaxuw
,in_x86_pmaxsd
,in_x86_pmaxud
,in_x86_ptest
,in_x86_pcmpeqq
,in_x86_packusdw
,in_x86_pcmpgtq
: //var r0:xmm;r1:xmm;
  begin
    case InlineNumber of
      in_x86_pcmpgtq: begin lOp:=A_pcmpgtq end;
      in_x86_packusdw: begin lOp:=A_packusdw end;
      in_x86_pcmpeqq: begin lOp:=A_pcmpeqq end;
      in_x86_ptest: begin lOp:=A_ptest end;
      in_x86_pmaxud: begin lOp:=A_pmaxud end;
      in_x86_pmaxsd: begin lOp:=A_pmaxsd end;
      in_x86_pmaxuw: begin lOp:=A_pmaxuw end;
      in_x86_pmaxsb: begin lOp:=A_pmaxsb end;
      in_x86_pminud: begin lOp:=A_pminud end;
      in_x86_pminsd: begin lOp:=A_pminsd end;
      in_x86_pminuw: begin lOp:=A_pminuw end;
      in_x86_pminsb: begin lOp:=A_pminsb end;
      in_x86_pmuldq: begin lOp:=A_pmuldq end;
      in_x86_pmulld: begin lOp:=A_pmulld end;
      in_x86_phminposuw: begin lOp:=A_phminposuw end;
      in_x86_phaddd: begin lOp:=A_phaddd end;
      in_x86_phaddw: begin lOp:=A_phaddw end;
      in_x86_phaddsw: begin lOp:=A_phaddsw end;
      in_x86_phsubd: begin lOp:=A_phsubd end;
      in_x86_phsubsw: begin lOp:=A_phsubsw end;
      in_x86_phsubw: begin lOp:=A_phsubw end;
      in_x86_pmaddubsw: begin lOp:=A_pmaddubsw end;
      in_x86_pmulhrsw: begin lOp:=A_pmulhrsw end;
      in_x86_pshufb: begin lOp:=A_pshufb end;
      in_x86_psignd: begin lOp:=A_psignd end;
      in_x86_psignw: begin lOp:=A_psignw end;
      in_x86_psignb: begin lOp:=A_psignb end;
      in_x86_hsubpd: begin lOp:=A_hsubpd end;
      in_x86_hsubps: begin lOp:=A_hsubps end;
      in_x86_haddpd: begin lOp:=A_haddpd end;
      in_x86_haddps: begin lOp:=A_haddps end;
      in_x86_addsubpd: begin lOp:=A_addsubpd end;
      in_x86_addsubps: begin lOp:=A_addsubps end;
      in_x86_punpcklqdq: begin lOp:=A_punpcklqdq end;
      in_x86_punpckhqdq: begin lOp:=A_punpckhqdq end;
      in_x86_psadbw_sse2: begin lOp:=A_psadbw end;
      in_x86_pmaxub_sse2: begin lOp:=A_pmaxub end;
      in_x86_pmaxsw_sse2: begin lOp:=A_pmaxsw end;
      in_x86_pminsw_sse2: begin lOp:=A_pminsw end;
      in_x86_pminub_sse2: begin lOp:=A_pminub end;
      in_x86_pavgw_sse2: begin lOp:=A_pavgw end;
      in_x86_pavgb_sse2: begin lOp:=A_pavgb end;
      in_x86_punpckldq: begin lOp:=A_punpckldq end;
      in_x86_punpcklwd: begin lOp:=A_punpcklwd end;
      in_x86_punpcklbw: begin lOp:=A_punpcklbw end;
      in_x86_punpckhdq: begin lOp:=A_punpckhdq end;
      in_x86_punpckhwd: begin lOp:=A_punpckhwd end;
      in_x86_punpckhbw: begin lOp:=A_punpckhbw end;
      in_x86_psubusw: begin lOp:=A_psubusw end;
      in_x86_psubusb: begin lOp:=A_psubusb end;
      in_x86_pmaddwd: begin lOp:=A_pmaddwd end;
      in_x86_psubsw: begin lOp:=A_psubsw end;
      in_x86_psubsb: begin lOp:=A_psubsb end;
      in_x86_psubq: begin lOp:=A_psubq end;
      in_x86_psubd: begin lOp:=A_psubd end;
      in_x86_psubw: begin lOp:=A_psubw end;
      in_x86_psubb: begin lOp:=A_psubb end;
      in_x86_psrlq_sse2: begin lOp:=A_psrlq end;
      in_x86_psrld_sse2: begin lOp:=A_psrld end;
      in_x86_psrlw_sse2: begin lOp:=A_psrlw end;
      in_x86_psraw_sse2: begin lOp:=A_psraw end;
      in_x86_psrad_sse2: begin lOp:=A_psrad end;
      in_x86_psllq_sse2: begin lOp:=A_psllq end;
      in_x86_pslld_sse2: begin lOp:=A_pslld end;
      in_x86_psllw_sse2: begin lOp:=A_psllw end;
      in_x86_pmuludq: begin lOp:=A_pmuludq end;
      in_x86_pmulhuw_sse2: begin lOp:=A_pmulhuw end;
      in_x86_pmulhw: begin lOp:=A_pmulhw end;
      in_x86_pmullw: begin lOp:=A_pmullw end;
      in_x86_pcmpgtd: begin lOp:=A_pcmpgtd end;
      in_x86_pcmpgtw: begin lOp:=A_pcmpgtw end;
      in_x86_pcmpgtb: begin lOp:=A_pcmpgtb end;
      in_x86_pcmpeqd: begin lOp:=A_pcmpeqd end;
      in_x86_pcmpeqw: begin lOp:=A_pcmpeqw end;
      in_x86_pcmpeqb: begin lOp:=A_pcmpeqb end;
      in_x86_pxor: begin lOp:=A_pxor end;
      in_x86_por: begin lOp:=A_por end;
      in_x86_pandn: begin lOp:=A_pandn end;
      in_x86_pand: begin lOp:=A_pand end;
      in_x86_paddusw: begin lOp:=A_paddusw end;
      in_x86_paddusb: begin lOp:=A_paddusb end;
      in_x86_paddsw: begin lOp:=A_paddsw end;
      in_x86_paddsb: begin lOp:=A_paddsb end;
      in_x86_paddq: begin lOp:=A_paddq end;
      in_x86_paddd: begin lOp:=A_paddd end;
      in_x86_paddw: begin lOp:=A_paddw end;
      in_x86_paddb: begin lOp:=A_paddb end;
      in_x86_packuswb: begin lOp:=A_packuswb end;
      in_x86_packsswb: begin lOp:=A_packsswb end;
      in_x86_packssdw: begin lOp:=A_packssdw end;
      in_x86_cvttps2dq: begin lOp:=A_cvttps2dq end;
      in_x86_cvttpd2dq: begin lOp:=A_cvttpd2dq end;
      in_x86_cvtsd2ss: begin lOp:=A_cvtsd2ss end;
      in_x86_cvtps2pd: begin lOp:=A_cvtps2pd end;
      in_x86_cvtps2dq: begin lOp:=A_cvtps2dq end;
      in_x86_cvtpd2ps: begin lOp:=A_cvtpd2ps end;
      in_x86_cvtpd2dq: begin lOp:=A_cvtpd2dq end;
      in_x86_cvtdq2ps: begin lOp:=A_cvtdq2ps end;
      in_x86_cvtdq2pd: begin lOp:=A_cvtdq2pd end;
      in_x86_unpcklpd: begin lOp:=A_unpcklpd end;
      in_x86_unpckhpd: begin lOp:=A_unpckhpd end;
      in_x86_xorpd: begin lOp:=A_xorpd end;
      in_x86_orpd: begin lOp:=A_orpd end;
      in_x86_andnpd: begin lOp:=A_andnpd end;
      in_x86_andpd: begin lOp:=A_andpd end;
      in_x86_subpd: begin lOp:=A_subpd end;
      in_x86_mulpd: begin lOp:=A_mulpd end;
      in_x86_minpd: begin lOp:=A_minpd end;
      in_x86_maxpd: begin lOp:=A_maxpd end;
      in_x86_divpd: begin lOp:=A_divpd end;
      in_x86_addpd: begin lOp:=A_addpd end;
      in_x86_unpcklps: begin lOp:=A_unpcklps end;
      in_x86_unpckhps: begin lOp:=A_unpckhps end;
      in_x86_andnps: begin lOp:=A_andnps end;
      in_x86_xorps: begin lOp:=A_xorps end;
      in_x86_orps: begin lOp:=A_orps end;
      in_x86_andps: begin lOp:=A_andps end;
      in_x86_rsqrtps: begin lOp:=A_rsqrtps end;
      in_x86_minps: begin lOp:=A_minps end;
      in_x86_maxps: begin lOp:=A_maxps end;
      in_x86_sqrtps: begin lOp:=A_sqrtps end;
      in_x86_rcpps: begin lOp:=A_rcpps end;
      in_x86_divps: begin lOp:=A_divps end;
      in_x86_mulps: begin lOp:=A_mulps end;
      in_x86_subps: begin lOp:=A_subps end;
      in_x86_addps: begin lOp:=A_addps end;
      in_x86_movhlps: begin lOp:=A_movhlps end;
      in_x86_movlhps: begin lOp:=A_movlhps; end;
      else
        InternalError(2020010201);
    end;

    GetParameters(2);

    for lIndex := 1 to 2 do SecondPass(lParaArray[lIndex]);

    Location_Force_MMReg(CurrentAsmData.CurrAsmList, lParaArray[1].Location, false);
    Location_Force_MMReg(CurrentAsmData.CurrAsmList, lParaArray[2].Location, true);
    Location:=lParaArray[1].Location;
    CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg(lOp,S_NO,lParaArray[2].Location.Register,lParaArray[1].Location.Register));
  end;
in_x86_addss
,in_x86_subss
,in_x86_mulss
,in_x86_divss
,in_x86_rcpss
,in_x86_sqrtss
,in_x86_maxss
,in_x86_minss
,in_x86_rsqrtss
: //var r0:f32;r1:f32;
  begin
    case InlineNumber of
      in_x86_rsqrtss: begin lOp:=A_rsqrtss end;
      in_x86_minss: begin lOp:=A_minss end;
      in_x86_maxss: begin lOp:=A_maxss end;
      in_x86_sqrtss: begin lOp:=A_sqrtss end;
      in_x86_rcpss: begin lOp:=A_rcpss end;
      in_x86_divss: begin lOp:=A_divss end;
      in_x86_mulss: begin lOp:=A_mulss end;
      in_x86_subss: begin lOp:=A_subss end;
      in_x86_addss: begin lOp:=A_addss; end;
      else
        InternalError(2020010201);
    end;

    GetParameters(2);

    for lIndex := 1 to 2 do SecondPass(lParaArray[lIndex]);

    Location_Force_MMReg(CurrentAsmData.CurrAsmList, lParaArray[1].Location, false);
    Location_Force_MMReg(CurrentAsmData.CurrAsmList, lParaArray[2].Location, true);
    Location:=lParaArray[1].Location;
    CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg(lOp,S_NO,lParaArray[2].Location.Register,lParaArray[1].Location.Register));
  end;
in_x86_addss_from_mem
,in_x86_subss_from_mem
,in_x86_mulss_from_mem
,in_x86_divss_from_mem
,in_x86_rcpss_from_mem
,in_x86_sqrtss_from_mem
,in_x86_maxss_from_mem
,in_x86_minss_from_mem
,in_x86_rsqrtss_from_mem
,in_x86_cvtsi2ss_from_mem
: //var r0:f32;r1:ptr32;
  begin
    case InlineNumber of
      in_x86_cvtsi2ss_from_mem: begin lOp:=A_cvtsi2ss end;
      in_x86_rsqrtss_from_mem: begin lOp:=A_rsqrtss end;
      in_x86_minss_from_mem: begin lOp:=A_minss end;
      in_x86_maxss_from_mem: begin lOp:=A_maxss end;
      in_x86_sqrtss_from_mem: begin lOp:=A_sqrtss end;
      in_x86_rcpss_from_mem: begin lOp:=A_rcpss end;
      in_x86_divss_from_mem: begin lOp:=A_divss end;
      in_x86_mulss_from_mem: begin lOp:=A_mulss end;
      in_x86_subss_from_mem: begin lOp:=A_subss end;
      in_x86_addss_from_mem: begin lOp:=A_addss; end;
      else
        InternalError(2020010201);
    end;

    GetParameters(2);

    for lIndex := 1 to 2 do SecondPass(lParaArray[lIndex]);

    Location_Force_MMReg(CurrentAsmData.CurrAsmList, lParaArray[1].Location, false);
    LocationMakeRef(lParaArray[2].Location);
    Location:=lParaArray[1].Location;
    CurrentAsmData.CurrAsmList.concat(TAICPU.op_ref_reg(lOp,S_NO,lParaArray[2].Location.Reference,lParaArray[1].Location.Register));
  end;
in_x86_addps_from_mem
,in_x86_subps_from_mem
,in_x86_mulps_from_mem
,in_x86_divps_from_mem
,in_x86_rcpps_from_mem
,in_x86_sqrtps_from_mem
,in_x86_maxps_from_mem
,in_x86_minps_from_mem
,in_x86_rsqrtps_from_mem
,in_x86_andps_from_mem
,in_x86_orps_from_mem
,in_x86_xorps_from_mem
,in_x86_andnps_from_mem
,in_x86_unpckhps_from_mem
,in_x86_unpcklps_from_mem
,in_x86_addpd_from_mem
,in_x86_divpd_from_mem
,in_x86_maxpd_from_mem
,in_x86_minpd_from_mem
,in_x86_mulpd_from_mem
,in_x86_subpd_from_mem
,in_x86_andpd_from_mem
,in_x86_andnpd_from_mem
,in_x86_orpd_from_mem
,in_x86_xorpd_from_mem
,in_x86_unpckhpd_from_mem
,in_x86_unpcklpd_from_mem
,in_x86_cvtdq2ps_from_mem
,in_x86_cvtpd2dq_from_mem
,in_x86_cvtpd2ps_from_mem
,in_x86_cvtps2dq_from_mem
,in_x86_cvttpd2dq_from_mem
,in_x86_cvttps2dq_from_mem
,in_x86_packssdw_from_mem
,in_x86_packsswb_from_mem
,in_x86_packuswb_from_mem
,in_x86_paddb_from_mem
,in_x86_paddw_from_mem
,in_x86_paddd_from_mem
,in_x86_paddq_from_mem
,in_x86_paddsb_from_mem
,in_x86_paddsw_from_mem
,in_x86_paddusb_from_mem
,in_x86_paddusw_from_mem
,in_x86_pand_from_mem
,in_x86_pandn_from_mem
,in_x86_por_from_mem
,in_x86_pxor_from_mem
,in_x86_pcmpeqb_from_mem
,in_x86_pcmpeqw_from_mem
,in_x86_pcmpeqd_from_mem
,in_x86_pcmpgtb_from_mem
,in_x86_pcmpgtw_from_mem
,in_x86_pcmpgtd_from_mem
,in_x86_pmullw_from_mem
,in_x86_pmulhw_from_mem
,in_x86_pmulhuw_from_mem
,in_x86_pmuludq_from_mem
,in_x86_psllw_from_mem
,in_x86_pslld_from_mem
,in_x86_psllq_from_mem
,in_x86_psrad_from_mem
,in_x86_psraw_from_mem
,in_x86_psrlw_from_mem
,in_x86_psrld_from_mem
,in_x86_psrlq_from_mem
,in_x86_psubb_from_mem
,in_x86_psubw_from_mem
,in_x86_psubd_from_mem
,in_x86_psubq_from_mem
,in_x86_psubsb_from_mem
,in_x86_psubsw_from_mem
,in_x86_pmaddwd_from_mem
,in_x86_psubusb_from_mem
,in_x86_psubusw_from_mem
,in_x86_punpckhbw_from_mem
,in_x86_punpckhwd_from_mem
,in_x86_punpckhdq_from_mem
,in_x86_punpcklbw_from_mem
,in_x86_punpcklwd_from_mem
,in_x86_punpckldq_from_mem
,in_x86_pavgb_from_mem
,in_x86_pavgw_from_mem
,in_x86_pminub_from_mem
,in_x86_pminsw_from_mem
,in_x86_pmaxsw_from_mem
,in_x86_pmaxub_from_mem
,in_x86_psadbw_from_mem
,in_x86_punpckhqdq_from_mem
,in_x86_punpcklqdq_from_mem
,in_x86_addsubps_from_mem
,in_x86_addsubpd_from_mem
,in_x86_haddps_from_mem
,in_x86_haddpd_from_mem
,in_x86_hsubps_from_mem
,in_x86_hsubpd_from_mem
,in_x86_psignb_from_mem
,in_x86_psignw_from_mem
,in_x86_psignd_from_mem
,in_x86_pshufb_from_mem
,in_x86_pmulhrsw_from_mem
,in_x86_pmaddubsw_from_mem
,in_x86_phsubw_from_mem
,in_x86_phsubsw_from_mem
,in_x86_phsubd_from_mem
,in_x86_phaddsw_from_mem
,in_x86_phaddw_from_mem
,in_x86_phaddd_from_mem
,in_x86_phminposuw_from_mem
,in_x86_pmulld_from_mem
,in_x86_pmuldq_from_mem
,in_x86_pminsb_from_mem
,in_x86_pminuw_from_mem
,in_x86_pminsd_from_mem
,in_x86_pminud_from_mem
,in_x86_pmaxsb_from_mem
,in_x86_pmaxuw_from_mem
,in_x86_pmaxsd_from_mem
,in_x86_pmaxud_from_mem
,in_x86_ptest_from_mem
,in_x86_pcmpeqq_from_mem
,in_x86_packusdw_from_mem
,in_x86_pcmpgtq_from_mem
: //var r0:xmm;r1:ptr128;
  begin
    case InlineNumber of
      in_x86_pcmpgtq_from_mem: begin lOp:=A_pcmpgtq end;
      in_x86_packusdw_from_mem: begin lOp:=A_packusdw end;
      in_x86_pcmpeqq_from_mem: begin lOp:=A_pcmpeqq end;
      in_x86_ptest_from_mem: begin lOp:=A_ptest end;
      in_x86_pmaxud_from_mem: begin lOp:=A_pmaxud end;
      in_x86_pmaxsd_from_mem: begin lOp:=A_pmaxsd end;
      in_x86_pmaxuw_from_mem: begin lOp:=A_pmaxuw end;
      in_x86_pmaxsb_from_mem: begin lOp:=A_pmaxsb end;
      in_x86_pminud_from_mem: begin lOp:=A_pminud end;
      in_x86_pminsd_from_mem: begin lOp:=A_pminsd end;
      in_x86_pminuw_from_mem: begin lOp:=A_pminuw end;
      in_x86_pminsb_from_mem: begin lOp:=A_pminsb end;
      in_x86_pmuldq_from_mem: begin lOp:=A_pmuldq end;
      in_x86_pmulld_from_mem: begin lOp:=A_pmulld end;
      in_x86_phminposuw_from_mem: begin lOp:=A_phminposuw end;
      in_x86_phaddd_from_mem: begin lOp:=A_phaddd end;
      in_x86_phaddw_from_mem: begin lOp:=A_phaddw end;
      in_x86_phaddsw_from_mem: begin lOp:=A_phaddsw end;
      in_x86_phsubd_from_mem: begin lOp:=A_phsubd end;
      in_x86_phsubsw_from_mem: begin lOp:=A_phsubsw end;
      in_x86_phsubw_from_mem: begin lOp:=A_phsubw end;
      in_x86_pmaddubsw_from_mem: begin lOp:=A_pmaddubsw end;
      in_x86_pmulhrsw_from_mem: begin lOp:=A_pmulhrsw end;
      in_x86_pshufb_from_mem: begin lOp:=A_pshufb end;
      in_x86_psignd_from_mem: begin lOp:=A_psignd end;
      in_x86_psignw_from_mem: begin lOp:=A_psignw end;
      in_x86_psignb_from_mem: begin lOp:=A_psignb end;
      in_x86_hsubpd_from_mem: begin lOp:=A_hsubpd end;
      in_x86_hsubps_from_mem: begin lOp:=A_hsubps end;
      in_x86_haddpd_from_mem: begin lOp:=A_haddpd end;
      in_x86_haddps_from_mem: begin lOp:=A_haddps end;
      in_x86_addsubpd_from_mem: begin lOp:=A_addsubpd end;
      in_x86_addsubps_from_mem: begin lOp:=A_addsubps end;
      in_x86_punpcklqdq_from_mem: begin lOp:=A_punpcklqdq end;
      in_x86_punpckhqdq_from_mem: begin lOp:=A_punpckhqdq end;
      in_x86_psadbw_from_mem: begin lOp:=A_psadbw end;
      in_x86_pmaxub_from_mem: begin lOp:=A_pmaxub end;
      in_x86_pmaxsw_from_mem: begin lOp:=A_pmaxsw end;
      in_x86_pminsw_from_mem: begin lOp:=A_pminsw end;
      in_x86_pminub_from_mem: begin lOp:=A_pminub end;
      in_x86_pavgw_from_mem: begin lOp:=A_pavgw end;
      in_x86_pavgb_from_mem: begin lOp:=A_pavgb end;
      in_x86_punpckldq_from_mem: begin lOp:=A_punpckldq end;
      in_x86_punpcklwd_from_mem: begin lOp:=A_punpcklwd end;
      in_x86_punpcklbw_from_mem: begin lOp:=A_punpcklbw end;
      in_x86_punpckhdq_from_mem: begin lOp:=A_punpckhdq end;
      in_x86_punpckhwd_from_mem: begin lOp:=A_punpckhwd end;
      in_x86_punpckhbw_from_mem: begin lOp:=A_punpckhbw end;
      in_x86_psubusw_from_mem: begin lOp:=A_psubusw end;
      in_x86_psubusb_from_mem: begin lOp:=A_psubusb end;
      in_x86_pmaddwd_from_mem: begin lOp:=A_pmaddwd end;
      in_x86_psubsw_from_mem: begin lOp:=A_psubsw end;
      in_x86_psubsb_from_mem: begin lOp:=A_psubsb end;
      in_x86_psubq_from_mem: begin lOp:=A_psubq end;
      in_x86_psubd_from_mem: begin lOp:=A_psubd end;
      in_x86_psubw_from_mem: begin lOp:=A_psubw end;
      in_x86_psubb_from_mem: begin lOp:=A_psubb end;
      in_x86_psrlq_from_mem: begin lOp:=A_psrlq end;
      in_x86_psrld_from_mem: begin lOp:=A_psrld end;
      in_x86_psrlw_from_mem: begin lOp:=A_psrlw end;
      in_x86_psraw_from_mem: begin lOp:=A_psraw end;
      in_x86_psrad_from_mem: begin lOp:=A_psrad end;
      in_x86_psllq_from_mem: begin lOp:=A_psllq end;
      in_x86_pslld_from_mem: begin lOp:=A_pslld end;
      in_x86_psllw_from_mem: begin lOp:=A_psllw end;
      in_x86_pmuludq_from_mem: begin lOp:=A_pmuludq end;
      in_x86_pmulhuw_from_mem: begin lOp:=A_pmulhuw end;
      in_x86_pmulhw_from_mem: begin lOp:=A_pmulhw end;
      in_x86_pmullw_from_mem: begin lOp:=A_pmullw end;
      in_x86_pcmpgtd_from_mem: begin lOp:=A_pcmpgtd end;
      in_x86_pcmpgtw_from_mem: begin lOp:=A_pcmpgtw end;
      in_x86_pcmpgtb_from_mem: begin lOp:=A_pcmpgtb end;
      in_x86_pcmpeqd_from_mem: begin lOp:=A_pcmpeqd end;
      in_x86_pcmpeqw_from_mem: begin lOp:=A_pcmpeqw end;
      in_x86_pcmpeqb_from_mem: begin lOp:=A_pcmpeqb end;
      in_x86_pxor_from_mem: begin lOp:=A_pxor end;
      in_x86_por_from_mem: begin lOp:=A_por end;
      in_x86_pandn_from_mem: begin lOp:=A_pandn end;
      in_x86_pand_from_mem: begin lOp:=A_pand end;
      in_x86_paddusw_from_mem: begin lOp:=A_paddusw end;
      in_x86_paddusb_from_mem: begin lOp:=A_paddusb end;
      in_x86_paddsw_from_mem: begin lOp:=A_paddsw end;
      in_x86_paddsb_from_mem: begin lOp:=A_paddsb end;
      in_x86_paddq_from_mem: begin lOp:=A_paddq end;
      in_x86_paddd_from_mem: begin lOp:=A_paddd end;
      in_x86_paddw_from_mem: begin lOp:=A_paddw end;
      in_x86_paddb_from_mem: begin lOp:=A_paddb end;
      in_x86_packuswb_from_mem: begin lOp:=A_packuswb end;
      in_x86_packsswb_from_mem: begin lOp:=A_packsswb end;
      in_x86_packssdw_from_mem: begin lOp:=A_packssdw end;
      in_x86_cvttps2dq_from_mem: begin lOp:=A_cvttps2dq end;
      in_x86_cvttpd2dq_from_mem: begin lOp:=A_cvttpd2dq end;
      in_x86_cvtps2dq_from_mem: begin lOp:=A_cvtps2dq end;
      in_x86_cvtpd2ps_from_mem: begin lOp:=A_cvtpd2ps end;
      in_x86_cvtpd2dq_from_mem: begin lOp:=A_cvtpd2dq end;
      in_x86_cvtdq2ps_from_mem: begin lOp:=A_cvtdq2ps end;
      in_x86_unpcklpd_from_mem: begin lOp:=A_unpcklpd end;
      in_x86_unpckhpd_from_mem: begin lOp:=A_unpckhpd end;
      in_x86_xorpd_from_mem: begin lOp:=A_xorpd end;
      in_x86_orpd_from_mem: begin lOp:=A_orpd end;
      in_x86_andnpd_from_mem: begin lOp:=A_andnpd end;
      in_x86_andpd_from_mem: begin lOp:=A_andpd end;
      in_x86_subpd_from_mem: begin lOp:=A_subpd end;
      in_x86_mulpd_from_mem: begin lOp:=A_mulpd end;
      in_x86_minpd_from_mem: begin lOp:=A_minpd end;
      in_x86_maxpd_from_mem: begin lOp:=A_maxpd end;
      in_x86_divpd_from_mem: begin lOp:=A_divpd end;
      in_x86_addpd_from_mem: begin lOp:=A_addpd end;
      in_x86_unpcklps_from_mem: begin lOp:=A_unpcklps end;
      in_x86_unpckhps_from_mem: begin lOp:=A_unpckhps end;
      in_x86_andnps_from_mem: begin lOp:=A_andnps end;
      in_x86_xorps_from_mem: begin lOp:=A_xorps end;
      in_x86_orps_from_mem: begin lOp:=A_orps end;
      in_x86_andps_from_mem: begin lOp:=A_andps end;
      in_x86_rsqrtps_from_mem: begin lOp:=A_rsqrtps end;
      in_x86_minps_from_mem: begin lOp:=A_minps end;
      in_x86_maxps_from_mem: begin lOp:=A_maxps end;
      in_x86_sqrtps_from_mem: begin lOp:=A_sqrtps end;
      in_x86_rcpps_from_mem: begin lOp:=A_rcpps end;
      in_x86_divps_from_mem: begin lOp:=A_divps end;
      in_x86_mulps_from_mem: begin lOp:=A_mulps end;
      in_x86_subps_from_mem: begin lOp:=A_subps end;
      in_x86_addps_from_mem: begin lOp:=A_addps; end;
      else
        InternalError(2020010201);
    end;

    GetParameters(2);

    for lIndex := 1 to 2 do SecondPass(lParaArray[lIndex]);

    Location_Force_MMReg(CurrentAsmData.CurrAsmList, lParaArray[1].Location, false);
    LocationMakeRef(lParaArray[2].Location);
    Location:=lParaArray[1].Location;
    CurrentAsmData.CurrAsmList.concat(TAICPU.op_ref_reg(lOp,S_NO,lParaArray[2].Location.Reference,lParaArray[1].Location.Register));
  end;
in_x86_cmpss
: //var r0:f32;r1:f32;imm:i32;
  begin
    case InlineNumber of
      in_x86_cmpss: begin lOp:=A_cmpss; end;
      else
        InternalError(2020010201);
    end;

    GetParameters(3);

    for lIndex := 1 to 3 do SecondPass(lParaArray[lIndex]);

    Location_Force_MMReg(CurrentAsmData.CurrAsmList, lParaArray[1].Location, false);
    Location_Force_MMReg(CurrentAsmData.CurrAsmList, lParaArray[2].Location, true);
    Location:=lParaArray[1].Location;
    CurrentAsmData.CurrAsmList.concat(TAICPU.op_const_reg_reg(lOp,S_NO,GetConstInt(lParaArray[3]),lParaArray[2].Location.Register,lParaArray[1].Location.Register));
  end;
in_x86_cmpss_from_mem
: //var r0:f32;r1:ptr32;imm:i32;
  begin
    case InlineNumber of
      in_x86_cmpss_from_mem: begin lOp:=A_cmpss; end;
      else
        InternalError(2020010201);
    end;

    GetParameters(3);

    for lIndex := 1 to 3 do SecondPass(lParaArray[lIndex]);

    Location_Force_MMReg(CurrentAsmData.CurrAsmList, lParaArray[1].Location, false);
    LocationMakeRef(lParaArray[2].Location);
    Location:=lParaArray[1].Location;
    CurrentAsmData.CurrAsmList.concat(TAICPU.op_const_ref_reg(lOp,S_NO,GetConstInt(lParaArray[3]),lParaArray[2].Location.Reference,lParaArray[1].Location.Register));
  end;
in_x86_cmpps
,in_x86_shufps
,in_x86_cmppd
,in_x86_shufpd
,in_x86_palignr
,in_x86_dpps
,in_x86_dppd
,in_x86_blendps
,in_x86_blendpd
,in_x86_insertps
,in_x86_mpsadbw
,in_x86_pblendw
,in_x86_pcmpestri
,in_x86_pcmpestrm
,in_x86_pcmpistri
,in_x86_pcmpistrm
: //var r0:xmm;r1:xmm;imm:i32;
  begin
    case InlineNumber of
      in_x86_pcmpistrm: begin lOp:=A_pcmpistrm end;
      in_x86_pcmpistri: begin lOp:=A_pcmpistri end;
      in_x86_pcmpestrm: begin lOp:=A_pcmpestrm end;
      in_x86_pcmpestri: begin lOp:=A_pcmpestri end;
      in_x86_pblendw: begin lOp:=A_pblendw end;
      in_x86_mpsadbw: begin lOp:=A_mpsadbw end;
      in_x86_insertps: begin lOp:=A_insertps end;
      in_x86_blendpd: begin lOp:=A_blendpd end;
      in_x86_blendps: begin lOp:=A_blendps end;
      in_x86_dppd: begin lOp:=A_dppd end;
      in_x86_dpps: begin lOp:=A_dpps end;
      in_x86_palignr: begin lOp:=A_palignr end;
      in_x86_shufpd: begin lOp:=A_shufpd end;
      in_x86_cmppd: begin lOp:=A_cmppd end;
      in_x86_shufps: begin lOp:=A_shufps end;
      in_x86_cmpps: begin lOp:=A_cmpps; end;
      else
        InternalError(2020010201);
    end;

    GetParameters(3);

    for lIndex := 1 to 3 do SecondPass(lParaArray[lIndex]);

    Location_Force_MMReg(CurrentAsmData.CurrAsmList, lParaArray[1].Location, false);
    Location_Force_MMReg(CurrentAsmData.CurrAsmList, lParaArray[2].Location, true);
    Location:=lParaArray[1].Location;
    CurrentAsmData.CurrAsmList.concat(TAICPU.op_const_reg_reg(lOp,S_NO,GetConstInt(lParaArray[3]),lParaArray[2].Location.Register,lParaArray[1].Location.Register));
  end;
in_x86_cmpps_from_mem
,in_x86_shufps_from_mem
,in_x86_cmppd_from_mem
,in_x86_shufpd_from_mem
,in_x86_palignr_from_mem
,in_x86_dpps_from_mem
,in_x86_dppd_from_mem
,in_x86_blendps_from_mem
,in_x86_blendpd_from_mem
,in_x86_mpsadbw_from_mem
,in_x86_pblendw_from_mem
,in_x86_pcmpestri_from_mem
,in_x86_pcmpestrm_from_mem
,in_x86_pcmpistri_from_mem
,in_x86_pcmpistrm_from_mem
: //var r0:xmm;r1:ptr128;imm:i32;
  begin
    case InlineNumber of
      in_x86_pcmpistrm_from_mem: begin lOp:=A_pcmpistrm end;
      in_x86_pcmpistri_from_mem: begin lOp:=A_pcmpistri end;
      in_x86_pcmpestrm_from_mem: begin lOp:=A_pcmpestrm end;
      in_x86_pcmpestri_from_mem: begin lOp:=A_pcmpestri end;
      in_x86_pblendw_from_mem: begin lOp:=A_pblendw end;
      in_x86_mpsadbw_from_mem: begin lOp:=A_mpsadbw end;
      in_x86_blendpd_from_mem: begin lOp:=A_blendpd end;
      in_x86_blendps_from_mem: begin lOp:=A_blendps end;
      in_x86_dppd_from_mem: begin lOp:=A_dppd end;
      in_x86_dpps_from_mem: begin lOp:=A_dpps end;
      in_x86_palignr_from_mem: begin lOp:=A_palignr end;
      in_x86_shufpd_from_mem: begin lOp:=A_shufpd end;
      in_x86_cmppd_from_mem: begin lOp:=A_cmppd end;
      in_x86_shufps_from_mem: begin lOp:=A_shufps end;
      in_x86_cmpps_from_mem: begin lOp:=A_cmpps; end;
      else
        InternalError(2020010201);
    end;

    GetParameters(3);

    for lIndex := 1 to 3 do SecondPass(lParaArray[lIndex]);

    Location_Force_MMReg(CurrentAsmData.CurrAsmList, lParaArray[1].Location, false);
    LocationMakeRef(lParaArray[2].Location);
    Location:=lParaArray[1].Location;
    CurrentAsmData.CurrAsmList.concat(TAICPU.op_const_ref_reg(lOp,S_NO,GetConstInt(lParaArray[3]),lParaArray[2].Location.Reference,lParaArray[1].Location.Register));
  end;
in_x86_cvtsi2ss
: //var r0:f32;r1:reg;
  begin
    case InlineNumber of
      in_x86_cvtsi2ss: begin lOp:=A_cvtsi2ss; end;
      else
        InternalError(2020010201);
    end;

    GetParameters(2);

    for lIndex := 1 to 2 do SecondPass(lParaArray[lIndex]);

    Location_Force_MMReg(CurrentAsmData.CurrAsmList, lParaArray[1].Location, false);
    hlcg.Location_Force_Reg(CurrentAsmData.CurrAsmList, lParaArray[2].Location, lParaArray[2].ResultDef,UIntType,true);
    Location:=lParaArray[1].Location;
    CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg(lOp,S_NO,lParaArray[2].Location.Register,lParaArray[1].Location.Register));
  end;
in_x86_cvtss2si
,in_x86_cvttss2si
: //out r0:reg;r1:f32;
  begin
    case InlineNumber of
      in_x86_cvttss2si: begin lOp:=A_cvttss2si end;
      in_x86_cvtss2si: begin lOp:=A_cvtss2si; end;
      else
        InternalError(2020010201);
    end;

    GetParameters(1);

    for lIndex := 1 to 1 do SecondPass(lParaArray[lIndex]);

    Location_Force_MMReg(CurrentAsmData.CurrAsmList, lParaArray[1].Location, true);
    Location_Reset(Location,LOC_REGISTER,OS_INT);
    Location.Register:=cg.GetIntRegister(CurrentAsmData.CurrAsmList, OS_INT);
    CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg(lOp,S_NO,lParaArray[1].Location.Register,Location.Register));
  end;
in_x86_cvtss2si_from_mem
,in_x86_cvttss2si_from_mem
: //out r0:reg;r1:ptr32;
  begin
    case InlineNumber of
      in_x86_cvttss2si_from_mem: begin lOp:=A_cvttss2si end;
      in_x86_cvtss2si_from_mem: begin lOp:=A_cvtss2si; end;
      else
        InternalError(2020010201);
    end;

    GetParameters(1);

    for lIndex := 1 to 1 do SecondPass(lParaArray[lIndex]);

    LocationMakeRef(lParaArray[1].Location);
    Location_Reset(Location,LOC_REGISTER,OS_INT);
    Location.Register:=cg.GetIntRegister(CurrentAsmData.CurrAsmList, OS_INT);
    CurrentAsmData.CurrAsmList.concat(TAICPU.op_ref_reg(lOp,S_NO,lParaArray[1].Location.Reference,Location.Register));
  end;
in_x86_cvtpi2ps
,in_x86_cvtpi2pd
: //var r0:xmm;r1:mm;
  begin
    case InlineNumber of
      in_x86_cvtpi2pd: begin lOp:=A_cvtpi2pd end;
      in_x86_cvtpi2ps: begin lOp:=A_cvtpi2ps; end;
      else
        InternalError(2020010201);
    end;

    GetParameters(2);

    for lIndex := 1 to 2 do SecondPass(lParaArray[lIndex]);

    Location_Force_MMReg(CurrentAsmData.CurrAsmList, lParaArray[1].Location, false);
    LocationForceMMXReg(CurrentAsmData.CurrAsmList, lParaArray[2].Location, true);
    Location:=lParaArray[1].Location;
    CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg(lOp,S_NO,lParaArray[2].Location.Register,lParaArray[1].Location.Register));
  end;
in_x86_cvtps2pi
,in_x86_cvttps2pi
,in_x86_movdq2q
: //out r0:mm;r1:xmm;
  begin
    case InlineNumber of
      in_x86_movdq2q: begin lOp:=A_movdq2q end;
      in_x86_cvttps2pi: begin lOp:=A_cvttps2pi end;
      in_x86_cvtps2pi: begin lOp:=A_cvtps2pi; end;
      else
        InternalError(2020010201);
    end;

    GetParameters(1);

    for lIndex := 1 to 1 do SecondPass(lParaArray[lIndex]);

    Location_Force_MMReg(CurrentAsmData.CurrAsmList, lParaArray[1].Location, true);
    Location_Reset(Location,LOC_MMXREGISTER,OS_M64);
    Location.Register:=TCGX86(cg).GetMMXRegister(CurrentAsmData.CurrAsmList);
    CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg(lOp,S_NO,lParaArray[1].Location.Register,Location.Register));
  end;
in_x86_cvtps2pi_from_mem
,in_x86_cvttps2pi_from_mem
: //out r0:mm;r1:ptr64;
  begin
    case InlineNumber of
      in_x86_cvttps2pi_from_mem: begin lOp:=A_cvttps2pi end;
      in_x86_cvtps2pi_from_mem: begin lOp:=A_cvtps2pi; end;
      else
        InternalError(2020010201);
    end;

    GetParameters(1);

    for lIndex := 1 to 1 do SecondPass(lParaArray[lIndex]);

    LocationMakeRef(lParaArray[1].Location);
    Location_Reset(Location,LOC_MMXREGISTER,OS_M64);
    Location.Register:=TCGX86(cg).GetMMXRegister(CurrentAsmData.CurrAsmList);
    CurrentAsmData.CurrAsmList.concat(TAICPU.op_ref_reg(lOp,S_NO,lParaArray[1].Location.Reference,Location.Register));
  end;
in_x86_pmulhuw_mmx
,in_x86_psadbw_mmx
,in_x86_pavgb_mmx
,in_x86_pavgw_mmx
,in_x86_pmaxub_mmx
,in_x86_pminub_mmx
,in_x86_pmaxsw_mmx
,in_x86_pminsw_mmx
: //var r0:mm;r1:mm;
  begin
    case InlineNumber of
      in_x86_pminsw_mmx: begin lOp:=A_pminsw end;
      in_x86_pmaxsw_mmx: begin lOp:=A_pmaxsw end;
      in_x86_pminub_mmx: begin lOp:=A_pminub end;
      in_x86_pmaxub_mmx: begin lOp:=A_pmaxub end;
      in_x86_pavgw_mmx: begin lOp:=A_pavgw end;
      in_x86_pavgb_mmx: begin lOp:=A_pavgb end;
      in_x86_psadbw_mmx: begin lOp:=A_psadbw end;
      in_x86_pmulhuw_mmx: begin lOp:=A_pmulhuw; end;
      else
        InternalError(2020010201);
    end;

    GetParameters(2);

    for lIndex := 1 to 2 do SecondPass(lParaArray[lIndex]);

    LocationForceMMXReg(CurrentAsmData.CurrAsmList, lParaArray[1].Location, false);
    LocationForceMMXReg(CurrentAsmData.CurrAsmList, lParaArray[2].Location, true);
    Location:=lParaArray[1].Location;
    CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg(lOp,S_NO,lParaArray[2].Location.Register,lParaArray[1].Location.Register));
  end;
in_x86_pmulhuw_mmx_from_mem
,in_x86_psadbw_mmx_from_mem
,in_x86_pavgb_mmx_from_mem
,in_x86_pavgw_mmx_from_mem
,in_x86_pmaxub_mmx_from_mem
,in_x86_pminub_mmx_from_mem
,in_x86_pmaxsw_mmx_from_mem
,in_x86_pminsw_mmx_from_mem
: //var r0:mm;r1:ptr64;
  begin
    case InlineNumber of
      in_x86_pminsw_mmx_from_mem: begin lOp:=A_pminsw end;
      in_x86_pmaxsw_mmx_from_mem: begin lOp:=A_pmaxsw end;
      in_x86_pminub_mmx_from_mem: begin lOp:=A_pminub end;
      in_x86_pmaxub_mmx_from_mem: begin lOp:=A_pmaxub end;
      in_x86_pavgw_mmx_from_mem: begin lOp:=A_pavgw end;
      in_x86_pavgb_mmx_from_mem: begin lOp:=A_pavgb end;
      in_x86_psadbw_mmx_from_mem: begin lOp:=A_psadbw end;
      in_x86_pmulhuw_mmx_from_mem: begin lOp:=A_pmulhuw; end;
      else
        InternalError(2020010201);
    end;

    GetParameters(2);

    for lIndex := 1 to 2 do SecondPass(lParaArray[lIndex]);

    LocationForceMMXReg(CurrentAsmData.CurrAsmList, lParaArray[1].Location, false);
    LocationMakeRef(lParaArray[2].Location);
    Location:=lParaArray[1].Location;
    CurrentAsmData.CurrAsmList.concat(TAICPU.op_ref_reg(lOp,S_NO,lParaArray[2].Location.Reference,lParaArray[1].Location.Register));
  end;
in_x86_pextrw_mmx
: //out r0:reg;r1:mm;imm:i32;
  begin
    case InlineNumber of
      in_x86_pextrw_mmx: begin lOp:=A_pextrw; end;
      else
        InternalError(2020010201);
    end;

    GetParameters(2);

    for lIndex := 1 to 2 do SecondPass(lParaArray[lIndex]);

    LocationForceMMXReg(CurrentAsmData.CurrAsmList, lParaArray[1].Location, true);
    Location_Reset(Location,LOC_REGISTER,OS_INT);
    Location.Register:=cg.GetIntRegister(CurrentAsmData.CurrAsmList, OS_INT);
    CurrentAsmData.CurrAsmList.concat(TAICPU.op_const_reg_reg(lOp,S_NO,GetConstInt(lParaArray[2]),lParaArray[1].Location.Register,Location.Register));
  end;
in_x86_pinsrw_mmx
: //var r0:mm;r1:reg;imm:i32;
  begin
    case InlineNumber of
      in_x86_pinsrw_mmx: begin lOp:=A_pinsrw; end;
      else
        InternalError(2020010201);
    end;

    GetParameters(3);

    for lIndex := 1 to 3 do SecondPass(lParaArray[lIndex]);

    LocationForceMMXReg(CurrentAsmData.CurrAsmList, lParaArray[1].Location, false);
    hlcg.Location_Force_Reg(CurrentAsmData.CurrAsmList, lParaArray[2].Location, lParaArray[2].ResultDef,UIntType,true);
    Location:=lParaArray[1].Location;
    CurrentAsmData.CurrAsmList.concat(TAICPU.op_const_reg_reg(lOp,S_NO,GetConstInt(lParaArray[3]),lParaArray[2].Location.Register,lParaArray[1].Location.Register));
  end;
in_x86_pmovmskb_mmx
: //out r0:reg;r1:mm;
  begin
    case InlineNumber of
      in_x86_pmovmskb_mmx: begin lOp:=A_pmovmskb; end;
      else
        InternalError(2020010201);
    end;

    GetParameters(1);

    for lIndex := 1 to 1 do SecondPass(lParaArray[lIndex]);

    LocationForceMMXReg(CurrentAsmData.CurrAsmList, lParaArray[1].Location, true);
    Location_Reset(Location,LOC_REGISTER,OS_INT);
    Location.Register:=cg.GetIntRegister(CurrentAsmData.CurrAsmList, OS_INT);
    CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg(lOp,S_NO,lParaArray[1].Location.Register,Location.Register));
  end;
in_x86_pshufw
: //out r0:mm;r1:mm;imm:i32;
  begin
    case InlineNumber of
      in_x86_pshufw: begin lOp:=A_pshufw; end;
      else
        InternalError(2020010201);
    end;

    GetParameters(2);

    for lIndex := 1 to 2 do SecondPass(lParaArray[lIndex]);

    LocationForceMMXReg(CurrentAsmData.CurrAsmList, lParaArray[1].Location, true);
    Location_Reset(Location,LOC_MMXREGISTER,OS_M64);
    Location.Register:=TCGX86(cg).GetMMXRegister(CurrentAsmData.CurrAsmList);
    CurrentAsmData.CurrAsmList.concat(TAICPU.op_const_reg_reg(lOp,S_NO,GetConstInt(lParaArray[2]),lParaArray[1].Location.Register,Location.Register));
  end;
in_x86_pshufw_from_mem
: //out r0:mm;r1:ptr64;imm:i32;
  begin
    case InlineNumber of
      in_x86_pshufw_from_mem: begin lOp:=A_pshufw; end;
      else
        InternalError(2020010201);
    end;

    GetParameters(2);

    for lIndex := 1 to 2 do SecondPass(lParaArray[lIndex]);

    LocationMakeRef(lParaArray[1].Location);
    Location_Reset(Location,LOC_MMXREGISTER,OS_M64);
    Location.Register:=TCGX86(cg).GetMMXRegister(CurrentAsmData.CurrAsmList);
    CurrentAsmData.CurrAsmList.concat(TAICPU.op_const_ref_reg(lOp,S_NO,GetConstInt(lParaArray[2]),lParaArray[1].Location.Reference,Location.Register));
  end;
in_x86_movmskpd
,in_x86_movd_to_reg
: //out r0:r32;r1:xmm;
  begin
    case InlineNumber of
      in_x86_movd_to_reg: begin lOp:=A_movd end;
      in_x86_movmskpd: begin lOp:=A_movmskpd; end;
      else
        InternalError(2020010201);
    end;

    GetParameters(1);

    for lIndex := 1 to 1 do SecondPass(lParaArray[lIndex]);

    Location_Force_MMReg(CurrentAsmData.CurrAsmList, lParaArray[1].Location, true);
    Location_Reset(Location,LOC_REGISTER,OS_32);
    Location.Register:=cg.GetIntRegister(CurrentAsmData.CurrAsmList, OS_32);
    CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg(lOp,S_NO,lParaArray[1].Location.Register,Location.Register));
  end;
in_x86_movsd_to_val
: //out r0:f64;r1:xmm;
  begin
    case InlineNumber of
      in_x86_movsd_to_val: begin lOp:=A_movsd; end;
      else
        InternalError(2020010201);
    end;

    GetParameters(1);

    for lIndex := 1 to 1 do SecondPass(lParaArray[lIndex]);

    Location_Force_MMReg(CurrentAsmData.CurrAsmList, lParaArray[1].Location, true);
    Location_Reset(Location,LOC_MMREGISTER,OS_M128);
    Location.Register:=cg.GetMMRegister(CurrentAsmData.CurrAsmList, OS_M128);
    CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg(lOp,S_NO,lParaArray[1].Location.Register,Location.Register));
  end;
in_x86_movsd_from_val
: //out r0:xmm;r1:f64;
  begin
    case InlineNumber of
      in_x86_movsd_from_val: begin lOp:=A_movsd; end;
      else
        InternalError(2020010201);
    end;

    GetParameters(1);

    for lIndex := 1 to 1 do SecondPass(lParaArray[lIndex]);

    Location_Force_MMReg(CurrentAsmData.CurrAsmList, lParaArray[1].Location, true);
    Location_Reset(Location,LOC_MMREGISTER,OS_M128);
    Location.Register:=cg.GetMMRegister(CurrentAsmData.CurrAsmList, OS_M128);
    CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg(lOp,S_NO,lParaArray[1].Location.Register,Location.Register));
  end;
in_x86_addsd
,in_x86_divsd
,in_x86_minsd
,in_x86_subsd
,in_x86_comisd
,in_x86_ucomisd
,in_x86_cvtss2sd
: //var r0:f64;r1:f64;
  begin
    case InlineNumber of
      in_x86_cvtss2sd: begin lOp:=A_cvtss2sd end;
      in_x86_ucomisd: begin lOp:=A_ucomisd end;
      in_x86_comisd: begin lOp:=A_comisd end;
      in_x86_subsd: begin lOp:=A_subsd end;
      in_x86_minsd: begin lOp:=A_minsd end;
      in_x86_divsd: begin lOp:=A_divsd end;
      in_x86_addsd: begin lOp:=A_addsd; end;
      else
        InternalError(2020010201);
    end;

    GetParameters(2);

    for lIndex := 1 to 2 do SecondPass(lParaArray[lIndex]);

    Location_Force_MMReg(CurrentAsmData.CurrAsmList, lParaArray[1].Location, false);
    Location_Force_MMReg(CurrentAsmData.CurrAsmList, lParaArray[2].Location, true);
    Location:=lParaArray[1].Location;
    CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg(lOp,S_NO,lParaArray[2].Location.Register,lParaArray[1].Location.Register));
  end;
in_x86_addsd_from_mem
,in_x86_divsd_from_mem
,in_x86_minsd_from_mem
,in_x86_mulsd_from_mem
,in_x86_subsd_from_mem
,in_x86_comisd_from_mem
,in_x86_ucomisd_from_mem
: //var r0:f64;r1:ptr64;
  begin
    case InlineNumber of
      in_x86_ucomisd_from_mem: begin lOp:=A_ucomisd end;
      in_x86_comisd_from_mem: begin lOp:=A_comisd end;
      in_x86_subsd_from_mem: begin lOp:=A_subsd end;
      in_x86_mulsd_from_mem: begin lOp:=A_mulsd end;
      in_x86_minsd_from_mem: begin lOp:=A_minsd end;
      in_x86_divsd_from_mem: begin lOp:=A_divsd end;
      in_x86_addsd_from_mem: begin lOp:=A_addsd; end;
      else
        InternalError(2020010201);
    end;

    GetParameters(2);

    for lIndex := 1 to 2 do SecondPass(lParaArray[lIndex]);

    Location_Force_MMReg(CurrentAsmData.CurrAsmList, lParaArray[1].Location, false);
    LocationMakeRef(lParaArray[2].Location);
    Location:=lParaArray[1].Location;
    CurrentAsmData.CurrAsmList.concat(TAICPU.op_ref_reg(lOp,S_NO,lParaArray[2].Location.Reference,lParaArray[1].Location.Register));
  end;
in_x86_maxsd
,in_x86_mulsd
: //var r0:f64;r1:xmm;
  begin
    case InlineNumber of
      in_x86_mulsd: begin lOp:=A_mulsd end;
      in_x86_maxsd: begin lOp:=A_maxsd; end;
      else
        InternalError(2020010201);
    end;

    GetParameters(2);

    for lIndex := 1 to 2 do SecondPass(lParaArray[lIndex]);

    Location_Force_MMReg(CurrentAsmData.CurrAsmList, lParaArray[1].Location, false);
    Location_Force_MMReg(CurrentAsmData.CurrAsmList, lParaArray[2].Location, true);
    Location:=lParaArray[1].Location;
    CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg(lOp,S_NO,lParaArray[2].Location.Register,lParaArray[1].Location.Register));
  end;
in_x86_sqrtpd
,in_x86_movddup
,in_x86_movsldup
,in_x86_movshdup
,in_x86_pabsb
,in_x86_pabsw
,in_x86_pabsd
,in_x86_pmovsxbw
,in_x86_pmovzxbw
,in_x86_pmovsxbd
,in_x86_pmovzxbd
,in_x86_pmovsxbq
,in_x86_pmovzxbq
,in_x86_pmovsxwd
,in_x86_pmovzxwd
,in_x86_pmovsxwq
,in_x86_pmovzxwq
,in_x86_pmovsxdq
,in_x86_pmovzxdq
: //out r0:xmm;r1:xmm;
  begin
    case InlineNumber of
      in_x86_pmovzxdq: begin lOp:=A_pmovzxdq end;
      in_x86_pmovsxdq: begin lOp:=A_pmovsxdq end;
      in_x86_pmovzxwq: begin lOp:=A_pmovzxwq end;
      in_x86_pmovsxwq: begin lOp:=A_pmovsxwq end;
      in_x86_pmovzxwd: begin lOp:=A_pmovzxwd end;
      in_x86_pmovsxwd: begin lOp:=A_pmovsxwd end;
      in_x86_pmovzxbq: begin lOp:=A_pmovzxbq end;
      in_x86_pmovsxbq: begin lOp:=A_pmovsxbq end;
      in_x86_pmovzxbd: begin lOp:=A_pmovzxbd end;
      in_x86_pmovsxbd: begin lOp:=A_pmovsxbd end;
      in_x86_pmovzxbw: begin lOp:=A_pmovzxbw end;
      in_x86_pmovsxbw: begin lOp:=A_pmovsxbw end;
      in_x86_pabsd: begin lOp:=A_pabsd end;
      in_x86_pabsw: begin lOp:=A_pabsw end;
      in_x86_pabsb: begin lOp:=A_pabsb end;
      in_x86_movshdup: begin lOp:=A_movshdup end;
      in_x86_movsldup: begin lOp:=A_movsldup end;
      in_x86_movddup: begin lOp:=A_movddup end;
      in_x86_sqrtpd: begin lOp:=A_sqrtpd; end;
      else
        InternalError(2020010201);
    end;

    GetParameters(1);

    for lIndex := 1 to 1 do SecondPass(lParaArray[lIndex]);

    Location_Force_MMReg(CurrentAsmData.CurrAsmList, lParaArray[1].Location, true);
    Location_Reset(Location,LOC_MMREGISTER,OS_M128);
    Location.Register:=cg.GetMMRegister(CurrentAsmData.CurrAsmList, OS_M128);
    CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg(lOp,S_NO,lParaArray[1].Location.Register,Location.Register));
  end;
in_x86_sqrtsd
: //out r0:f64;r1:f64;
  begin
    case InlineNumber of
      in_x86_sqrtsd: begin lOp:=A_sqrtsd; end;
      else
        InternalError(2020010201);
    end;

    GetParameters(1);

    for lIndex := 1 to 1 do SecondPass(lParaArray[lIndex]);

    Location_Force_MMReg(CurrentAsmData.CurrAsmList, lParaArray[1].Location, true);
    Location_Reset(Location,LOC_MMREGISTER,OS_M128);
    Location.Register:=cg.GetMMRegister(CurrentAsmData.CurrAsmList, OS_M128);
    CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg(lOp,S_NO,lParaArray[1].Location.Register,Location.Register));
  end;
in_x86_sqrtsd_from_mem
: //out r0:f64;r1:ptr64;
  begin
    case InlineNumber of
      in_x86_sqrtsd_from_mem: begin lOp:=A_sqrtsd; end;
      else
        InternalError(2020010201);
    end;

    GetParameters(1);

    for lIndex := 1 to 1 do SecondPass(lParaArray[lIndex]);

    LocationMakeRef(lParaArray[1].Location);
    Location_Reset(Location,LOC_MMREGISTER,OS_M128);
    Location.Register:=cg.GetMMRegister(CurrentAsmData.CurrAsmList, OS_M128);
    CurrentAsmData.CurrAsmList.concat(TAICPU.op_ref_reg(lOp,S_NO,lParaArray[1].Location.Reference,Location.Register));
  end;
in_x86_cmpsd
: //var r0:f64;r1:f64;imm:i32;
  begin
    case InlineNumber of
      in_x86_cmpsd: begin lOp:=A_cmpsd; end;
      else
        InternalError(2020010201);
    end;

    GetParameters(3);

    for lIndex := 1 to 3 do SecondPass(lParaArray[lIndex]);

    Location_Force_MMReg(CurrentAsmData.CurrAsmList, lParaArray[1].Location, false);
    Location_Force_MMReg(CurrentAsmData.CurrAsmList, lParaArray[2].Location, true);
    Location:=lParaArray[1].Location;
    CurrentAsmData.CurrAsmList.concat(TAICPU.op_const_reg_reg(lOp,S_NO,GetConstInt(lParaArray[3]),lParaArray[2].Location.Register,lParaArray[1].Location.Register));
  end;
in_x86_cmpsd_from_mem
: //var r0:f64;r1:ptr64;imm:i32;
  begin
    case InlineNumber of
      in_x86_cmpsd_from_mem: begin lOp:=A_cmpsd; end;
      else
        InternalError(2020010201);
    end;

    GetParameters(3);

    for lIndex := 1 to 3 do SecondPass(lParaArray[lIndex]);

    Location_Force_MMReg(CurrentAsmData.CurrAsmList, lParaArray[1].Location, false);
    LocationMakeRef(lParaArray[2].Location);
    Location:=lParaArray[1].Location;
    CurrentAsmData.CurrAsmList.concat(TAICPU.op_const_ref_reg(lOp,S_NO,GetConstInt(lParaArray[3]),lParaArray[2].Location.Reference,lParaArray[1].Location.Register));
  end;
in_x86_cvtpd2pi
,in_x86_cvttpd2pi
: //var r0:mm;r1:xmm;
  begin
    case InlineNumber of
      in_x86_cvttpd2pi: begin lOp:=A_cvttpd2pi end;
      in_x86_cvtpd2pi: begin lOp:=A_cvtpd2pi; end;
      else
        InternalError(2020010201);
    end;

    GetParameters(2);

    for lIndex := 1 to 2 do SecondPass(lParaArray[lIndex]);

    LocationForceMMXReg(CurrentAsmData.CurrAsmList, lParaArray[1].Location, false);
    Location_Force_MMReg(CurrentAsmData.CurrAsmList, lParaArray[2].Location, true);
    Location:=lParaArray[1].Location;
    CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg(lOp,S_NO,lParaArray[2].Location.Register,lParaArray[1].Location.Register));
  end;
in_x86_cvtpd2pi_from_mem
,in_x86_cvttpd2pi_from_mem
: //var r0:mm;r1:ptr128;
  begin
    case InlineNumber of
      in_x86_cvttpd2pi_from_mem: begin lOp:=A_cvttpd2pi end;
      in_x86_cvtpd2pi_from_mem: begin lOp:=A_cvtpd2pi; end;
      else
        InternalError(2020010201);
    end;

    GetParameters(2);

    for lIndex := 1 to 2 do SecondPass(lParaArray[lIndex]);

    LocationForceMMXReg(CurrentAsmData.CurrAsmList, lParaArray[1].Location, false);
    LocationMakeRef(lParaArray[2].Location);
    Location:=lParaArray[1].Location;
    CurrentAsmData.CurrAsmList.concat(TAICPU.op_ref_reg(lOp,S_NO,lParaArray[2].Location.Reference,lParaArray[1].Location.Register));
  end;
in_x86_cvtsd2si
,in_x86_cvttsd2si
: //var r0:sreg;r1:xmm;
  begin
    case InlineNumber of
      in_x86_cvttsd2si: begin lOp:=A_cvttsd2si end;
      in_x86_cvtsd2si: begin lOp:=A_cvtsd2si; end;
      else
        InternalError(2020010201);
    end;

    GetParameters(2);

    for lIndex := 1 to 2 do SecondPass(lParaArray[lIndex]);

    hlcg.Location_Force_Reg(CurrentAsmData.CurrAsmList, lParaArray[1].Location, lParaArray[1].ResultDef,SIntType,false);
    Location_Force_MMReg(CurrentAsmData.CurrAsmList, lParaArray[2].Location, true);
    Location:=lParaArray[1].Location;
    CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg(lOp,S_NO,lParaArray[2].Location.Register,lParaArray[1].Location.Register));
  end;
in_x86_cvtsd2si_from_mem
,in_x86_cvttsd2si_from_mem
: //var r0:sreg;r1:ptr64;
  begin
    case InlineNumber of
      in_x86_cvttsd2si_from_mem: begin lOp:=A_cvttsd2si end;
      in_x86_cvtsd2si_from_mem: begin lOp:=A_cvtsd2si; end;
      else
        InternalError(2020010201);
    end;

    GetParameters(2);

    for lIndex := 1 to 2 do SecondPass(lParaArray[lIndex]);

    hlcg.Location_Force_Reg(CurrentAsmData.CurrAsmList, lParaArray[1].Location, lParaArray[1].ResultDef,SIntType,false);
    LocationMakeRef(lParaArray[2].Location);
    Location:=lParaArray[1].Location;
    CurrentAsmData.CurrAsmList.concat(TAICPU.op_ref_reg(lOp,S_NO,lParaArray[2].Location.Reference,lParaArray[1].Location.Register));
  end;
in_x86_cvtsi2sd
: //var r0:f64;r1:r32;
  begin
    case InlineNumber of
      in_x86_cvtsi2sd: begin lOp:=A_cvtsi2sd; end;
      else
        InternalError(2020010201);
    end;

    GetParameters(2);

    for lIndex := 1 to 2 do SecondPass(lParaArray[lIndex]);

    Location_Force_MMReg(CurrentAsmData.CurrAsmList, lParaArray[1].Location, false);
    hlcg.Location_Force_Reg(CurrentAsmData.CurrAsmList, lParaArray[2].Location, lParaArray[2].ResultDef,U32IntType,true);
    Location:=lParaArray[1].Location;
    CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg(lOp,S_NO,lParaArray[2].Location.Register,lParaArray[1].Location.Register));
  end;
in_x86_cvtsi2sd_from_mem
,in_x86_cvtss2sd_from_mem
: //var r0:f64;r1:ptr32;
  begin
    case InlineNumber of
      in_x86_cvtss2sd_from_mem: begin lOp:=A_cvtss2sd end;
      in_x86_cvtsi2sd_from_mem: begin lOp:=A_cvtsi2sd; end;
      else
        InternalError(2020010201);
    end;

    GetParameters(2);

    for lIndex := 1 to 2 do SecondPass(lParaArray[lIndex]);

    Location_Force_MMReg(CurrentAsmData.CurrAsmList, lParaArray[1].Location, false);
    LocationMakeRef(lParaArray[2].Location);
    Location:=lParaArray[1].Location;
    CurrentAsmData.CurrAsmList.concat(TAICPU.op_ref_reg(lOp,S_NO,lParaArray[2].Location.Reference,lParaArray[1].Location.Register));
  end;
in_x86_movd_from_reg
: //out r0:xmm;r1:r32;
  begin
    case InlineNumber of
      in_x86_movd_from_reg: begin lOp:=A_movd; end;
      else
        InternalError(2020010201);
    end;

    GetParameters(1);

    for lIndex := 1 to 1 do SecondPass(lParaArray[lIndex]);

    hlcg.Location_Force_Reg(CurrentAsmData.CurrAsmList, lParaArray[1].Location, lParaArray[1].ResultDef,U32IntType,true);
    Location_Reset(Location,LOC_MMREGISTER,OS_M128);
    Location.Register:=cg.GetMMRegister(CurrentAsmData.CurrAsmList, OS_M128);
    CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg(lOp,S_NO,lParaArray[1].Location.Register,Location.Register));
  end;
in_x86_movq_from_mem
,in_x86_movddup_from_mem
,in_x86_pmovsxbw_from_mem
,in_x86_pmovzxbw_from_mem
,in_x86_pmovsxwd_from_mem
,in_x86_pmovzxwd_from_mem
,in_x86_pmovsxdq_from_mem
,in_x86_pmovzxdq_from_mem
: //out r0:xmm;r1:ptr64;
  begin
    case InlineNumber of
      in_x86_pmovzxdq_from_mem: begin lOp:=A_pmovzxdq end;
      in_x86_pmovsxdq_from_mem: begin lOp:=A_pmovsxdq end;
      in_x86_pmovzxwd_from_mem: begin lOp:=A_pmovzxwd end;
      in_x86_pmovsxwd_from_mem: begin lOp:=A_pmovsxwd end;
      in_x86_pmovzxbw_from_mem: begin lOp:=A_pmovzxbw end;
      in_x86_pmovsxbw_from_mem: begin lOp:=A_pmovsxbw end;
      in_x86_movddup_from_mem: begin lOp:=A_movddup end;
      in_x86_movq_from_mem: begin lOp:=A_movq; end;
      else
        InternalError(2020010201);
    end;

    GetParameters(1);

    for lIndex := 1 to 1 do SecondPass(lParaArray[lIndex]);

    LocationMakeRef(lParaArray[1].Location);
    Location_Reset(Location,LOC_MMREGISTER,OS_M128);
    Location.Register:=cg.GetMMRegister(CurrentAsmData.CurrAsmList, OS_M128);
    CurrentAsmData.CurrAsmList.concat(TAICPU.op_ref_reg(lOp,S_NO,lParaArray[1].Location.Reference,Location.Register));
  end;
in_x86_pmovmskb
: //var r0:r32;r1:xmm;
  begin
    case InlineNumber of
      in_x86_pmovmskb: begin lOp:=A_pmovmskb; end;
      else
        InternalError(2020010201);
    end;

    GetParameters(2);

    for lIndex := 1 to 2 do SecondPass(lParaArray[lIndex]);

    hlcg.Location_Force_Reg(CurrentAsmData.CurrAsmList, lParaArray[1].Location, lParaArray[1].ResultDef,U32IntType,false);
    Location_Force_MMReg(CurrentAsmData.CurrAsmList, lParaArray[2].Location, true);
    Location:=lParaArray[1].Location;
    CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg(lOp,S_NO,lParaArray[2].Location.Register,lParaArray[1].Location.Register));
  end;
in_x86_pextrw_sse2
: //out r0:r16;r1:xmm;imm:i32;
  begin
    case InlineNumber of
      in_x86_pextrw_sse2: begin lOp:=A_pextrw; end;
      else
        InternalError(2020010201);
    end;

    GetParameters(2);

    for lIndex := 1 to 2 do SecondPass(lParaArray[lIndex]);

    Location_Force_MMReg(CurrentAsmData.CurrAsmList, lParaArray[1].Location, true);
    Location_Reset(Location,LOC_REGISTER,OS_16);
    Location.Register:=cg.GetIntRegister(CurrentAsmData.CurrAsmList, OS_16);
    CurrentAsmData.CurrAsmList.concat(TAICPU.op_const_reg_reg(lOp,S_NO,GetConstInt(lParaArray[2]),lParaArray[1].Location.Register,Location.Register));
  end;
in_x86_pinsrw_sse2
,in_x86_pinsrb
,in_x86_pinsrd
: //var r0:xmm;r1:r32;imm:i32;
  begin
    case InlineNumber of
      in_x86_pinsrd: begin lOp:=A_pinsrd end;
      in_x86_pinsrb: begin lOp:=A_pinsrb end;
      in_x86_pinsrw_sse2: begin lOp:=A_pinsrw; end;
      else
        InternalError(2020010201);
    end;

    GetParameters(3);

    for lIndex := 1 to 3 do SecondPass(lParaArray[lIndex]);

    Location_Force_MMReg(CurrentAsmData.CurrAsmList, lParaArray[1].Location, false);
    hlcg.Location_Force_Reg(CurrentAsmData.CurrAsmList, lParaArray[2].Location, lParaArray[2].ResultDef,U32IntType,true);
    Location:=lParaArray[1].Location;
    CurrentAsmData.CurrAsmList.concat(TAICPU.op_const_reg_reg(lOp,S_NO,GetConstInt(lParaArray[3]),lParaArray[2].Location.Register,lParaArray[1].Location.Register));
  end;
in_x86_pinsrw_from_mem
: //var r0:xmm;r1:ptr16;imm:i32;
  begin
    case InlineNumber of
      in_x86_pinsrw_from_mem: begin lOp:=A_pinsrw; end;
      else
        InternalError(2020010201);
    end;

    GetParameters(3);

    for lIndex := 1 to 3 do SecondPass(lParaArray[lIndex]);

    Location_Force_MMReg(CurrentAsmData.CurrAsmList, lParaArray[1].Location, false);
    LocationMakeRef(lParaArray[2].Location);
    Location:=lParaArray[1].Location;
    CurrentAsmData.CurrAsmList.concat(TAICPU.op_const_ref_reg(lOp,S_NO,GetConstInt(lParaArray[3]),lParaArray[2].Location.Reference,lParaArray[1].Location.Register));
  end;
in_x86_psllw_sse2_imm
,in_x86_pslld_sse2_imm
,in_x86_psllq_sse2_imm
,in_x86_psrad_sse2_imm
,in_x86_psraw_sse2_imm
,in_x86_psrlw_sse2_imm
,in_x86_psrld_sse2_imm
,in_x86_psrlq_sse2_imm
,in_x86_pslldq
,in_x86_psrldq
: //var r0:xmm;imm:i32;
  begin
    case InlineNumber of
      in_x86_psrldq: begin lOp:=A_psrldq end;
      in_x86_pslldq: begin lOp:=A_pslldq end;
      in_x86_psrlq_sse2_imm: begin lOp:=A_psrlq end;
      in_x86_psrld_sse2_imm: begin lOp:=A_psrld end;
      in_x86_psrlw_sse2_imm: begin lOp:=A_psrlw end;
      in_x86_psraw_sse2_imm: begin lOp:=A_psraw end;
      in_x86_psrad_sse2_imm: begin lOp:=A_psrad end;
      in_x86_psllq_sse2_imm: begin lOp:=A_psllq end;
      in_x86_pslld_sse2_imm: begin lOp:=A_pslld end;
      in_x86_psllw_sse2_imm: begin lOp:=A_psllw; end;
      else
        InternalError(2020010201);
    end;

    GetParameters(2);

    for lIndex := 1 to 2 do SecondPass(lParaArray[lIndex]);

    Location_Force_MMReg(CurrentAsmData.CurrAsmList, lParaArray[1].Location, false);
    Location:=lParaArray[1].Location;
    CurrentAsmData.CurrAsmList.concat(TAICPU.op_const_reg(lOp,S_NO,GetConstInt(lParaArray[2]),lParaArray[1].Location.Register));
  end;
in_x86_maskmovdqu
: //addr:edi_ptr;r0:xmm;r1:xmm;
  begin
    case InlineNumber of
      in_x86_maskmovdqu: begin lOp:=A_maskmovdqu; end;
      else
        InternalError(2020010201);
    end;

    GetParameters(3);

    for lIndex := 1 to 3 do SecondPass(lParaArray[lIndex]);

    hlcg.GetCPURegister(CurrentAsmData.CurrAsmList,{$if defined(cpu64bitalu)}NR_RDI{$else}NR_EDI{$endif});
    hlcg.A_Load_Loc_Reg(CurrentAsmData.CurrAsmList,lParaArray[1].ResultDef,VoidPointerType,lParaArray[1].Location,{$if defined(cpu64bitalu)}NR_RDI{$else}NR_EDI{$endif});
    Location_Force_MMReg(CurrentAsmData.CurrAsmList, lParaArray[2].Location, true);
    Location_Force_MMReg(CurrentAsmData.CurrAsmList, lParaArray[3].Location, true);
    CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg(lOp,S_NO,lParaArray[3].Location.Register,lParaArray[2].Location.Register));
    hlcg.UngetCPURegister(CurrentAsmData.CurrAsmList,{$if defined(cpu64bitalu)}NR_RDI{$else}NR_EDI{$endif});
  end;
in_x86_movq2dq
: //out r0:xmm;r1:mm;
  begin
    case InlineNumber of
      in_x86_movq2dq: begin lOp:=A_movq2dq; end;
      else
        InternalError(2020010201);
    end;

    GetParameters(1);

    for lIndex := 1 to 1 do SecondPass(lParaArray[lIndex]);

    LocationForceMMXReg(CurrentAsmData.CurrAsmList, lParaArray[1].Location, true);
    Location_Reset(Location,LOC_MMREGISTER,OS_M128);
    Location.Register:=cg.GetMMRegister(CurrentAsmData.CurrAsmList, OS_M128);
    CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg(lOp,S_NO,lParaArray[1].Location.Register,Location.Register));
  end;
in_x86_pshufhw
,in_x86_pshuflw
,in_x86_pshufd
,in_x86_roundps
,in_x86_roundss
,in_x86_roundpd
: //out r0:xmm;r1:xmm;imm:i32;
  begin
    case InlineNumber of
      in_x86_roundpd: begin lOp:=A_roundpd end;
      in_x86_roundss: begin lOp:=A_roundss end;
      in_x86_roundps: begin lOp:=A_roundps end;
      in_x86_pshufd: begin lOp:=A_pshufd end;
      in_x86_pshuflw: begin lOp:=A_pshuflw end;
      in_x86_pshufhw: begin lOp:=A_pshufhw; end;
      else
        InternalError(2020010201);
    end;

    GetParameters(2);

    for lIndex := 1 to 2 do SecondPass(lParaArray[lIndex]);

    Location_Force_MMReg(CurrentAsmData.CurrAsmList, lParaArray[1].Location, true);
    Location_Reset(Location,LOC_MMREGISTER,OS_M128);
    Location.Register:=cg.GetMMRegister(CurrentAsmData.CurrAsmList, OS_M128);
    CurrentAsmData.CurrAsmList.concat(TAICPU.op_const_reg_reg(lOp,S_NO,GetConstInt(lParaArray[2]),lParaArray[1].Location.Register,Location.Register));
  end;
in_x86_pshufhw_from_mem
,in_x86_pshuflw_from_mem
,in_x86_pshufd_from_mem
,in_x86_roundps_from_mem
,in_x86_roundpd_from_mem
: //out r0:xmm;r1:ptr128;imm:i32;
  begin
    case InlineNumber of
      in_x86_roundpd_from_mem: begin lOp:=A_roundpd end;
      in_x86_roundps_from_mem: begin lOp:=A_roundps end;
      in_x86_pshufd_from_mem: begin lOp:=A_pshufd end;
      in_x86_pshuflw_from_mem: begin lOp:=A_pshuflw end;
      in_x86_pshufhw_from_mem: begin lOp:=A_pshufhw; end;
      else
        InternalError(2020010201);
    end;

    GetParameters(2);

    for lIndex := 1 to 2 do SecondPass(lParaArray[lIndex]);

    LocationMakeRef(lParaArray[1].Location);
    Location_Reset(Location,LOC_MMREGISTER,OS_M128);
    Location.Register:=cg.GetMMRegister(CurrentAsmData.CurrAsmList, OS_M128);
    CurrentAsmData.CurrAsmList.concat(TAICPU.op_const_ref_reg(lOp,S_NO,GetConstInt(lParaArray[2]),lParaArray[1].Location.Reference,Location.Register));
  end;
in_x86_blendvps
,in_x86_blendvpd
,in_x86_pblendvb
: //var r0:xmm;r1:xmm;mask:implicit_xmm0;
  begin
    case InlineNumber of
      in_x86_pblendvb: begin lOp:=A_pblendvb end;
      in_x86_blendvpd: begin lOp:=A_blendvpd end;
      in_x86_blendvps: begin lOp:=A_blendvps; end;
      else
        InternalError(2020010201);
    end;

    GetParameters(3);

    for lIndex := 1 to 3 do SecondPass(lParaArray[lIndex]);

    Location_Force_MMReg(CurrentAsmData.CurrAsmList, lParaArray[1].Location, false);
    Location_Force_MMReg(CurrentAsmData.CurrAsmList, lParaArray[2].Location, true);
    Location_Force_MMReg(CurrentAsmData.CurrAsmList, lParaArray[3].Location, true);
    hlcg.GetCPURegister(CurrentAsmData.CurrAsmList,NR_XMM0);
    hlcg.A_LoadMM_Loc_Reg(CurrentAsmData.CurrAsmList,lParaArray[3].ResultDef,X86_M128Type,lParaArray[3].Location,NR_XMM0,nil);
    Location:=lParaArray[1].Location;
    CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg(lOp,S_NO,lParaArray[2].Location.Register,lParaArray[1].Location.Register));
    hlcg.UngetCPURegister(CurrentAsmData.CurrAsmList,NR_XMM0);
  end;
in_x86_blendvps_from_mem
,in_x86_blendvpd_from_mem
,in_x86_pblendvb_from_mem
: //var r0:xmm;r1:ptr128;mask:implicit_xmm0;
  begin
    case InlineNumber of
      in_x86_pblendvb_from_mem: begin lOp:=A_pblendvb end;
      in_x86_blendvpd_from_mem: begin lOp:=A_blendvpd end;
      in_x86_blendvps_from_mem: begin lOp:=A_blendvps; end;
      else
        InternalError(2020010201);
    end;

    GetParameters(3);

    for lIndex := 1 to 3 do SecondPass(lParaArray[lIndex]);

    Location_Force_MMReg(CurrentAsmData.CurrAsmList, lParaArray[1].Location, false);
    LocationMakeRef(lParaArray[2].Location);
    Location_Force_MMReg(CurrentAsmData.CurrAsmList, lParaArray[3].Location, true);
    hlcg.GetCPURegister(CurrentAsmData.CurrAsmList,NR_XMM0);
    hlcg.A_LoadMM_Loc_Reg(CurrentAsmData.CurrAsmList,lParaArray[3].ResultDef,X86_M128Type,lParaArray[3].Location,NR_XMM0,nil);
    Location:=lParaArray[1].Location;
    CurrentAsmData.CurrAsmList.concat(TAICPU.op_ref_reg(lOp,S_NO,lParaArray[2].Location.Reference,lParaArray[1].Location.Register));
    hlcg.UngetCPURegister(CurrentAsmData.CurrAsmList,NR_XMM0);
  end;
in_x86_roundss_from_mem
: //out r0:xmm;r1:ptr32;imm:i32;
  begin
    case InlineNumber of
      in_x86_roundss_from_mem: begin lOp:=A_roundss; end;
      else
        InternalError(2020010201);
    end;

    GetParameters(2);

    for lIndex := 1 to 2 do SecondPass(lParaArray[lIndex]);

    LocationMakeRef(lParaArray[1].Location);
    Location_Reset(Location,LOC_MMREGISTER,OS_M128);
    Location.Register:=cg.GetMMRegister(CurrentAsmData.CurrAsmList, OS_M128);
    CurrentAsmData.CurrAsmList.concat(TAICPU.op_const_ref_reg(lOp,S_NO,GetConstInt(lParaArray[2]),lParaArray[1].Location.Reference,Location.Register));
  end;
in_x86_roundsd
: //out r0:f64;r1:f64;imm:i32;
  begin
    case InlineNumber of
      in_x86_roundsd: begin lOp:=A_roundsd; end;
      else
        InternalError(2020010201);
    end;

    GetParameters(2);

    for lIndex := 1 to 2 do SecondPass(lParaArray[lIndex]);

    Location_Force_MMReg(CurrentAsmData.CurrAsmList, lParaArray[1].Location, true);
    Location_Reset(Location,LOC_MMREGISTER,OS_M128);
    Location.Register:=cg.GetMMRegister(CurrentAsmData.CurrAsmList, OS_M128);
    CurrentAsmData.CurrAsmList.concat(TAICPU.op_const_reg_reg(lOp,S_NO,GetConstInt(lParaArray[2]),lParaArray[1].Location.Register,Location.Register));
  end;
in_x86_roundsd_from_mem
: //out r0:f64;r1:ptr64;imm:i32;
  begin
    case InlineNumber of
      in_x86_roundsd_from_mem: begin lOp:=A_roundsd; end;
      else
        InternalError(2020010201);
    end;

    GetParameters(2);

    for lIndex := 1 to 2 do SecondPass(lParaArray[lIndex]);

    LocationMakeRef(lParaArray[1].Location);
    Location_Reset(Location,LOC_MMREGISTER,OS_M128);
    Location.Register:=cg.GetMMRegister(CurrentAsmData.CurrAsmList, OS_M128);
    CurrentAsmData.CurrAsmList.concat(TAICPU.op_const_ref_reg(lOp,S_NO,GetConstInt(lParaArray[2]),lParaArray[1].Location.Reference,Location.Register));
  end;
in_x86_insertps_from_mem
,in_x86_pinsrd_from_mem
: //var r0:xmm;r1:ptr32;imm:i32;
  begin
    case InlineNumber of
      in_x86_pinsrd_from_mem: begin lOp:=A_pinsrd end;
      in_x86_insertps_from_mem: begin lOp:=A_insertps; end;
      else
        InternalError(2020010201);
    end;

    GetParameters(3);

    for lIndex := 1 to 3 do SecondPass(lParaArray[lIndex]);

    Location_Force_MMReg(CurrentAsmData.CurrAsmList, lParaArray[1].Location, false);
    LocationMakeRef(lParaArray[2].Location);
    Location:=lParaArray[1].Location;
    CurrentAsmData.CurrAsmList.concat(TAICPU.op_const_ref_reg(lOp,S_NO,GetConstInt(lParaArray[3]),lParaArray[2].Location.Reference,lParaArray[1].Location.Register));
  end;
in_x86_extractps
,in_x86_pextrd
: //out r0:r32;r1:xmm;imm:i32;
  begin
    case InlineNumber of
      in_x86_pextrd: begin lOp:=A_pextrd end;
      in_x86_extractps: begin lOp:=A_extractps; end;
      else
        InternalError(2020010201);
    end;

    GetParameters(2);

    for lIndex := 1 to 2 do SecondPass(lParaArray[lIndex]);

    Location_Force_MMReg(CurrentAsmData.CurrAsmList, lParaArray[1].Location, true);
    Location_Reset(Location,LOC_REGISTER,OS_32);
    Location.Register:=cg.GetIntRegister(CurrentAsmData.CurrAsmList, OS_32);
    CurrentAsmData.CurrAsmList.concat(TAICPU.op_const_reg_reg(lOp,S_NO,GetConstInt(lParaArray[2]),lParaArray[1].Location.Register,Location.Register));
  end;
in_x86_extractps_from_mem
,in_x86_pextrd_to_mem
: //r0:ptr32;r1:xmm;imm:i32;
  begin
    case InlineNumber of
      in_x86_pextrd_to_mem: begin lOp:=A_pextrd end;
      in_x86_extractps_from_mem: begin lOp:=A_extractps; end;
      else
        InternalError(2020010201);
    end;

    GetParameters(3);

    for lIndex := 1 to 3 do SecondPass(lParaArray[lIndex]);

    LocationMakeRef(lParaArray[1].Location);
    Location_Force_MMReg(CurrentAsmData.CurrAsmList, lParaArray[2].Location, true);
    CurrentAsmData.CurrAsmList.concat(TAICPU.op_const_reg_ref(lOp,S_NO,GetConstInt(lParaArray[3]),lParaArray[2].Location.Register,lParaArray[1].Location.Reference));
  end;
in_x86_pinsrb_from_mem
: //var r0:xmm;r1:ptr8;imm:i32;
  begin
    case InlineNumber of
      in_x86_pinsrb_from_mem: begin lOp:=A_pinsrb; end;
      else
        InternalError(2020010201);
    end;

    GetParameters(3);

    for lIndex := 1 to 3 do SecondPass(lParaArray[lIndex]);

    Location_Force_MMReg(CurrentAsmData.CurrAsmList, lParaArray[1].Location, false);
    LocationMakeRef(lParaArray[2].Location);
    Location:=lParaArray[1].Location;
    CurrentAsmData.CurrAsmList.concat(TAICPU.op_const_ref_reg(lOp,S_NO,GetConstInt(lParaArray[3]),lParaArray[2].Location.Reference,lParaArray[1].Location.Register));
  end;
{$ifdef X86_64}
in_x86_pinsrq
: //var r0:xmm;r1:reg;imm:i32;
  begin
    case InlineNumber of
      in_x86_pinsrq: begin lOp:=A_pinsrq; end;
      else
        InternalError(2020010201);
    end;

    GetParameters(3);

    for lIndex := 1 to 3 do SecondPass(lParaArray[lIndex]);

    Location_Force_MMReg(CurrentAsmData.CurrAsmList, lParaArray[1].Location, false);
    hlcg.Location_Force_Reg(CurrentAsmData.CurrAsmList, lParaArray[2].Location, lParaArray[2].ResultDef,UIntType,true);
    Location:=lParaArray[1].Location;
    CurrentAsmData.CurrAsmList.concat(TAICPU.op_const_reg_reg(lOp,S_NO,GetConstInt(lParaArray[3]),lParaArray[2].Location.Register,lParaArray[1].Location.Register));
  end;
{$endif}
{$ifdef X86_64}
in_x86_pinsrq_from_mem
: //var r0:xmm;r1:ptr64;imm:i32;
  begin
    case InlineNumber of
      in_x86_pinsrq_from_mem: begin lOp:=A_pinsrq; end;
      else
        InternalError(2020010201);
    end;

    GetParameters(3);

    for lIndex := 1 to 3 do SecondPass(lParaArray[lIndex]);

    Location_Force_MMReg(CurrentAsmData.CurrAsmList, lParaArray[1].Location, false);
    LocationMakeRef(lParaArray[2].Location);
    Location:=lParaArray[1].Location;
    CurrentAsmData.CurrAsmList.concat(TAICPU.op_const_ref_reg(lOp,S_NO,GetConstInt(lParaArray[3]),lParaArray[2].Location.Reference,lParaArray[1].Location.Register));
  end;
{$endif}
in_x86_pextrb
: //out r0:r8;r1:xmm;imm:i32;
  begin
    case InlineNumber of
      in_x86_pextrb: begin lOp:=A_pextrb; end;
      else
        InternalError(2020010201);
    end;

    GetParameters(2);

    for lIndex := 1 to 2 do SecondPass(lParaArray[lIndex]);

    Location_Force_MMReg(CurrentAsmData.CurrAsmList, lParaArray[1].Location, true);
    Location_Reset(Location,LOC_REGISTER,OS_8);
    Location.Register:=cg.GetIntRegister(CurrentAsmData.CurrAsmList, OS_8);
    CurrentAsmData.CurrAsmList.concat(TAICPU.op_const_reg_reg(lOp,S_NO,GetConstInt(lParaArray[2]),lParaArray[1].Location.Register,Location.Register));
  end;
in_x86_pextrb_to_mem
: //r0:ptr8;r1:xmm;imm:i32;
  begin
    case InlineNumber of
      in_x86_pextrb_to_mem: begin lOp:=A_pextrb; end;
      else
        InternalError(2020010201);
    end;

    GetParameters(3);

    for lIndex := 1 to 3 do SecondPass(lParaArray[lIndex]);

    LocationMakeRef(lParaArray[1].Location);
    Location_Force_MMReg(CurrentAsmData.CurrAsmList, lParaArray[2].Location, true);
    CurrentAsmData.CurrAsmList.concat(TAICPU.op_const_reg_ref(lOp,S_NO,GetConstInt(lParaArray[3]),lParaArray[2].Location.Register,lParaArray[1].Location.Reference));
  end;
in_x86_pextrw_sse41_to_mem
: //r0:ptr16;r1:xmm;imm:i32;
  begin
    case InlineNumber of
      in_x86_pextrw_sse41_to_mem: begin lOp:=A_pextrw; end;
      else
        InternalError(2020010201);
    end;

    GetParameters(3);

    for lIndex := 1 to 3 do SecondPass(lParaArray[lIndex]);

    LocationMakeRef(lParaArray[1].Location);
    Location_Force_MMReg(CurrentAsmData.CurrAsmList, lParaArray[2].Location, true);
    CurrentAsmData.CurrAsmList.concat(TAICPU.op_const_reg_ref(lOp,S_NO,GetConstInt(lParaArray[3]),lParaArray[2].Location.Register,lParaArray[1].Location.Reference));
  end;
{$ifdef X86_64}
in_x86_pextrq
: //out r0:r32;r1:xmm;imm:i32;
  begin
    case InlineNumber of
      in_x86_pextrq: begin lOp:=A_pextrq; end;
      else
        InternalError(2020010201);
    end;

    GetParameters(2);

    for lIndex := 1 to 2 do SecondPass(lParaArray[lIndex]);

    Location_Force_MMReg(CurrentAsmData.CurrAsmList, lParaArray[1].Location, true);
    Location_Reset(Location,LOC_REGISTER,OS_32);
    Location.Register:=cg.GetIntRegister(CurrentAsmData.CurrAsmList, OS_32);
    CurrentAsmData.CurrAsmList.concat(TAICPU.op_const_reg_reg(lOp,S_NO,GetConstInt(lParaArray[2]),lParaArray[1].Location.Register,Location.Register));
  end;
{$endif}
{$ifdef X86_64}
in_x86_pextrq_to_mem
: //r0:ptr64;r1:xmm;imm:i32;
  begin
    case InlineNumber of
      in_x86_pextrq_to_mem: begin lOp:=A_pextrq; end;
      else
        InternalError(2020010201);
    end;

    GetParameters(3);

    for lIndex := 1 to 3 do SecondPass(lParaArray[lIndex]);

    LocationMakeRef(lParaArray[1].Location);
    Location_Force_MMReg(CurrentAsmData.CurrAsmList, lParaArray[2].Location, true);
    CurrentAsmData.CurrAsmList.concat(TAICPU.op_const_reg_ref(lOp,S_NO,GetConstInt(lParaArray[3]),lParaArray[2].Location.Register,lParaArray[1].Location.Reference));
  end;
{$endif}
in_x86_pmovsxbq_from_mem
,in_x86_pmovzxbq_from_mem
: //out r0:xmm;r1:ptr16;
  begin
    case InlineNumber of
      in_x86_pmovzxbq_from_mem: begin lOp:=A_pmovzxbq end;
      in_x86_pmovsxbq_from_mem: begin lOp:=A_pmovsxbq; end;
      else
        InternalError(2020010201);
    end;

    GetParameters(1);

    for lIndex := 1 to 1 do SecondPass(lParaArray[lIndex]);

    LocationMakeRef(lParaArray[1].Location);
    Location_Reset(Location,LOC_MMREGISTER,OS_M128);
    Location.Register:=cg.GetMMRegister(CurrentAsmData.CurrAsmList, OS_M128);
    CurrentAsmData.CurrAsmList.concat(TAICPU.op_ref_reg(lOp,S_NO,lParaArray[1].Location.Reference,Location.Register));
  end;
