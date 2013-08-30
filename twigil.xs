#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "callchecker0.h"

Perl_check_t old_rv2sv_checker;

#define SVt_PADNAME SVt_PVMG

#ifndef COP_SEQ_RANGE_LOW_set
# define COP_SEQ_RANGE_LOW_set(sv,val) \
  do { ((XPVNV*)SvANY(sv))->xnv_u.xpad_cop_seq.xlow = val; } while (0)
# define COP_SEQ_RANGE_HIGH_set(sv,val) \
  do { ((XPVNV*)SvANY(sv))->xnv_u.xpad_cop_seq.xhigh = val; } while (0)
#endif /* !COP_SEQ_RANGE_LOW_set */

static PADOFFSET
pad_add_my_scalar_pvn(pTHX_ char const *namepv, STRLEN namelen)
{
  PADOFFSET offset;
  SV *namesv, *myvar;
  myvar = *av_fetch(PL_comppad, AvFILLp(PL_comppad) + 1, 1);
  offset = AvFILLp(PL_comppad);
  SvPADMY_on(myvar);
  PL_curpad = AvARRAY(PL_comppad);
  namesv = newSV_type(SVt_PADNAME);
  sv_setpvn(namesv, namepv, namelen);
  COP_SEQ_RANGE_LOW_set(namesv, PL_cop_seqmax);
  COP_SEQ_RANGE_HIGH_set(namesv, PERL_PADSEQ_INTRO);
  PL_cop_seqmax++;
  av_store(PL_comppad_name, offset, namesv);
  return offset;
}

static PADOFFSET
pad_add_my_scalar_sv(pTHX_ SV *namesv)
{
  char const *pv;
  STRLEN len;
  pv = SvPV(namesv, len);
  return pad_add_my_scalar_pvn(aTHX_ pv, len);
}

static SV *
parse_ident (pTHX_ const char *prefix, STRLEN prefixlen)
{
  STRLEN idlen;
  char *start, *s;
  char c;
  SV *sv;

  start = s = PL_parser->bufptr;
  c = *s;

  if (!isIDFIRST(c))
    return NULL;

  do {
    c = *++s;
  } while (isALNUM(c));

  lex_read_to(s);

  idlen = s - start;
  sv = newSV(1 + prefixlen + idlen);
  *SvPVX(sv) = '$';
  Copy(prefix, SvPVX(sv) + 1, prefixlen, char);
  Copy(start, SvPVX(sv) + 1 + prefixlen, idlen, char);
  SvPVX(sv)[1 + prefixlen + idlen] = 0;
  SvCUR_set(sv, 1 + prefixlen + idlen);
  SvPOK_on(sv);

  return sv;
}

static OP *
myck_rv2sv (pTHX_ OP *o)
{
  OP *kid;
  SV *sv, *name;
  PADOFFSET offset;

  if (!(o->op_flags & OPf_KIDS))
    return old_rv2sv_checker(aTHX_ o);

  kid = cUNOPo->op_first;
  if (kid->op_type != OP_CONST)
    return old_rv2sv_checker(aTHX_ o);

  sv = cSVOPx(kid)->op_sv;
  if (!SvPOK(sv))
    return old_rv2sv_checker(aTHX_ o);
  if (*SvPVX(sv) != '!' && *SvPVX(sv) != '.')
    return old_rv2sv_checker(aTHX_ o);

  name = parse_ident(aTHX_ SvPVX(sv), 1);
  if (!name)
    return old_rv2sv_checker(aTHX_ o);

  op_free(o);
  offset = pad_findmy_sv(name, 0);
  if (offset == NOT_IN_PAD)
    croak("twigil variable %"SVf" not found", SVfARG(name));
  o = newOP(OP_PADSV, 0);
  o->op_targ = offset;

  return o;
}

static OP *
myck_entersub_intro_twigil_var (pTHX_ OP *o, GV *namegv, SV *ckobj) {
  OP *pushop, *sigop;

  PERL_UNUSED_ARG(namegv);
  PERL_UNUSED_ARG(ckobj);

  pushop = cUNOPo->op_first;
  if(!pushop->op_sibling)
    pushop = cUNOPx(pushop)->op_first;

  if ((sigop = pushop->op_sibling) && sigop->op_type == OP_CONST) {
    OP *padsv = newOP(OP_PADSV, (OPpLVAL_INTRO << 8));
    padsv->op_targ = pad_add_my_scalar_sv(aTHX_ cSVOPx_sv(sigop));
    op_free(o);
    return padsv;
  }

  return o;
}

MODULE = twigil  PACKAGE = twigil

PROTOTYPES: DISABLE

BOOT:
  old_rv2sv_checker = PL_check[OP_RV2SV];
  PL_check[OP_RV2SV] = myck_rv2sv;
  cv_set_call_checker(get_cv("twigil::intro_twigil_var", 0),
                      myck_entersub_intro_twigil_var, &PL_sv_undef);
