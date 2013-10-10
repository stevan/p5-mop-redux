#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

static OP *ck_mop_keyword(pTHX_ OP *entersubop, GV *namegv, SV *ckobj)
{
    op_free(entersubop);
    return SvTRUE(ckobj)
        ? newSVOP(OP_CONST, 0, &PL_sv_yes)
        : newOP(OP_NULL, 0);
}

MODULE = mop  PACKAGE = mop

PROTOTYPES: DISABLE

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
