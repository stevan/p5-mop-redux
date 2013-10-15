#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "callparser1.h"

static MGVTBL subname_vtbl;

static OP *ck_mop_keyword(pTHX_ OP *entersubop, GV *namegv, SV *ckobj)
{
    PERL_UNUSED_ARG(namegv);
    op_free(entersubop);
    return SvTRUE(ckobj)
        ? newSVOP(OP_CONST, 0, &PL_sv_yes)
        : newOP(OP_NULL, 0);
}

static SV *
read_tokenish (pTHX)
{
    char c;
    SV *ret = sv_2mortal(newSV(1));
    SvCUR_set(ret, 0);
    SvPOK_on(ret);

    if (strchr("$@%!:", lex_peek_unichar(0)) != NULL)
        sv_catpvf(ret, "%c", lex_read_unichar(0));

    c = lex_peek_unichar(0);
    while (c != -1 && !isSPACE(c)) {
        sv_catpvf(ret, "%c", lex_read_unichar(0));
        c = lex_peek_unichar(0);
    }

    return ret;
}

#define PARSE_NAME_ALLOW_PACKAGE 1
static SV *
parse_name (pTHX_ const char *what, STRLEN whatlen, U32 flags)
{
    char *start, *s;
    STRLEN len;
    bool saw_idfirst = FALSE;
    SV *sv;

    if (flags & ~PARSE_NAME_ALLOW_PACKAGE)
        croak("unknown flags");

    start = s = PL_parser->bufptr;

    while (1) {
        char c = lex_peek_unichar(LEX_KEEP_PREVIOUS);

        if (saw_idfirst ? isALNUM(c) : (saw_idfirst = TRUE, isIDFIRST(c))) {
            lex_read_unichar(LEX_KEEP_PREVIOUS); ++s;
        }
        else if (flags & PARSE_NAME_ALLOW_PACKAGE && c == ':') {
            lex_read_unichar(0); ++s;
            if (lex_peek_unichar(0) == ':') { /* TODO: check next != ':' */
                lex_read_unichar(0); ++s;
            }
            else {
                croak("Invalid identifier: %.*s%"SVf,
                      s - start, start,
                      SVfARG(read_tokenish(aTHX)));
            }
        }
        else break;
    }

    len = s - start;
    if (!len)
        croak("%"SVf" is not a valid %.*s name",
              SVfARG(read_tokenish(aTHX)), whatlen, what);
    sv = sv_2mortal(newSV(len));
    Copy(start, SvPVX(sv), len, char);
    SvPVX(sv)[len] = '\0';
    SvCUR_set(sv, len);
    SvPOK_on(sv);

    return sv;
}

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
#    define pad_findmy_sv(sv, flags) pad_findmy(SvPVX(sv), SvCUR(sv), flags)
#endif /* !pad_findmy_sv */

#ifndef PERL_PADSEQ_INTRO
#    define PERL_PADSEQ_INTRO I32_MAX
#endif /* !PERL_PADSEQ_INTRO */

#ifndef pad_add_name_pvn
#    define pad_add_name_pvn(name,namelen,flags,typestash,ourstash) \
            Perl_pad_add_name(aTHX_ name, namelen, flags, typestash, ourstash)
#endif

static PADOFFSET
pad_add_my_pvn(pTHX_ char const *namepv, STRLEN namelen)
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

static bool
twigil_enabled (pTHX)
{
    HE *he = hv_fetch_ent(GvHV(PL_hintgv), twigils_hint_key_sv, 0, twigils_hint_key_hash);
    return he && SvTRUE(HeVAL(he));
}

static OP *
myck_rv2sv (pTHX_ OP *o)
{
    OP *kid, *ret;
    SV *sv, *name;
    PADOFFSET offset;
    char prefix[2];

    if (!(o->op_flags & OPf_KIDS))
        return old_rv2sv_checker(aTHX_ o);

    kid = cUNOPo->op_first;
    if (kid->op_type != OP_CONST)
        return old_rv2sv_checker(aTHX_ o);

    sv = cSVOPx_sv(kid);
    if (!SvPOK(sv))
        return old_rv2sv_checker(aTHX_ o);

    if (!twigil_enabled(aTHX))
        return old_rv2sv_checker(aTHX_ o);

    if (*SvPVX(sv) != '!')
        return old_rv2sv_checker(aTHX_ o);

    prefix[0] = '$';
    prefix[1] = *SvPVX(sv);
    name = parse_ident(aTHX_ prefix, 2);
    if (!name)
        return old_rv2sv_checker(aTHX_ o);

    offset = pad_findmy_sv(name, 0);
    if (offset == NOT_IN_PAD)
        croak("No such twigil variable %"SVf, SVfARG(name));

    ret = newOP(OP_PADSV, 0);
    ret->op_targ = offset;

    op_free(o);
    return ret;
}

