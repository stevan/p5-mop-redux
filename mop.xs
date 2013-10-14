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
parse_name (pTHX_ const char *what, U32 flags)
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
        croak("%"SVf" is not a valid %s name", SVfARG(read_tokenish(aTHX)), what);
    sv = sv_2mortal(newSV(len));
    Copy(start, SvPVX(sv), len, char);
    SvPVX(sv)[len] = '\0';
    SvCUR_set(sv, len);
    SvPOK_on(sv);

    return sv;
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
    aTHX_ what, flags
  POSTCALL:
    SvREFCNT_inc(RETVAL); /* parse_name mortalises, which is what we want when
                             we start using it from C code */

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
