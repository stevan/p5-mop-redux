#include "EXTERN.h"
#include "perl.h"
#define NO_XSLOCKS
#include "XSUB.h"

#include "callparser1.h"

/* subname magic {{{ */

static MGVTBL subname_vtbl;

/* }}} */
/* attribute magic {{{ */

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

#define set_attr_magic(var, name, meta, self) THX_set_attr_magic(aTHX_ var, name, meta, self)
static void
THX_set_attr_magic(pTHX_ SV *var, SV *name, SV *meta, SV *self)
{
    SV *svs[3];
    AV *data;
    svs[0] = name;
    svs[1] = meta;
    svs[2] = self;
    data = (AV *)sv_2mortal((SV *)av_make(3, svs));
    sv_magicext(var, (SV *)data, PERL_MAGIC_ext, &attr_vtbl, "attr", 0);
}

#define set_err_magic(var, name) THX_set_err_magic(aTHX_ var, name)
static void
THX_set_err_magic(pTHX_ SV *var, SV *name)
{
    sv_magicext(var, name, PERL_MAGIC_ext, &err_vtbl, "err", 0);
}

/* }}} */
/* stash magic {{{ */

static MGVTBL meta_vtbl;

#define get_meta(name) THX_get_meta(aTHX_ name)
static SV *
THX_get_meta(pTHX_ SV *name)
{
    MAGIC *mg = NULL;
    HV *stash;

    stash = gv_stashsv(name, 0);

    if (stash) {
        mg = mg_findext((SV *)stash, PERL_MAGIC_ext, &meta_vtbl);
    }

    return mg ? mg->mg_obj : &PL_sv_undef;
}

#define set_meta(name, meta) THX_set_meta(aTHX_ name, meta)
static void
THX_set_meta(pTHX_ SV *name, SV *meta)
{
    HV *stash;

    stash = gv_stashsv(name, GV_ADD);
    sv_magicext((SV *)stash, meta, PERL_MAGIC_ext, &meta_vtbl, "meta", 0);
}

#define unset_meta(name) THX_unset_meta(aTHX_ name)
static void
THX_unset_meta(pTHX_ SV *name)
{
    HV *stash;

    stash = gv_stashsv(name, GV_ADD);
    sv_unmagicext((SV *)stash, PERL_MAGIC_ext, &meta_vtbl);
}

/* }}} */
/* lexer helpers {{{ */

#ifndef OFFUNISKIP
#if UVSIZE >= 8
#  define UTF8_QUAD_MAX UINT64_C(0x1000000000)

/* Input is a true Unicode (not-native) code point */
#define OFFUNISKIP(uv) ( (uv) < 0x80        ? 1 : \
		      (uv) < 0x800          ? 2 : \
		      (uv) < 0x10000        ? 3 : \
		      (uv) < 0x200000       ? 4 : \
		      (uv) < 0x4000000      ? 5 : \
		      (uv) < 0x80000000     ? 6 : \
                      (uv) < UTF8_QUAD_MAX ? 7 : 13 )
#else
/* No, I'm not even going to *TRY* putting #ifdef inside a #define */
#define OFFUNISKIP(uv) ( (uv) < 0x80        ? 1 : \
		      (uv) < 0x800          ? 2 : \
		      (uv) < 0x10000        ? 3 : \
		      (uv) < 0x200000       ? 4 : \
		      (uv) < 0x4000000      ? 5 : \
		      (uv) < 0x80000000     ? 6 : 7 )
#endif
#endif

#define lex_peek_sv(len) THX_lex_peek_sv(aTHX_ len)
static SV *
THX_lex_peek_sv(pTHX_ STRLEN len)
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
        bufptr = PL_parser->bufptr;
        bufend = PL_parser->bufend;
    }

    if (lex_bufutf8()) {
        char *end = bufptr;
        STRLEN i;

        for (i = 0; i < len; ++i) {
            unsigned char skip = UTF8SKIP(end);

            if (end - bufptr + skip > bufend - bufptr)
                break;

            end += UTF8SKIP(end);
        }

        return sv_2mortal(newSVpvn_utf8(bufptr, end - bufptr, TRUE));
    }
    else {
        got = bufend - bufptr;
        if (got < len)
            len = got;
        return sv_2mortal(newSVpvn(bufptr, len));
    }
}

