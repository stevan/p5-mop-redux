#include "EXTERN.h"
#include "perl.h"
#define NO_XSLOCKS
#include "XSUB.h"

#include "callparser1.h"

static int mg_attr_get(pTHX_ SV *sv, MAGIC *mg);
static int mg_attr_set(pTHX_ SV *sv, MAGIC *mg);
static int mg_err_get(pTHX_ SV *sv, MAGIC *mg);
static int mg_err_set(pTHX_ SV *sv, MAGIC *mg);

static MGVTBL subname_vtbl;
static MGVTBL attr_vtbl = {
    mg_attr_get,                /* get */
    mg_attr_set,                /* set */
    0,                          /* len */
    0,                          /* clear */
    0,                          /* free */
    0,                          /* copy */
    0,                          /* dup */
    0,                          /* local */
};
static MGVTBL err_vtbl = {
    mg_err_get,                 /* get */
    mg_err_set,                 /* set */
    0,                          /* len */
    0,                          /* clear */
    0,                          /* free */
    0,                          /* copy */
    0,                          /* dup */
    0,                          /* local */
};

static int
mg_attr_get(pTHX_ SV *sv, MAGIC *mg)
{
    SV *name, *meta, *self, *attr, *val;

    name = *av_fetch((AV *)mg->mg_obj, 0, 0);
    meta = *av_fetch((AV *)mg->mg_obj, 1, 0);
    self = *av_fetch((AV *)mg->mg_obj, 2, 0);

    ENTER;
    {
        dSP;

        PUSHMARK(SP);
        XPUSHs(meta);
        XPUSHs(name);
        PUTBACK;

        call_method("get_attribute", G_SCALAR);

        SPAGAIN;
        attr = POPs;
        PUTBACK;
    }

    {
        dSP;

        PUSHMARK(SP);
        XPUSHs(attr);
        XPUSHs(self);
        PUTBACK;

        call_method("fetch_data_in_slot_for", G_SCALAR);

        SPAGAIN;
        val = POPs;
        PUTBACK;
    }
    LEAVE;

    sv_setsv(sv, val);

    return 0;
}

static int
mg_attr_set(pTHX_ SV *sv, MAGIC *mg)
{
    SV *name, *meta, *self, *attr;

    name = *av_fetch((AV *)mg->mg_obj, 0, 0);
    meta = *av_fetch((AV *)mg->mg_obj, 1, 0);
    self = *av_fetch((AV *)mg->mg_obj, 2, 0);

    ENTER;
    {
        dSP;

        PUSHMARK(SP);
        XPUSHs(meta);
        XPUSHs(name);
        PUTBACK;

        call_method("get_attribute", G_SCALAR);

        SPAGAIN;
        attr = POPs;
        PUTBACK;
    }

    {
        dSP;

        PUSHMARK(SP);
        XPUSHs(attr);
        XPUSHs(self);
        XPUSHs(sv);
        PUTBACK;

        call_method("store_data_in_slot_for", G_VOID);
    }
    LEAVE;

    return 0;
}

static int
mg_err_get(pTHX_ SV *sv, MAGIC *mg)
{
    PERL_UNUSED_ARG(sv);
    croak("Cannot access the attribute:(%"SVf") in a method "
          "without a blessed invocant", SVfARG(mg->mg_obj));
}

static int
mg_err_set(pTHX_ SV *sv, MAGIC *mg)
{
    PERL_UNUSED_ARG(sv);
    croak("Cannot assign to the attribute:(%"SVf") in a method "
          "without a blessed invocant", SVfARG(mg->mg_obj));
}

static OP *
ck_mop_keyword(pTHX_ OP *entersubop, GV *namegv, SV *ckobj)
{
    PERL_UNUSED_ARG(namegv);
    op_free(entersubop);
    return SvTRUE(ckobj)
        ? newSVOP(OP_CONST, 0, &PL_sv_yes)
        : newOP(OP_NULL, 0);
}

static SV *
read_tokenish(pTHX)
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

