#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "callchecker0.h"
#include "callparser.h"

Perl_check_t old_rv2sv_checker, old_rv2av_checker, old_rv2hv_checker;
SV *twigils_hint_key_sv, *not_in_pad_fatal_hint_key_sv,
   *no_autovivification_hint_key_sv;
U32 twigils_hint_key_hash, not_in_pad_fatal_hint_key_hash,
    no_autovivification_hint_key_hash;

enum twigil_var_type {
  TWIGIL_VAR_MY,
  TWIGIL_VAR_STATE,
  TWIGIL_VAR_OUR
};

enum subscript_type {
  SUBSCRIPT_ARRAY,
  SUBSCRIPT_HASH,
  SUBSCRIPT_ARRAY_SLICE,
  SUBSCRIPT_HASH_SLICE
};

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

#ifndef pad_add_name_pvn
#  define pad_add_name_pvn(name,namelen,flags,typestash,ourstash) \
          Perl_pad_add_name(aTHX_ name, namelen, flags, typestash, ourstash)
#endif

#ifndef padadd_OUR
#  define padadd_OUR 1
#endif

#ifndef ref
extern OP *Perl_ref(pTHX_ OP *, I32);
#  define ref(o,type) Perl_ref(aTHX_ o, type)
#endif

#ifndef LEX_INTERPEND
#  define LEX_INTERPEND 5
#endif