#define read_tokenish() THX_read_tokenish(aTHX)
static SV *
THX_read_tokenish(pTHX)
{
    char c;
    SV *ret = sv_2mortal(newSV(1));
    SvCUR_set(ret, 0);
    SvPOK_on(ret);

    if (strchr("$@%!:", lex_peek_unichar(LEX_KEEP_PREVIOUS)) != NULL)
        sv_catpvf(ret, "%c", lex_read_unichar(LEX_KEEP_PREVIOUS));

    c = lex_peek_unichar(LEX_KEEP_PREVIOUS);
    while (c != -1 && !isSPACE(c)) {
        sv_catpvf(ret, "%c", lex_read_unichar(LEX_KEEP_PREVIOUS));
        c = lex_peek_unichar(LEX_KEEP_PREVIOUS);
    }

    return ret;
}

#define PARSE_NAME_ALLOW_PACKAGE 1
#define parse_name_prefix(prefix, prefixlen, what, whatlen, flags) THX_parse_name_prefix(aTHX_ prefix, prefixlen, what, whatlen, flags)
static SV *
THX_parse_name_prefix(pTHX_ const char *prefix, STRLEN prefixlen,
                  const char *what, STRLEN whatlen, U32 flags)
{
    char *start, *s;
    STRLEN len = 0;
    SV *sv;

    if (flags & ~PARSE_NAME_ALLOW_PACKAGE)
        croak("unknown flags");

    /* copied with a few modifications from parse_ident in toke.c */
    for (;;) {
        I32 c = lex_peek_unichar(LEX_KEEP_PREVIOUS);
        if (lex_bufutf8() && isIDFIRST_uni(c)) {
             /* The UTF-8 case must come first, otherwise things
             * like c\N{COMBINING TILDE} would start failing, as the
             * isWORDCHAR_A case below would gobble the 'c' up.
             */

            do {
                len += OFFUNISKIP(c);
                lex_read_unichar(LEX_KEEP_PREVIOUS);
                c = lex_peek_unichar(LEX_KEEP_PREVIOUS);
            } while (isIDCONT_uni(c));
        }
        else if (isIDFIRST_A((U8)c)) {
            do {
                ++len;
                lex_read_unichar(LEX_KEEP_PREVIOUS);
                c = lex_peek_unichar(LEX_KEEP_PREVIOUS);
            } while (isIDCONT_A((U8)c));
        }
        else if ((flags & PARSE_NAME_ALLOW_PACKAGE) && c == ':') {
            ++len;
            lex_read_unichar(LEX_KEEP_PREVIOUS);
            c = lex_peek_unichar(LEX_KEEP_PREVIOUS);
            if (c == ':') {
                ++len;
                lex_read_unichar(LEX_KEEP_PREVIOUS);
                c = lex_peek_unichar(LEX_KEEP_PREVIOUS);
            }
            else {
                SV *buf;

                buf = newSVpvn(PL_parser->bufptr - len, len);
                croak("Invalid identifier: %"SVf"%"SVf,
                      SVfARG(buf),
                      SVfARG(read_tokenish()));
            }
        }
        else
            break;
    }

    if (!len)
        croak("%"SVf" is not a valid %.*s name",
              SVfARG(read_tokenish()), whatlen, what);
    sv = sv_2mortal(newSV(prefixlen + len));
    Copy(prefix, SvPVX(sv), prefixlen, char);
    Copy(PL_parser->bufptr - len, SvPVX(sv) + prefixlen, len, char);
    SvPVX(sv)[prefixlen + len] = '\0';
    SvCUR_set(sv, prefixlen + len);
    SvPOK_on(sv);
    if (lex_bufutf8())
        SvUTF8_on(sv);

    return sv;
}

#define parse_name(what, whatlen, flags) THX_parse_name(aTHX_ what, whatlen, flags)
static SV *
THX_parse_name(pTHX_ const char *what, STRLEN whatlen, U32 flags)
{
    return parse_name_prefix(NULL, 0, what, whatlen, flags);
}