static char *
lex_peek_pv(pTHX_ STRLEN len, STRLEN *lenp)
{
    char *bufptr = PL_parser->bufptr;
    char *bufend = PL_parser->bufend;
    STRLEN got;

    /* XXX before 5.19.2, lex_next_chunk when we aren't at the end of a line
     * just breaks things entirely (the parser no longer sees the text that is
     * read in). this is (i think inadvertently) fixed in 5.19.2 (21791330a),
     * but it still screws up the line numbers of everything that follows. so,
     * the workaround is just to not call lex_next_chunk unless we're at the
     * end of a line. this is a bit limiting, but should rarely come up in
     * practice.
    */
    /*
    while (PL_parser->bufend - PL_parser->bufptr < len) {
        if (!lex_next_chunk(0)) {
            break;
        }
    }
    */

    if (bufptr == bufend) {
        lex_next_chunk(0);
        bufend = PL_parser->bufend;
    }

    if (lex_bufutf8())
        croak("Not yet implemented");

    got = bufend - bufptr;
    if (got < len)
        len = got;

    *lenp = len;
    return bufptr;
}

#define PARSE_NAME_ALLOW_PACKAGE 1
static SV *
parse_name_prefix(pTHX_ const char *prefix, STRLEN prefixlen,
                  const char *what, STRLEN whatlen, U32 flags)
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
    sv = sv_2mortal(newSV(prefixlen + len));
    Copy(prefix, SvPVX(sv), prefixlen, char);
    Copy(start, SvPVX(sv) + prefixlen, len, char);
    SvPVX(sv)[prefixlen + len] = '\0';
    SvCUR_set(sv, prefixlen + len);
    SvPOK_on(sv);

    return sv;
}

static SV *
parse_name(pTHX_ const char *what, STRLEN whatlen, U32 flags)
{
    return parse_name_prefix(aTHX_ NULL, 0, what, whatlen, flags);
}

static bool
parse_modifier(pTHX_ const char *modifier, STRLEN len)
{
    STRLEN got;
    char *s = lex_peek_pv(aTHX_ len + 1, &got);

    if (got < len)
        return FALSE;

    if (strnNE(s, modifier, len))
        return FALSE;

    if (got >= len + 1) {
        char last = s[len];
        if (isALNUM(last) || last == '_')
            return FALSE;
    }

    lex_read_to(s + len);
    return TRUE;
}

static SV *
parse_modifier_with_single_value(pTHX_ const char *modifier, STRLEN len)
{
    if (!parse_modifier(aTHX_ modifier, len))
        return NULL;

    lex_read_space(0);

    if (strnEQ(modifier, "extends", len))
        return parse_name(aTHX_ "class", sizeof("class") - 1, PARSE_NAME_ALLOW_PACKAGE);

    return parse_name(aTHX_ modifier, len, PARSE_NAME_ALLOW_PACKAGE);
}

static AV *
parse_modifier_with_multiple_values(pTHX_ const char *modifier, STRLEN len)
{
    AV *ret = (AV *)sv_2mortal((SV *)newAV());

    if (!parse_modifier(aTHX_ modifier, len))
        return ret;

    lex_read_space(0);

    do {
        SV *name = parse_name(aTHX_ "role", sizeof("role"), PARSE_NAME_ALLOW_PACKAGE);
        av_push(ret, SvREFCNT_inc(name));
        lex_read_space(0);
    } while (lex_peek_unichar(0) == ',' && (lex_read_unichar(0), lex_read_space(0), TRUE));

    return ret;
}

struct mop_trait {
    SV *name;
    OP *params;
};

static void
syntax_error(pTHX_ SV *err)
{
    dSP;
    ENTER;
    PUSHMARK(SP);
    XPUSHs(err);
    PUTBACK;
    call_pv("mop::internals::syntax::syntax_error", G_VOID);
    PUTBACK;
    LEAVE;
}

static struct mop_trait **
parse_traits(pTHX_ UV *ntraitsp)
{
    dXCPT;
    U32 ntraits = 0;
    struct mop_trait **ret = NULL;

    if (!parse_modifier(aTHX_ "is", 2)) {
        *ntraitsp = 0;
        return ret;
    }
    lex_read_space(0);

    XCPT_TRY_START {
        do {
            struct mop_trait *trait;
            Renew(ret, ntraits + 1, struct mop_trait *);
            Newx(trait, 1, struct mop_trait);
            ret[ntraits] = trait;
            trait->name = parse_name(aTHX_ "trait", sizeof("trait") - 1,
                                     PARSE_NAME_ALLOW_PACKAGE);

            if (lex_peek_unichar(0) == '(') {
                lex_read_unichar(0);
                trait->params = parse_fullexpr(0);
                if (lex_peek_unichar(0) != ')')
                    syntax_error(aTHX_ sv_2mortal(newSVpvf("Unterminated parameter "
                                                           "list for trait %"SVf,
                                                           SVfARG(trait->name))));
                lex_read_unichar(0);
            }
            else
                trait->params = NULL;

            ntraits++;
        } while (lex_peek_unichar(0) == ',' && (lex_read_unichar(0),
                                                lex_read_space(0), TRUE));
    } XCPT_TRY_END XCPT_CATCH {
        UV i;
        for (i = 0; i < ntraits; i++) {
            /* name is already mortal */
            if (ret[i]->params)
                op_free(ret[i]->params);
            Safefree(ret[i]);
            Safefree(ret);
        }
        XCPT_RETHROW;
    }

    *ntraitsp = ntraits;
    return ret;
}