static PADOFFSET
pad_add_my_pvn(pTHX_ char const *namepv, STRLEN namelen)
{
  PADOFFSET offset;
  SV *namesv, *myvar;
  myvar = *av_fetch(PL_comppad, AvFILLp(PL_comppad) + 1, 1);
  switch (*namepv) {
  case '$':
    break;
  case '@':
    sv_upgrade(myvar, SVt_PVAV);
    break;
  case '%':
    sv_upgrade(myvar, SVt_PVHV);
    break;
  }
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
pad_add_my_sv(pTHX_ SV *namesv)
{
  char const *pv;
  STRLEN len;
  pv = SvPV(namesv, len);
  return pad_add_my_pvn(aTHX_ pv, len);
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
  sv = sv_2mortal(newSV(prefixlen + idlen));
  Copy(prefix, SvPVX(sv), prefixlen, char);
  Copy(start, SvPVX(sv) + prefixlen, idlen, char);
  SvPVX(sv)[prefixlen + idlen] = 0;
  SvCUR_set(sv, prefixlen + idlen);
  SvPOK_on(sv);

  return sv;
}

static SV *
parse_ident_maybe_subscripted (pTHX_ const char *prefix, STRLEN prefixlen, enum subscript_type *subscrtp, OP **subscrp)
{
  OP *expr;
  char subscript;
  SV *sv = parse_ident(aTHX_ prefix, prefixlen);

  if (PL_parser->lex_state == LEX_INTERPEND)
    return sv;

  lex_read_space(0);
  if (lex_peek_unichar(0) != '[' && lex_peek_unichar(0) != '{')
    return sv;
  subscript = lex_read_unichar(0);

  expr = parse_fullexpr(0);

  lex_read_space(0);
  if (lex_peek_unichar(0) != (subscript == '[' ? ']' : '}'))
    croak("syntax error");
  lex_read_unichar(0);

  if (*SvPVX(sv) == '$' && subscript == '[') {
    *SvPVX(sv) = '@';
    *subscrtp = SUBSCRIPT_ARRAY;
  }
  else if (*SvPVX(sv) == '$' && subscript == '{') {
    *SvPVX(sv) = '%';
    *subscrtp = SUBSCRIPT_HASH;
  }
  else if (*SvPVX(sv) == '@' && subscript == '[') {
    *subscrtp = SUBSCRIPT_ARRAY_SLICE;
  }
  else if (*SvPVX(sv) == '@' && subscript == '{') {
    *SvPVX(sv) = '%';
    *subscrtp = SUBSCRIPT_HASH_SLICE;
  }

  *subscrp = expr;
  return sv;
}

static bool
twigil_allowed (pTHX_ char twigil)
{
  HE *he = hv_fetch_ent(GvHV(PL_hintgv), twigils_hint_key_sv, 0, twigils_hint_key_hash);
  return he && memchr(SvPVX(HeVAL(he)), twigil, SvCUR(HeVAL(he))) != NULL;
}

static bool
not_in_pad_is_fatal (pTHX)
{
  HE *he = hv_fetch_ent(GvHV(PL_hintgv), not_in_pad_fatal_hint_key_sv, 0,
                        not_in_pad_fatal_hint_key_hash);
  return he && SvTRUE(HeVAL(he));
}

static OP *
myck_rv2any (pTHX_ OP *o, char sigil, Perl_check_t old_checker)
{
  OP *kid, *ret, *subscript = NULL;
  SV *sv, *name;
  PADOFFSET offset;
  char *parse_start, prefix[2];
  enum subscript_type subscript_type;

  if (!(o->op_flags & OPf_KIDS))
    return old_checker(aTHX_ o);

  kid = cUNOPo->op_first;
  if (kid->op_type != OP_CONST)
    return old_checker(aTHX_ o);

  sv = cSVOPx_sv(kid);
  if (!SvPOK(sv))
    return old_checker(aTHX_ o);

  if (!twigil_allowed(aTHX_ *SvPVX(sv)))
    return old_checker(aTHX_ o);

  parse_start = PL_parser->bufptr;
  prefix[0] = sigil;
  prefix[1] = *SvPVX(sv);
  name = parse_ident_maybe_subscripted(aTHX_ prefix, 2, &subscript_type, &subscript);
  if (!name)
    return old_checker(aTHX_ o);

  offset = pad_findmy_sv(name, 0);
  if (offset == NOT_IN_PAD) {
    if (not_in_pad_is_fatal(aTHX))
      croak("No such twigil variable %"SVf, SVfARG(name));
    PL_parser->bufptr = parse_start;
    return old_checker(aTHX_ o);
  }

  if (PAD_COMPNAME_FLAGS_isOUR(offset)) {
    HV *stash = PAD_COMPNAME_OURSTASH(offset);
    HEK *stashname = HvNAME_HEK(stash);
    SV *sym = newSVhek(stashname);
    sv_catpvs(sym, "::");
    sv_catsv(sym, name);
    ret = newUNOP(o->op_type, 0, newSVOP(OP_CONST, 0, sym));
  }
  else {
    ret = newOP(sigil == '$' ? OP_PADSV : sigil == '@' ? OP_PADAV : OP_PADHV, 0);
    ret->op_targ = offset;
  }

  if (subscript) {
    switch (subscript_type) {
    case SUBSCRIPT_ARRAY:
      ret = newBINOP(OP_AELEM, 0, Perl_oopsAV(aTHX_ ret), Perl_scalar(aTHX_ subscript));
      break;
    case SUBSCRIPT_HASH:
      ret = newBINOP(OP_HELEM, 0, Perl_oopsHV(aTHX_ ret), Perl_jmaybe(aTHX_ subscript));
      break;
    case SUBSCRIPT_ARRAY_SLICE:
      ret = op_prepend_elem(OP_ASLICE, newOP(OP_PUSHMARK, 0),
                            newLISTOP(OP_ASLICE, 0, Perl_list(aTHX_ subscript),
                                      ref(ret, OP_ASLICE)));
      break;
    case SUBSCRIPT_HASH_SLICE:
      ret = op_prepend_elem(OP_HSLICE, newOP(OP_PUSHMARK, 0),
                            newLISTOP(OP_HSLICE, 0, Perl_list(aTHX_ subscript),
                                      ref(Perl_oopsHV(aTHX_ ret), OP_HSLICE)));
      break;
    }
  }

  op_free(o);
  return ret;
}

static OP *
myck_rv2sv (pTHX_ OP *o)
{
  return myck_rv2any(aTHX_ o, '$', old_rv2sv_checker);
}

static OP *
myck_rv2av (pTHX_ OP *o)
{
  return myck_rv2any(aTHX_ o, '@', old_rv2av_checker);
}

static OP *
myck_rv2hv (pTHX_ OP *o)
{
  return myck_rv2any(aTHX_ o, '%', old_rv2hv_checker);
}

static void
add_allowed_twigil (pTHX_ char twigil)
{
  dSP;
  ENTER;
  SAVETMPS;
  PUSHMARK(SP);
  XPUSHs(sv_2mortal(newSVpv(&twigil, 1)));
  PUTBACK;
  call_pv("twigils::_add_allowed_twigil", 0);
  FREETMPS;
  LEAVE;
}

static bool
twigils_should_autovivify (pTHX)
{
  HE *he = hv_fetch_ent(GvHV(PL_hintgv), no_autovivification_hint_key_sv, 0,
                        no_autovivification_hint_key_hash);
  return !he || !SvTRUE(HeVAL(he));
}

static OP *
myck_entersub_intro_twigil_var (pTHX_ OP *o, GV *namegv, SV *ckobj) {
  SV *namesv;
  OP *pushop, *sigop, *ret;
  char sigil, twigil;
  int flags = 0;

  PERL_UNUSED_ARG(namegv);

  pushop = cUNOPo->op_first;
  if (!pushop->op_sibling)
    pushop = cUNOPx(pushop)->op_first;

  if (!(sigop = pushop->op_sibling) || sigop->op_type != OP_CONST)
    croak("Unable to extract compile time constant twigil variable name");

  namesv = cSVOPx_sv(sigop);
  sigil = *SvPVX(namesv);
  twigil = *(SvPVX(namesv) + 1);

  if (twigils_should_autovivify(aTHX))
    add_allowed_twigil(aTHX_ twigil);
  else if (!twigil_allowed(aTHX_ twigil))
    croak("Unregistered sigil character %c", twigil);

  switch ((enum twigil_var_type)SvIV(ckobj)) {
  case TWIGIL_VAR_STATE:
    flags = (OPpPAD_STATE << 8);
    /* fall through */
  case TWIGIL_VAR_MY:
    ret = newOP(sigil == '$' ? OP_PADSV : sigil == '@' ? OP_PADAV : OP_PADHV,
                (OPpLVAL_INTRO << 8) | OPf_MOD | flags);
    ret->op_targ = pad_add_my_sv(aTHX_ namesv);
    break;
  case TWIGIL_VAR_OUR:
    pad_add_name_pvn(SvPVX(namesv), SvCUR(namesv), padadd_OUR, NULL, PL_curstash);
    ret = newUNOP(sigil == '$' ? OP_RV2SV : sigil == '@' ? OP_RV2AV : OP_RV2HV,
                  (OPpOUR_INTRO << 8), newSVOP(OP_CONST, 0, SvREFCNT_inc(namesv)));
    break;
  }

  op_free(o);
  return ret;
}

static OP *
myparse_args_intro_twigil_var (pTHX_ GV *namegv, SV *psobj, U32 *flagsp)
{
  char twigil[2];
  SV *ident;

  PERL_UNUSED_ARG(namegv);
  PERL_UNUSED_ARG(psobj);
  PERL_UNUSED_ARG(flagsp);

  lex_read_space(0);
  twigil[0] = lex_peek_unichar(0);
  if (twigil[0] != '$' && twigil[0] != '@' && twigil[0] != '%')
    croak("syntax error");
  lex_read_unichar(0);

  if (isSPACE(lex_peek_unichar(0)))
    croak("syntax error");

  twigil[1] = lex_read_unichar(0);

  ident = parse_ident(aTHX_ twigil, 2);
  if (!ident)
    croak("syntax error");

  return newSVOP(OP_CONST, 0, SvREFCNT_inc(ident));
}

MODULE = twigils  PACKAGE = twigils

PROTOTYPES: DISABLE

BOOT:
{
  CV *intro_twigil_my_var_cv = get_cv("twigils::intro_twigil_my_var", 0);
  CV *intro_twigil_state_var_cv = get_cv("twigils::intro_twigil_state_var", 0);
  CV *intro_twigil_our_var_cv = get_cv("twigils::intro_twigil_our_var", 0);

  twigils_hint_key_sv = newSVpvs_share("twigils/twigils");
  twigils_hint_key_hash = SvSHARED_HASH(twigils_hint_key_sv);
  not_in_pad_fatal_hint_key_sv = newSVpvs_share("twigils/not_in_pad_fatal");
  not_in_pad_fatal_hint_key_hash = SvSHARED_HASH(not_in_pad_fatal_hint_key_sv);
  no_autovivification_hint_key_sv = newSVpvs_share("twigils/no_autovivification");
  no_autovivification_hint_key_hash = SvSHARED_HASH(no_autovivification_hint_key_sv);

  old_rv2sv_checker = PL_check[OP_RV2SV];
  old_rv2av_checker = PL_check[OP_RV2AV];
  old_rv2hv_checker = PL_check[OP_RV2HV];
  PL_check[OP_RV2SV] = myck_rv2sv;
  PL_check[OP_RV2AV] = myck_rv2av;
  PL_check[OP_RV2HV] = myck_rv2hv;

  cv_set_call_parser(intro_twigil_my_var_cv,
                     myparse_args_intro_twigil_var, &PL_sv_undef);
  cv_set_call_parser(intro_twigil_state_var_cv,
                     myparse_args_intro_twigil_var, &PL_sv_undef);
  cv_set_call_parser(intro_twigil_our_var_cv,
                     myparse_args_intro_twigil_var, &PL_sv_undef);

  cv_set_call_checker(intro_twigil_my_var_cv,
                      myck_entersub_intro_twigil_var,
                      sv_2mortal(newSViv(TWIGIL_VAR_MY)));
  cv_set_call_checker(intro_twigil_state_var_cv,
                      myck_entersub_intro_twigil_var,
                      sv_2mortal(newSViv(TWIGIL_VAR_STATE)));
  cv_set_call_checker(intro_twigil_our_var_cv,
                      myck_entersub_intro_twigil_var,
                      sv_2mortal(newSViv(TWIGIL_VAR_OUR)));
}