/* }}} */
/* other helpers {{{ */

#define syntax_error(err) THX_syntax_error(aTHX_ err)
static void
THX_syntax_error(pTHX_ SV *err)
{
    dSP;
    ENTER;
    PUSHMARK(SP);
    XPUSHs(err);
    PUTBACK;
    call_pv("mop::internals::syntax::syntax_error", G_VOID);
    LEAVE;
}

#define current_meta_name() THX_current_meta_name(aTHX)
static SV *
THX_current_meta_name(pTHX)
{
    dSP;
    SV *ret;

    ENTER;
    PUSHMARK(SP);
    XPUSHs(get_sv("mop::internals::syntax::CURRENT_META", 0));
    PUTBACK;
    call_method("name", G_SCALAR);
    SPAGAIN;
    ret = SvREFCNT_inc(POPs);
    PUTBACK;
    LEAVE;

    return ret;
}

#define current_attributes() THX_current_attributes(aTHX)
static AV *
THX_current_attributes(pTHX)
{
    dSP;
    AV *ret;
    int nret, i;

    ENTER;
    PUSHMARK(SP);
    XPUSHs(get_sv("mop::internals::syntax::CURRENT_META", 0));
    PUTBACK;
    nret = call_method("attributes", G_ARRAY);
    SPAGAIN;
    ret = newAV();
    av_extend(ret, nret);
    for (i = 0; i < nret; ++i) {
        SV *attr;

        attr = POPs;
        PUTBACK;

        PUSHMARK(SP);
        XPUSHs(attr);
        PUTBACK;
        call_method("name", G_SCALAR);
        SPAGAIN;
        av_push(ret, POPs);
        PUTBACK;
    }
    LEAVE;

    return ret;
}

/* }}} */
/* twigils {{{ */

static Perl_check_t old_rv2sv_checker;
static SV *twigils_hint_key_sv;
static U32 twigils_hint_key_hash;

#define intro_twigil_var(namesv) THX_intro_twigil_var(aTHX_ namesv)
static OP *
THX_intro_twigil_var(pTHX_ SV *namesv)
{
    OP *o = newOP(OP_PADSV, (OPpLVAL_INTRO << 8) | OPf_MOD);
    o->op_targ = pad_add_name_sv(namesv, 0, NULL, NULL);
    return o;
}

#define parse_ident(prefix, prefixlen) THX_parse_ident(aTHX_ prefix, prefixlen)
static SV *
THX_parse_ident(pTHX_ const char *prefix, STRLEN prefixlen)
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

#define twigil_enabled() THX_twigil_enabled(aTHX)
static bool
THX_twigil_enabled(pTHX)
{
    HE *he = hv_fetch_ent(GvHV(PL_hintgv), twigils_hint_key_sv, 0, twigils_hint_key_hash);
    return he && SvTRUE(HeVAL(he));
}

static OP *
myck_rv2sv_twigils(pTHX_ OP *o)
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

    if (!twigil_enabled())
        return old_rv2sv_checker(aTHX_ o);

    if (*SvPVX(sv) != '!')
        return old_rv2sv_checker(aTHX_ o);

    prefix[0] = '$';
    prefix[1] = *SvPVX(sv);
    name = parse_ident(prefix, 2);
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

/* }}} */
/* keyword modifier parsing {{{ */

#define parse_modifier(modifier, len) THX_parse_modifier(aTHX_ modifier, len)
static bool
THX_parse_modifier(pTHX_ const char *modifier, STRLEN len)
{
    STRLEN got;
    char *s = SvPV(lex_peek_sv(len + 1), got);

    if (got < len)
        return FALSE;

    if (strnNE(s, modifier, len))
        return FALSE;

    if (got >= len + 1) {
        char last = s[len];
        if (isALNUM(last) || last == '_')
            return FALSE;
    }

    lex_read_to(PL_parser->bufptr + len);
    return TRUE;
}