static OP *
gen_traits_ops(pTHX_ OP *append_to, struct mop_trait **traits, UV ntraits)
{
    UV i;

    for (i = 0; i < ntraits; i++) {
        OP *cvop = newUNOP(OP_REFGEN, 0,
                           newCVREF((OPpENTERSUB_AMPER<<8),
                                    newSVOP(OP_CONST, 0, SvREFCNT_inc(traits[i]->name))));

        append_to = op_append_elem(OP_LIST, append_to, cvop);
        append_to = op_append_elem(OP_LIST, append_to,
                                   traits[i]->params
                                   ? traits[i]->params
                                   : newSVOP(OP_CONST, 0, &PL_sv_undef));

        Safefree(traits[i]);
    }
    Safefree(traits);

    return append_to;
}

static OP *
parse_has(pTHX_ GV *namegv, SV *psobj, U32 *flagsp)
{
    SV *name;
    UV ntraits;
    OP *default_value = NULL, *ret;
    struct mop_trait **traits;

    PERL_UNUSED_ARG(namegv);
    PERL_UNUSED_ARG(psobj);

    lex_read_space(0);

    if (lex_peek_unichar(0) != '$')
        syntax_error(aTHX_ sv_2mortal(newSVpvf("Invalid attribute name %"SVf,
                                               SVfARG(read_tokenish(aTHX)))));
    lex_read_unichar(0);

    if (lex_peek_unichar(0) != '!')
        syntax_error(aTHX_ sv_2mortal(newSVpvf("Invalid attribute name $%"SVf,
                                               SVfARG(read_tokenish(aTHX)))));
    lex_read_unichar(0);

    name = parse_name_prefix(aTHX_ "$!", 2, "attribute", sizeof("attribute") - 1, 0);
    lex_read_space(0);

    traits = parse_traits(aTHX_ &ntraits);
    lex_read_space(0);

    if (lex_peek_unichar(0) == '=') {
        I32 floor;

        lex_read_unichar(0);
        lex_read_space(0);
        floor = start_subparse(0, CVf_ANON);
        default_value = newANONSUB(floor, NULL, parse_fullexpr(0));
        lex_read_space(0);
    }

    if (lex_peek_unichar(0) == ';')
        lex_read_unichar(0);
    else if (lex_peek_unichar(0) != '}')
        syntax_error(aTHX_ sv_2mortal(newSVpvf("Couldn't parse attribute %"SVf,
                                               SVfARG(name))));

    ret = op_append_elem(OP_LIST, newSVOP(OP_CONST, 0, SvREFCNT_inc(name)),
                         default_value ? default_value : newSVOP(OP_CONST, 0, &PL_sv_undef));
    ret = gen_traits_ops(aTHX_ ret, traits, ntraits);

    *flagsp = CALLPARSER_STATEMENT;
    return ret;
}

static AV *
current_attributes(pTHX)
{
    return GvAV(gv_fetchpvs("mop::internals::syntax::CURRENT_ATTRIBUTE_NAMES",
                            GV_ADD, SVt_PVAV));
}

static void
add_attribute(pTHX_ SV *namesv)
{
    AV *attrs = current_attributes(aTHX);
    av_push(attrs, SvREFCNT_inc(namesv));
}

static OP *
check_has(pTHX_ OP *entersubop, GV *namegv, SV *ckobj)
{
    OP *pushop, *nameop;

    PERL_UNUSED_ARG(namegv);
    PERL_UNUSED_ARG(ckobj);

    pushop = cUNOPx(entersubop)->op_first;
    if (!pushop->op_sibling)
        pushop = cUNOPx(pushop)->op_first;

    if ((nameop = pushop->op_sibling) && nameop->op_type == OP_CONST) {
        add_attribute(aTHX_ cSVOPx_sv(nameop));
    }

    return PL_check[entersubop->op_type](aTHX_ entersubop);
}