static OP *
myck_entersub_intro_twigil_var (pTHX_ OP *o, GV *namegv, SV *ckobj)
{
    SV *namesv;
    OP *pushop, *sigop, *ret;
    char twigil;

    PERL_UNUSED_ARG(namegv);
    PERL_UNUSED_ARG(ckobj);

    pushop = cUNOPo->op_first;
    if (!pushop->op_sibling)
        pushop = cUNOPx(pushop)->op_first;

    if (!(sigop = pushop->op_sibling) || sigop->op_type != OP_CONST)
        croak("Unable to extract compile time constant twigil variable name");

    namesv = cSVOPx_sv(sigop);
    twigil = *(SvPVX(namesv) + 1);

    if (twigil != '!')
        croak("Unregistered sigil character %c", twigil);

    ret = newOP(OP_PADSV, (OPpLVAL_INTRO << 8) | OPf_MOD);
    ret->op_targ = pad_add_my_sv(aTHX_ namesv);

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

MODULE = mop  PACKAGE = mop::internals::util

PROTOTYPES: DISABLE

# copied directly from Sub::Name, to decrease deps
void
subname(name, sub)
    char *name
    SV *sub
  PREINIT:
    CV *cv = NULL;
    GV *gv;
    HV *stash = CopSTASH(PL_curcop);
    char *s, *end = NULL, saved;
    MAGIC *mg;
  PPCODE:
    if (!SvROK(sub) && SvGMAGICAL(sub))
        mg_get(sub);
    if (SvROK(sub))
        cv = (CV *) SvRV(sub);
    else if (SvTYPE(sub) == SVt_PVGV)
        cv = GvCVu(sub);
    else if (!SvOK(sub))
        croak(PL_no_usym, "a subroutine");
    else if (PL_op->op_private & HINT_STRICT_REFS)
        croak("Can't use string (\"%.32s\") as %s ref while \"strict refs\" in use",
              SvPV_nolen(sub), "a subroutine");
    else if ((gv = gv_fetchpv(SvPV_nolen(sub), FALSE, SVt_PVCV)))
        cv = GvCVu(gv);
    if (!cv)
        croak("Undefined subroutine %s", SvPV_nolen(sub));
    if (SvTYPE(cv) != SVt_PVCV && SvTYPE(cv) != SVt_PVFM)
        croak("Not a subroutine reference");
    for (s = name; *s++; ) {
        if (*s == ':' && s[-1] == ':')
            end = ++s;
        else if (*s && s[-1] == '\'')
            end = s;
    }
    s--;
    if (end) {
        saved = *end;
        *end = 0;
        stash = GvHV(gv_fetchpv(name, TRUE, SVt_PVHV));
        *end = saved;
        name = end;
    }
    gv = (GV *) newSV(0);
    gv_init(gv, stash, name, s - name, TRUE);

    mg = SvMAGIC(cv);
    while (mg && mg->mg_virtual != &subname_vtbl)
        mg = mg->mg_moremagic;
    if (!mg) {
        Newz(702, mg, 1, MAGIC);
        mg->mg_moremagic = SvMAGIC(cv);
        mg->mg_type = PERL_MAGIC_ext;
        mg->mg_virtual = &subname_vtbl;
        SvMAGIC_set(cv, mg);
    }
    if (mg->mg_flags & MGf_REFCOUNTED)
        SvREFCNT_dec(mg->mg_obj);
    mg->mg_flags |= MGf_REFCOUNTED;
    mg->mg_obj = (SV *) gv;
    SvRMAGICAL_on(cv);
    CvANON_off(cv);
    CvGV_set(cv, gv);
    PUSHs(sub);

MODULE = mop  PACKAGE = mop::internals::syntax

PROTOTYPES: DISABLE

SV *
parse_name (what, flags=0)
    const char *what
    U32 flags
  C_ARGS:
    aTHX_ what, SvCUR(ST(0)), flags
  POSTCALL:
    SvREFCNT_inc(RETVAL); /* parse_name mortalises, which is what we want when
                             we start using it from C code */

SV *
read_tokenish ()
  C_ARGS:
    aTHX
  POSTCALL:
    SvREFCNT_inc(RETVAL); /* As above. */

BOOT:
{
    CV *class, *role, *has, *method;

    class  = get_cv("mop::internals::syntax::class",  0);
    role   = get_cv("mop::internals::syntax::role",   0);
    has    = get_cv("mop::internals::syntax::has",    0);
    method = get_cv("mop::internals::syntax::method", 0);

    cv_set_call_checker(class,  ck_mop_keyword, &PL_sv_yes);
    cv_set_call_checker(role,   ck_mop_keyword, &PL_sv_yes);
    cv_set_call_checker(has,    ck_mop_keyword, &PL_sv_undef);
    cv_set_call_checker(method, ck_mop_keyword, &PL_sv_undef);
}

MODULE = mop  PACKAGE = mop::internals::twigils

PROTOTYPES: DISABLE

BOOT:
{
    CV *intro_twigil_my_var_cv = get_cv("mop::internals::twigils::intro_twigil_my_var", 0);

    twigils_hint_key_sv = newSVpvs_share("mop::internals::twigils/twigils");
    twigils_hint_key_hash = SvSHARED_HASH(twigils_hint_key_sv);

    old_rv2sv_checker = PL_check[OP_RV2SV];
    PL_check[OP_RV2SV] = myck_rv2sv;

    cv_set_call_parser(intro_twigil_my_var_cv,
                       myparse_args_intro_twigil_var, &PL_sv_undef);

    cv_set_call_checker(intro_twigil_my_var_cv,
                        myck_entersub_intro_twigil_var,
                        &PL_sv_undef);
}