#define parse_modifier_with_single_value(modifier, len) THX_parse_modifier_with_single_value(aTHX_ modifier, len)
static SV *
THX_parse_modifier_with_single_value(pTHX_ const char *modifier, STRLEN len)
{
    if (!parse_modifier(modifier, len))
        return NULL;

    lex_read_space(0);

    if (strnEQ(modifier, "extends", len))
        return parse_name("class", sizeof("class") - 1, PARSE_NAME_ALLOW_PACKAGE);

    return parse_name(modifier, len, PARSE_NAME_ALLOW_PACKAGE);
}

#define parse_modifier_with_multiple_values(modifier, len) THX_parse_modifier_with_multiple_values(aTHX_ modifier, len)
static AV *
THX_parse_modifier_with_multiple_values(pTHX_ const char *modifier, STRLEN len)
{
    AV *ret = (AV *)sv_2mortal((SV *)newAV());

    if (!parse_modifier(modifier, len))
        return ret;

    lex_read_space(0);

    do {
        SV *name = parse_name("role", sizeof("role"), PARSE_NAME_ALLOW_PACKAGE);
        av_push(ret, SvREFCNT_inc(name));
        lex_read_space(0);
    } while (lex_peek_unichar(0) == ',' && (lex_read_unichar(0), lex_read_space(0), TRUE));

    return ret;
}

/* }}} */
/* trait parsing {{{ */

struct mop_trait {
    SV *name;
    OP *params;
};