struct mop_signature_var {
    SV *name;
    OP *default_value;
};

static UV
parse_signature(pTHX_ SV *method_name,
                struct mop_signature_var **invocantp,
                struct mop_signature_var ***varsp)
{
    dXCPT;
    UV numvars = 0;
    struct mop_signature_var **vars = NULL, *invocant = NULL;

    if (lex_peek_unichar(0) == '(') {
        char sigil;
        bool seen_slurpy = FALSE;

        lex_read_unichar(0);
        lex_read_space(0);

        XCPT_TRY_START {
            while ((sigil = lex_peek_unichar(0)) != ')') {
                struct mop_signature_var *var;

                if (sigil != '$' && sigil != '@' && sigil != '%')
                    syntax_error(aTHX_ sv_2mortal(newSVpvf("Invalid sigil: %c", sigil)));
                if (seen_slurpy)
                    syntax_error(aTHX_ sv_2mortal(newSVpvs("Can't declare parameters "
                                                           "after a slurpy parameter")));
                seen_slurpy = sigil == '@' || sigil == '%';
                lex_read_unichar(0);
                lex_read_space(0);

                Newxz(var, 1, struct mop_signature_var);

                var->name = parse_name_prefix(aTHX_ &sigil, 1, "argument",
                                              sizeof("argument") - 1, 0);
                lex_read_space(0);

                if (lex_peek_unichar(0) == '=') {
                    I32 floor;

                    lex_read_unichar(0);
                    lex_read_space(0);
                    floor = start_subparse(0, CVf_ANON);
                    var->default_value = newANONSUB(
                        floor, NULL, parse_arithexpr(0));
                    lex_read_space(0);
                }

                if (lex_peek_unichar(0) == ':') {
                    if (invocant)
                        syntax_error(aTHX_ sv_2mortal(newSVpvs("Cannot specify "
                                                               "multiple invocants")));
                    if (var->default_value)
                        syntax_error(aTHX_ sv_2mortal(newSVpvs("Cannot specify a default "
                                                               "value for the invocant")));
                    invocant = var;
                    lex_read_unichar(0);
                    lex_read_space(0);
                }
                else {
                    Renew(vars, numvars + 1, struct mop_signature_var *);
                    vars[numvars] = var;

                    if (lex_peek_unichar(0) != ')' && lex_peek_unichar(0) != ',')
                        syntax_error(aTHX_ sv_2mortal(newSVpvf("Unterminated prototype for "
                                                           "%"SVf, SVfARG(method_name))));

                    if (lex_peek_unichar(0) == ',') {
                        lex_read_unichar(0);
                        lex_read_space(0);
                    }

                    numvars++;
                }
            }
        } XCPT_TRY_END XCPT_CATCH {
            UV i;

            if (invocant) {
                /* name is already mortal. default_value is never used. */
                Safefree(invocant);
            }

            for (i = 0; i < numvars; i++) {
                /* name is already mortal */
                if (vars[i]->default_value)
                    op_free(vars[i]->default_value);
                Safefree(vars[i]);
                Safefree(vars);
            }
        XCPT_RETHROW;
            XCPT_RETHROW;
        }
        lex_read_unichar(0);
    }

    if (!invocant) {
        Newxz(invocant, 1, struct mop_signature_var);
        invocant->name = sv_2mortal(newSVpvs("$self"));
        /* invocant->default_value = newOP(OP_SHIFT, OPf_WANT_SCALAR | OPf_SPECIAL); */
    }

    *invocantp = invocant;
    *varsp = vars;
    return numvars;
}

static void
add_required_method(pTHX_ SV *method_name)
{
    dSP;

    PERL_UNUSED_ARG(method_name);

    ENTER;
    PUSHMARK(SP);
    XPUSHs(get_sv("mop::internals::syntax::CURRENT_META", 0));
    XPUSHs(method_name);
    PUTBACK;
    call_method("add_required_method", G_VOID);
    PUTBACK;
    LEAVE;
}

static OP *
intro_twigil_var(pTHX_ SV *namesv)
{
    OP *o = newOP(OP_PADSV, (OPpLVAL_INTRO << 8) | OPf_MOD);
    o->op_targ = pad_add_name_sv(namesv, 0, NULL, NULL);
    return o;
}

