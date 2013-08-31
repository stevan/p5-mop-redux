#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "callchecker0.h"

Perl_check_t old_rv2sv_checker;
SV *twigils_hint_key_sv;
U32 twigils_hint_key_hash;

#define SVt_PADNAME SVt_PVMG

#ifndef COP_SEQ_RANGE_LOW_set
# define COP_SEQ_RANGE_LOW_set(sv,val) \
  do { ((XPVNV*)SvANY(sv))->xnv_u.xpad_cop_seq.xlow = val; } while (0)
# define COP_SEQ_RANGE_HIGH_set(sv,val) \
  do { ((XPVNV*)SvANY(sv))->xnv_u.xpad_cop_seq.xhigh = val; } while (0)
#endif /* !COP_SEQ_RANGE_LOW_set */

#ifndef pad_findmy_sv
#  define pad_findmy_sv(sv, flags) pad_findmy(SvPVX(sv), SvCUR(sv), flags)
#endif /* !pad_findmy_sv */

#ifndef PERL_PADSEQ_INTRO
#  define PERL_PADSEQ_INTRO I32_MAX
#endif /* !PERL_PADSEQ_INTRO */

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
  if (start > SvPVX(PL_parser->linestr) && isSPACE(*(start - 1)))
    return NULL;

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
  HE *he;
  PADOFFSET offset;

  if (!(o->op_flags & OPf_KIDS))
    return old_rv2sv_checker(aTHX_ o);

  kid = cUNOPo->op_first;
  if (kid->op_type != OP_CONST)
    return old_rv2sv_checker(aTHX_ o);

  sv = cSVOPx_sv(kid);
  if (!SvPOK(sv))
    return old_rv2sv_checker(aTHX_ o);

  he = hv_fetch_ent(GvHV(PL_hintgv), twigils_hint_key_sv, 0, twigils_hint_key_hash);
  if (!he || memchr(SvPVX(HeVAL(he)), *SvPVX(sv), SvLEN(HeVAL(he))) == NULL)
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
  dSP;
  SV *namesv;
  OP *pushop, *sigop, *padsv;

  PERL_UNUSED_ARG(namegv);

  pushop = cUNOPo->op_first;
  if (!pushop->op_sibling)
    pushop = cUNOPx(pushop)->op_first;

  if (!(sigop = pushop->op_sibling) || sigop->op_type != OP_CONST)
    croak("Unable to extract compile time constant twigil variable name");

  namesv = cSVOPx_sv(sigop);

  ENTER;
  SAVETMPS;
  PUSHMARK(SP);
  XPUSHs(sv_2mortal(newSVpv(SvPVX(namesv) + 1, 1)));
  PUTBACK;
  call_pv("twigils::_add_allowed_twigil", 0);
  FREETMPS;
  LEAVE;

  padsv = newOP(OP_PADSV, (OPpLVAL_INTRO << 8) | SvIV(ckobj));
  padsv->op_targ = pad_add_my_scalar_sv(aTHX_ namesv);
  op_free(o);
  return padsv;
}

MODULE = twigils  PACKAGE = twigils

PROTOTYPES: DISABLE

BOOT:
  twigils_hint_key_sv = newSVpvs_share("twigils/twigils");
  twigils_hint_key_hash = SvSHARED_HASH(twigils_hint_key_sv);
  old_rv2sv_checker = PL_check[OP_RV2SV];
  PL_check[OP_RV2SV] = myck_rv2sv;
  cv_set_call_checker(get_cv("twigils::intro_twigil_my_var", 0),
                      myck_entersub_intro_twigil_var,
                      sv_2mortal(newSViv(OPf_MOD)));
  cv_set_call_checker(get_cv("twigils::intro_twigil_state_var", 0),
                      myck_entersub_intro_twigil_var,
                      sv_2mortal(newSViv(OPf_MOD | (OPpPAD_STATE << 8))));