#define parse_traits(ntraitsp) THX_parse_traits(aTHX_ ntraitsp)
static struct mop_trait **
THX_parse_traits(pTHX_ UV *ntraitsp)
{
    dXCPT;
    U32 ntraits = 0;
    struct mop_trait **ret = NULL;

    if (!parse_modifier("is", 2)) {
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
            trait->name = parse_name("trait", sizeof("trait") - 1,
                                     PARSE_NAME_ALLOW_PACKAGE);

            if (lex_peek_unichar(0) == '(') {
                lex_read_unichar(0);
                trait->params = newANONLIST(parse_fullexpr(0));
                if (lex_peek_unichar(0) != ')')
                    syntax_error(sv_2mortal(newSVpvf("Unterminated parameter "
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

#define gen_traits_ops(append_to, traits, ntraits) THX_gen_traits_ops(aTHX_ append_to, traits, ntraits)
static OP *
THX_gen_traits_ops(pTHX_ OP *append_to, struct mop_trait **traits, UV ntraits)
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

/* }}} */
/* attribute parsing {{{ */

#define parse_has(namegv, psobj, flagsp) THX_parse_has(aTHX_ namegv, psobj, flagsp)
static OP *
THX_parse_has(pTHX_ GV *namegv, SV *psobj, U32 *flagsp)
{
    SV *name;
    UV ntraits;
    OP *default_value = NULL, *ret;
    struct mop_trait **traits;

    PERL_UNUSED_ARG(namegv);
    PERL_UNUSED_ARG(psobj);

    lex_read_space(0);

    if (lex_peek_unichar(0) != '$')
        syntax_error(sv_2mortal(newSVpvf("Invalid attribute name %"SVf,
                                         SVfARG(read_tokenish()))));
    lex_read_unichar(0);

    if (lex_peek_unichar(0) != '!')
        syntax_error(sv_2mortal(newSVpvf("Invalid attribute name $%"SVf,
                                         SVfARG(read_tokenish()))));
    lex_read_unichar(0);

    name = parse_name_prefix("$!", 2, "attribute", sizeof("attribute") - 1, 0);
    lex_read_space(0);

    traits = parse_traits(&ntraits);
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
        syntax_error(sv_2mortal(newSVpvf("Couldn't parse attribute %"SVf,
                                         SVfARG(name))));

    ret = op_append_elem(OP_LIST, newSVOP(OP_CONST, 0, SvREFCNT_inc(name)),
                         default_value ? default_value : newSVOP(OP_CONST, 0, &PL_sv_undef));
    ret = gen_traits_ops(ret, traits, ntraits);

    *flagsp = CALLPARSER_STATEMENT;
    return ret;
}

/* }}} */
/* method parsing {{{ */

struct mop_signature_var {
    SV *name;
    OP *default_value;
};

#define parse_signature(method_name, invocantp, varsp) THX_parse_signature(aTHX_ method_name, invocantp, varsp)
static UV
THX_parse_signature(pTHX_ SV *method_name,
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
                    syntax_error(sv_2mortal(newSVpvf("Invalid sigil: %c", sigil)));
                if (seen_slurpy)
                    syntax_error(sv_2mortal(newSVpvs("Can't declare parameters "
                                                     "after a slurpy parameter")));
                seen_slurpy = sigil == '@' || sigil == '%';
                lex_read_unichar(0);
                lex_read_space(0);

                Newxz(var, 1, struct mop_signature_var);

                var->name = parse_name_prefix(&sigil, 1, "argument",
                                              sizeof("argument") - 1, 0);
                lex_read_space(0);

                if (lex_peek_unichar(0) == '=') {
                    lex_read_unichar(0);
                    lex_read_space(0);
                    var->default_value = parse_arithexpr(0);
                    lex_read_space(0);
                }

                if (lex_peek_unichar(0) == ':') {
                    if (invocant)
                        syntax_error(sv_2mortal(newSVpvs("Cannot specify "
                                                         "multiple invocants")));
                    if (var->default_value)
                        syntax_error(sv_2mortal(newSVpvs("Cannot specify a default "
                                                         "value for the invocant")));
                    invocant = var;
                    lex_read_unichar(0);
                    lex_read_space(0);
                }
                else {
                    Renew(vars, numvars + 1, struct mop_signature_var *);
                    vars[numvars] = var;

                    if (lex_peek_unichar(0) != ')' && lex_peek_unichar(0) != ',')
                        syntax_error(sv_2mortal(newSVpvf("Unterminated prototype for "
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
        }
        lex_read_unichar(0);
    }

    if (!invocant) {
        Newxz(invocant, 1, struct mop_signature_var);
        invocant->name = sv_2mortal(newSVpvs("$self"));
    }

    *invocantp = invocant;
    *varsp = vars;
    return numvars;
}

#define gen_default_op(padoff, argsoff, o) THX_gen_default_op(aTHX_ padoff, argsoff, o)
static OP *
THX_gen_default_op(pTHX_ PADOFFSET padoff, UV argsoff, OP *o)
{
    OP *padop, *cmpop;

    padop = newOP(OP_PADSV, OPf_MOD);
    padop->op_targ = padoff;

    cmpop = newBINOP(OP_LT, 0,
                     newAVREF(newGVOP(OP_GV, 0, PL_defgv)),
                     newSVOP(OP_CONST, 0, newSVuv(argsoff + 1)));

    return newCONDOP(0, cmpop, newASSIGNOP(0, padop, 0, o), NULL);
}

static OP *
pp_init_attr(pTHX)
{
    dSP; dTARGET;
    AV *args = (AV *)SvRV(POPs);
    SV *attr_name = *av_fetch(args, 0, 0);
    SV *meta_class_name = *av_fetch(args, 1, 0);
    SV *invocant = *av_fetch(args, 2, 0);
    SV *meta_class = get_meta(meta_class_name);

    if (sv_isobject(invocant))
        set_attr_magic(TARG, attr_name, meta_class, invocant);
    else
        set_err_magic(TARG, attr_name);
    return PL_op->op_next;
}

#define parse_method(namegv, psobj, flagsp, floor) THX_parse_method(aTHX_ namegv, psobj, flagsp, floor)
static OP *
THX_parse_method(pTHX_ GV *namegv, SV *psobj, U32 *flagsp, I32 *floor)
{
    SV *name;
    AV *attrs;
    UV numvars, numtraits, i;
    IV j;
    int blk_floor;
    struct mop_signature_var **vars;
    struct mop_signature_var *invocant;
    struct mop_trait **traits;
    OP *body, *body_ref;
    OP *unpackargsop = NULL, *attrintroop = NULL, *attrinitop = NULL;
    U8 errors;

    PERL_UNUSED_ARG(namegv);
    PERL_UNUSED_ARG(psobj);

    *flagsp = CALLPARSER_STATEMENT;

    lex_read_space(0);
    name = parse_name("method", sizeof("method") - 1, 0);
    lex_read_space(0);

    switch (lex_peek_unichar(0)) {
    case ';':
        lex_read_unichar(0);
        /* fall through */
    case '}':
        return newSVOP(OP_CONST, 0, SvREFCNT_inc(name));
    }

    numvars = parse_signature(name, &invocant, &vars);
    lex_read_space(0);

    traits = parse_traits(&numtraits);
    lex_read_space(0);

    if (lex_peek_unichar(0) != '{')
        syntax_error(sv_2mortal(newSVpvs("Non-required methods require a body")));

    errors = PL_parser->error_count;

    blk_floor = start_subparse(0, CVf_ANON);

    unpackargsop = newOP(OP_PADSV, (OPpLVAL_INTRO << 8) | OPf_MOD);
    unpackargsop->op_targ = pad_add_name_sv(invocant->name, 0, NULL, NULL);
    unpackargsop = newSTATEOP(0, NULL,
                              newASSIGNOP(OPf_STACKED, unpackargsop, 0,
                                          newOP(OP_SHIFT, OPf_WANT_SCALAR | OPf_SPECIAL)));

    if (numvars) {
        OP *lhsop = newLISTOP(OP_LIST, 0, NULL, NULL);
        OP *defaultsops = NULL;

        for (i = 0; i < numvars; i++) {
            struct mop_signature_var *var = vars[i];
            OP *o = newOP(OP_PADSV, (OPpLVAL_INTRO << 8) | OPf_MOD);
            o->op_targ = pad_add_name_sv(var->name, 0, NULL, NULL);
            lhsop = op_append_elem(OP_LIST, lhsop, o);

            if (var->default_value)
                defaultsops = op_append_elem(OP_LINESEQ, defaultsops,
                                             gen_default_op(o->op_targ, i,
                                                            var->default_value));
        }
        Safefree(vars);

        unpackargsop = op_append_elem(OP_LINESEQ, unpackargsop,
                                      newASSIGNOP(OPf_STACKED, lhsop, 0,
                                                  newAVREF(newGVOP(OP_GV, 0, PL_defgv))));
        unpackargsop = op_append_elem(OP_LINESEQ, unpackargsop, defaultsops);
    }

    attrs = current_attributes();
    for (j = 0; j <= av_len(attrs); j++) {
        SV *attr = *av_fetch(attrs, j, 0);
        OP *o = intro_twigil_var(attr);
        OP *initop, *fetchinvocantop, *initopargs;
        initopargs = newSVOP(OP_CONST, 0, SvREFCNT_inc(attr));
        initopargs = op_append_elem(OP_LIST, initopargs,
                                    newSVOP(OP_CONST, 0, current_meta_name()));
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
    body = op_prepend_elem(OP_LINESEQ, attrinitop, body);
    body = op_prepend_elem(OP_LINESEQ, attrintroop, body);
    if (unpackargsop)
        body = op_prepend_elem(OP_LINESEQ, newSTATEOP(0, NULL, unpackargsop), body);

    body_ref = newANONSUB(blk_floor, NULL, body);

    if (PL_parser->error_count > errors)
        syntax_error(&PL_sv_undef);

    return gen_traits_ops(op_append_elem(OP_LIST,
                                         newSVOP(OP_CONST, 0, SvREFCNT_inc(name)),
                                         body_ref),
                          traits, numtraits);
}

/* }}} */
/* keyword checkers {{{ */

static OP *
return_true(pTHX_ OP *o, GV *namegv, SV *ckobj)
{
    PERL_UNUSED_ARG(namegv);
    PERL_UNUSED_ARG(ckobj);

    op_free(o);
    return newSVOP(OP_CONST, 0, &PL_sv_yes);
}

static OP *
compile_keyword_away(pTHX_ OP *o, GV *namegv, SV *ckobj)
{
    PERL_UNUSED_ARG(namegv);
    PERL_UNUSED_ARG(ckobj);

    op_free(o);
    return newOP(OP_NULL, 0);
}

/* }}} */
/* keyword parsers {{{ */

static OP *
run_has(pTHX_ GV *namegv, SV *psobj, U32 *flagsp)
{
    dSP;
    I32 floor = start_subparse(0, CVf_ANON);
    OP *o = parse_has(namegv, psobj, flagsp);
    GV *gv = gv_fetchpvs("mop::internals::syntax::add_attribute", 0, SVt_PVCV);
    CV *cv;

    o = newUNOP(OP_ENTERSUB, OPf_STACKED,
                op_append_elem(OP_LIST, o,
                               newUNOP(OP_RV2CV, 0,
                                       newGVOP(OP_GV, 0, gv))));
    cv = newATTRSUB(floor, NULL, NULL, NULL, newSTATEOP(0, NULL, o));
    if (CvCLONE(cv))
        cv = cv_clone(cv);

    ENTER;
    PUSHMARK(SP);
    PUTBACK;
    call_sv((SV *)cv, G_VOID);
    LEAVE;
    return newOP(OP_NULL, 0);
}

static OP *
run_method(pTHX_ GV *namegv, SV *psobj, U32 *flagsp)
{
    dSP;
    I32 floor = start_subparse(0, CVf_ANON);
    OP *o = parse_method(namegv, psobj, flagsp, &floor);
    GV *gv = gv_fetchpvs("mop::internals::syntax::add_method", 0, SVt_PVCV);
    CV *cv;

    o = newUNOP(OP_ENTERSUB, OPf_STACKED,
                op_append_elem(OP_LIST, o,
                               newUNOP(OP_RV2CV, 0,
                                       newGVOP(OP_GV, 0, gv))));
    cv = newATTRSUB(floor, NULL, NULL, NULL, o);
    if (CvCLONE(cv))
        cv = cv_clone(cv);

    ENTER;
    PUSHMARK(SP);
    PUTBACK;
    call_sv((SV *)cv, G_VOID);
    LEAVE;
    return newOP(OP_NULL, 0);
}

/* }}} */
/* xsubs: mop::internals::util {{{ */

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

SV *
get_meta (package)
    SV *package
  POSTCALL:
    SvREFCNT_inc(RETVAL);

void
set_meta (package, meta)
    SV *package
    SV *meta

void
unset_meta (package)
    SV *package

# }}}
# xsubs: mop::internals::syntax {{{

MODULE = mop  PACKAGE = mop::internals::syntax

PROTOTYPES: DISABLE

SV *
parse_name (what, flags=0)
    const char *what
    U32 flags
  C_ARGS:
    what, SvCUR(ST(0)), flags
  POSTCALL:
    SvREFCNT_inc(RETVAL); /* parse_name mortalises, which is what we want when
                             we start using it from C code */

SV *
read_tokenish ()
  POSTCALL:
    SvREFCNT_inc(RETVAL); /* As above. */

SV *
parse_modifier_with_single_value (modifier)
    char *modifier
  C_ARGS:
    modifier, SvCUR(ST(0))
  POSTCALL:
    SvREFCNT_inc(RETVAL); /* As above. */

void
parse_modifier_with_multiple_values (modifier)
    char *modifier
  PREINIT:
    AV *names;
    I32 i;
  PPCODE:
    names = parse_modifier_with_multiple_values(modifier, SvCUR(ST(0)));
    for (i = 0; i <= av_len(names); i++)
        PUSHs(*av_fetch(names, i, 0));

BOOT:
{
    CV *class, *role, *has, *method;

    class  = get_cv("mop::internals::syntax::class",  0);
    role   = get_cv("mop::internals::syntax::role",   0);
    has    = get_cv("mop::internals::syntax::has",    0);
    method = get_cv("mop::internals::syntax::method", 0);

    cv_set_call_checker(class,  return_true, &PL_sv_undef);
    cv_set_call_checker(role,   return_true, &PL_sv_undef);

    cv_set_call_parser(has,    run_has,    &PL_sv_undef);
    cv_set_call_parser(method, run_method, &PL_sv_undef);

    cv_set_call_checker(has,    compile_keyword_away, &PL_sv_undef);
    cv_set_call_checker(method, compile_keyword_away, &PL_sv_undef);

    twigils_hint_key_sv = newSVpvs_share("mop::internals::syntax/twigils");
    twigils_hint_key_hash = SvSHARED_HASH(twigils_hint_key_sv);

    old_rv2sv_checker = PL_check[OP_RV2SV];
    PL_check[OP_RV2SV] = myck_rv2sv_twigils;
}

# }}}