static void
set_attr_magic(pTHX_ SV *var, SV *name, SV *meta, SV *self)
{
    SV *svs[3];
    AV *data;
    svs[0] = name;
    svs[1] = meta;
    svs[2] = self;
    data = (AV *)sv_2mortal((SV *)av_make(3, svs));
    sv_magicext(var, (SV *)data, PERL_MAGIC_ext, &attr_vtbl, "attr", 0);
}

static void
set_err_magic(pTHX_ SV *var, SV *name)
{
    sv_magicext(var, name, PERL_MAGIC_ext, &err_vtbl, "err", 0);
}

static OP *
pp_init_attr(pTHX)
{
    dSP; dTARGET;
    AV *args = (AV *)SvRV(POPs);
    SV *attr_name = *av_fetch(args, 0, 0);
    SV *meta_class = *av_fetch(args, 1, 0);
    SV *invocant = *av_fetch(args, 2, 0);
    if (sv_isobject(invocant))
        set_attr_magic(aTHX_ TARG, attr_name, meta_class, invocant);
    else
        set_err_magic(aTHX_ TARG, attr_name);
    return PL_op->op_next;
}

static OP *
parse_method(pTHX_ GV *namegv, SV *psobj, U32 *flagsp)
{
    SV *name;
    AV *attrs;
    UV numvars, numtraits, i;
    IV j;
    int blk_floor;
    struct mop_signature_var **vars;
    struct mop_signature_var *invocant;
    struct mop_trait **traits;
    OP *body, *unpackargsop = NULL, *attrintroop = NULL, *attrinitop = NULL;

    PERL_UNUSED_ARG(namegv);
    PERL_UNUSED_ARG(psobj);

    *flagsp = CALLPARSER_STATEMENT;

    lex_read_space(0);
    name = parse_name(aTHX_ "method", sizeof("method") - 1, 0);
    lex_read_space(0);

    numvars = parse_signature(aTHX_ name, &invocant, &vars);
    lex_read_space(0);

    traits = parse_traits(aTHX_ &numtraits);
    lex_read_space(0);

    switch (lex_peek_unichar(0)) {
    case ';':
        lex_read_unichar(0);
        /* fall through */
    case '}':
        add_required_method(aTHX_ name);
        return newOP(OP_NULL, 0);
        break;
    }

    if (lex_peek_unichar(0) != '{')
        syntax_error(aTHX_ sv_2mortal(newSVpvs("Non-required methods require a body")));

    blk_floor = start_subparse(0, CVf_ANON);

    unpackargsop = newOP(OP_PADSV, (OPpLVAL_INTRO << 8) | OPf_MOD);
    unpackargsop->op_targ = pad_add_name_sv(invocant->name, 0, NULL, NULL);
    unpackargsop = newSTATEOP(0, NULL,
                              newASSIGNOP(OPf_STACKED, unpackargsop, 0,
                                          newOP(OP_SHIFT, OPf_WANT_SCALAR | OPf_SPECIAL)));

    if (numvars) {
        OP *lhsop = NULL;
        lhsop = newLISTOP(OP_LIST, 0, NULL, NULL);

        for (i = 0; i < numvars; i++) {
            OP *o;
            o = newOP(OP_PADSV, (OPpLVAL_INTRO << 8) | OPf_MOD);
            o->op_targ = pad_add_name_sv(vars[i]->name, 0, NULL, NULL);
            lhsop = op_append_elem(OP_LIST, lhsop, o);
        }
        Safefree(vars);

        unpackargsop = op_append_elem(OP_LIST, unpackargsop,
                                      newASSIGNOP(OPf_STACKED, lhsop, 0,
                                                  newAVREF(newGVOP(OP_GV, 0, PL_defgv))));
    }

    attrs = current_attributes(aTHX);
    for (j = 0; j <= av_len(attrs); j++) {
        SV *attr = *av_fetch(attrs, j, 0);
        OP *o = intro_twigil_var(aTHX_ attr);
        OP *initop, *fetchinvocantop, *initopargs;
        initopargs = newSVOP(OP_CONST, 0, SvREFCNT_inc(attr));
        initopargs = op_append_elem(OP_LIST, initopargs,
                                    newSVOP(OP_CONST, 0,
                                            SvREFCNT_inc(get_sv("mop::internals::"
                                                                "syntax::CURRENT_META", 0))));
        fetchinvocantop = newOP(OP_PADSV, 0);
        fetchinvocantop->op_targ = pad_findmy_sv(invocant->name, 0);
        initopargs = op_append_elem(OP_LIST, initopargs, fetchinvocantop);
        initop = newUNOP(OP_RAND, 0, newANONLIST(initopargs));
        initop->op_targ = o->op_targ;
        initop->op_ppaddr = pp_init_attr;

        if (!attrintroop) {
            attrintroop = o;
            attrinitop = initop;
        }
        else {
            attrintroop = op_append_elem(OP_LINESEQ, attrintroop, o);
            attrinitop = op_append_elem(OP_LINESEQ, attrinitop, initop);
        }
    }
    attrintroop = newSTATEOP(0, NULL, attrintroop);

    body = parse_block(0);
    if (!body)
        syntax_error(aTHX_ &PL_sv_undef);

    body = op_prepend_elem(OP_LINESEQ, attrinitop, body);
    body = op_prepend_elem(OP_LINESEQ, attrintroop, body);
    if (unpackargsop)
        body = op_prepend_elem(OP_LINESEQ, newSTATEOP(0, NULL, unpackargsop), body);

    return gen_traits_ops(aTHX_ op_append_elem(OP_LIST,
                                               newSVOP(OP_CONST, 0, SvREFCNT_inc(name)),
                                               newANONSUB(blk_floor, NULL, body)),
                          traits, numtraits);
}

static OP *
check_method(pTHX_ OP *entersubop, GV *namegv, SV *ckobj)
{
    OP *pushop, *nameop;

    PERL_UNUSED_ARG(namegv);
    PERL_UNUSED_ARG(ckobj);

    pushop = cUNOPx(entersubop)->op_first;
    if (!pushop->op_sibling)
        pushop = cUNOPx(pushop)->op_first;

    /* method("method_name", ...) */
    if ((nameop = pushop->op_sibling) && nameop->op_type == OP_CONST) {
        return PL_check[entersubop->op_type](aTHX_ entersubop);
    }

    /* required method to be compiled away */
    op_free(entersubop);
    return newOP(OP_NULL, 0);
}

static Perl_check_t old_rv2sv_checker;
static SV *twigils_hint_key_sv;
static U32 twigils_hint_key_hash;

static SV *
parse_ident(pTHX_ const char *prefix, STRLEN prefixlen)
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
twigil_enabled(pTHX)
{
    HE *he = hv_fetch_ent(GvHV(PL_hintgv), twigils_hint_key_sv, 0, twigils_hint_key_hash);
    return he && SvTRUE(HeVAL(he));
}

static OP *
myck_rv2sv(pTHX_ OP *o)
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

SV *
parse_modifier_with_single_value (modifier)
    char *modifier
  C_ARGS:
    aTHX_ modifier, SvCUR(ST(0))
  POSTCALL:
    SvREFCNT_inc(RETVAL); /* As above. */

void
parse_modifier_with_multiple_values (modifier)
    char *modifier
  PREINIT:
    AV *names;
    I32 i;
  PPCODE:
    names = parse_modifier_with_multiple_values(aTHX_ modifier, SvCUR(ST(0)));
    for (i = 0; i <= av_len(names); i++)
        PUSHs(*av_fetch(names, i, 0));

BOOT:
{
    CV *class, *role, *has, *method;

    class  = get_cv("mop::internals::syntax::class",  0);
    role   = get_cv("mop::internals::syntax::role",   0);
    has    = get_cv("mop::internals::syntax::has",    0);
    method = get_cv("mop::internals::syntax::method", 0);

    cv_set_call_checker(class,  ck_mop_keyword, &PL_sv_yes);
    cv_set_call_checker(role,   ck_mop_keyword, &PL_sv_yes);

    cv_set_call_parser(has,    parse_has,    &PL_sv_undef);
    cv_set_call_parser(method, parse_method, &PL_sv_undef);

    cv_set_call_checker(has,    check_has,    &PL_sv_undef);
    cv_set_call_checker(method, check_method, &PL_sv_undef);

    twigils_hint_key_sv = newSVpvs_share("mop::internals::syntax/twigils");
    twigils_hint_key_hash = SvSHARED_HASH(twigils_hint_key_sv);

    old_rv2sv_checker = PL_check[OP_RV2SV];
    PL_check[OP_RV2SV] = myck_rv2sv;
}
