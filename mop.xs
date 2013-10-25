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
    dSP;
    SV *name, *meta, *self, *attr, *val;

    name = *av_fetch((AV *)mg->mg_obj, 0, 0);
    meta = *av_fetch((AV *)mg->mg_obj, 1, 0);
    self = *av_fetch((AV *)mg->mg_obj, 2, 0);

    ENTER;
    PUSHMARK(SP);
    XPUSHs(meta);
    XPUSHs(name);
    PUTBACK;
    call_method("get_attribute", G_SCALAR);
    SPAGAIN;
    attr = POPs;
    PUTBACK;
    LEAVE;

    ENTER;
    PUSHMARK(SP);
    XPUSHs(attr);
    XPUSHs(self);
    PUTBACK;
    call_method("fetch_data_in_slot_for", G_SCALAR);
    SPAGAIN;
    val = POPs;
    PUTBACK;
    LEAVE;

    sv_setsv(sv, val);

    return 0;
}

static int
mg_attr_set(pTHX_ SV *sv, MAGIC *mg)
{
    dSP;
    SV *name, *meta, *self, *attr;

    name = *av_fetch((AV *)mg->mg_obj, 0, 0);
    meta = *av_fetch((AV *)mg->mg_obj, 1, 0);
    self = *av_fetch((AV *)mg->mg_obj, 2, 0);

    ENTER;
    PUSHMARK(SP);
    XPUSHs(meta);
    XPUSHs(name);
    PUTBACK;
    call_method("get_attribute", G_SCALAR);
    SPAGAIN;
    attr = POPs;
    PUTBACK;
    LEAVE;

    ENTER;
    PUSHMARK(SP);
    XPUSHs(attr);
    XPUSHs(self);
    XPUSHs(sv);
    PUTBACK;
    call_method("store_data_in_slot_for", G_VOID);
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
/* version helpers {{{ */

/* modified from prescan_version in core. prescan_version assumes that the
 * characters following a version number will be either ; or {, which isn't
 * true for us. */
#define peek_version(s, errstr) THX_peek_version(aTHX_ s, errstr)
STRLEN
THX_peek_version(pTHX_ const char *s, const char **errstr)
{
    const char *d = s;

    if (*d == 'v') { /* explicit v-string */
        d++;
        if (!isDIGIT(*d)) { /* degenerate v-string */
            return 0;
        }

        if (d[0] == '0' && isDIGIT(d[1])) {
            /* no leading zeros allowed */
            BADVERSION(0,errstr,"Invalid version format (no leading zeros)");
        }

        while (isDIGIT(*d))         /* integer part */
            d++;

        if (*d == '.')
        {
            d++;                 /* decimal point */
        }
        else
        {
            /* require v1.2.3 */
            BADVERSION(0,errstr,"Invalid version format (dotted-decimal versions require at least three parts)");
        }

        {
            int i = 0;
            int j = 0;
            while (isDIGIT(*d)) {        /* just keep reading */
                i++;
                while (isDIGIT(*d)) {
                    d++; j++;
                    /* maximum 3 digits between decimal */
                    if (j > 3) {
                        BADVERSION(0,errstr,"Invalid version format (maximum 3 digits between decimals)");
                    }
                }
                if (*d == '_') {
                    BADVERSION(0,errstr,"Invalid version format (no underscores)");
                }
                else if (*d == '.') {
                    d++;
                }
                else if (!isDIGIT(*d)) {
                    break;
                }
                j = 0;
            }

            if (i < 2) {
                /* requires v1.2.3 */
                BADVERSION(0,errstr,"Invalid version format (dotted-decimal versions require at least three parts)");
            }
        }
    }                                         /* end if dotted-decimal */
    else
    {                                        /* decimal versions */
        if (*d == '.') {
            BADVERSION(0,errstr,"Invalid version format (0 before decimal required)");
        }
        if (*d == '0' && isDIGIT(d[1])) {
            BADVERSION(0,errstr,"Invalid version format (no leading zeros)");
        }

        /* and we never support negative versions */
        if ( *d == '-') {
            BADVERSION(0,errstr,"Invalid version format (negative version number)");
        }

        /* consume all of the integer part */
        while (isDIGIT(*d))
            d++;

        /* look for a fractional part */
        if (*d == '.') {
            /* we found it, so consume it */
            d++;
        }
        else if (!*d || isSPACE(*d)) {
            /* found just an integer (or nothing) */
            return d - s;
        }
        else if ( d == s ) {
            /* didn't find either integer or period */
            return 0;
        }
        else if (*d == '_') {
            /* underscore can't come after integer part */
            BADVERSION(0,errstr,"Invalid version format (no underscores)");
        }
        else {
            /* anything else after integer part is just invalid data */
            BADVERSION(0,errstr,"Invalid version format (non-numeric data)");
        }

        /* scan the fractional part after the decimal point*/

        if (!isDIGIT(*d)) {
            BADVERSION(0,errstr,"Invalid version format (fractional part required)");
        }

        while (isDIGIT(*d)) {
            d++;
            if (*d == '.' && isDIGIT(d[-1])) {
                BADVERSION(0,errstr,"Invalid version format (dotted-decimal versions must begin with 'v')");
            }
            if (*d == '_') {
                BADVERSION(0,errstr,"Invalid version format (no underscores)");
            }
        }
    }

    return d - s;
}

static SV *
parse_version(const char *buf, STRLEN len)
{
    dSP;
    SV *v;

    ENTER;

    PUSHMARK(SP);
    XPUSHs(sv_2mortal(newSVpvs("version")));
    XPUSHs(sv_2mortal(newSVpvn(buf, len)));
    PUTBACK;
    call_method("parse", G_SCALAR);
    SPAGAIN;
    v = POPs;
    PUTBACK;

    LEAVE;

    return v;
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

#ifndef isIDCONT_uni
inline bool is_uni_idcont(pTHX_ UV c) {
    U8 tmpbuf[UTF8_MAXBYTES+1];
    uvchr_to_utf8(tmpbuf, c);
    return is_utf8_idcont(tmpbuf);
}
#define isIDCONT_uni(uv) is_uni_idcont(aTHX_ uv)
#endif
#ifndef isIDCONT_A
/* not ideal, but it's just for backcompat anyway */
#define isIDCONT_A(uv) isIDCONT_uni(uv)
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
    STRLEN len = 0;
    SV *sv;
    bool in_fqname = FALSE;

    if (flags & ~PARSE_NAME_ALLOW_PACKAGE)
        croak("unknown flags");

    for (;;) {
        UV c;

        /* XXX why does lex_peek_unichar return an I32? */
        c = (UV)lex_peek_unichar(LEX_KEEP_PREVIOUS);

        if (lex_bufutf8()) {
            if (in_fqname ? isIDCONT_uni(c) : isIDFIRST_uni(c)) {
                do {
                    len += OFFUNISKIP(c);
                    lex_read_unichar(LEX_KEEP_PREVIOUS);
                    c = (UV)lex_peek_unichar(LEX_KEEP_PREVIOUS);
                } while (isIDCONT_uni(c));
            }
        }
        else {
            if (in_fqname ? isIDCONT_A((U8)c) : isIDFIRST_A((U8)c)) {
                do {
                    ++len;
                    lex_read_unichar(LEX_KEEP_PREVIOUS);
                    c = (UV)lex_peek_unichar(LEX_KEEP_PREVIOUS);
                } while (isIDCONT_A((U8)c));
            }
        }

        if ((flags & PARSE_NAME_ALLOW_PACKAGE) && c == ':') {
            in_fqname = TRUE;
            ++len;
            lex_read_unichar(LEX_KEEP_PREVIOUS);
            c = (UV)lex_peek_unichar(LEX_KEEP_PREVIOUS);
            if (c == ':') {
                ++len;
                lex_read_unichar(LEX_KEEP_PREVIOUS);
                c = (UV)lex_peek_unichar(LEX_KEEP_PREVIOUS);
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
    if (!SvOK(err))
        err = ERRSV;

    PL_parser->error_count++;

    croak_sv(err);
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

#define load_classes(classes) THX_load_classes(aTHX_ classes)
static void
THX_load_classes(pTHX_ AV *classes)
{
    int i;

    for (i = 0; i <= av_len(classes); ++i) {
        SV *name;

        name = *av_fetch(classes, i, FALSE);

        if (SvOK(get_meta(name)))
            continue;

        /* have to make a copy of name here, because load_module modifies it */
        load_module(PERL_LOADMOD_NOIMPORT, newSVsv(name), NULL);
    }
}

#define isa(sv, name) THX_isa(aTHX_ sv, name)
static bool
THX_isa(pTHX_ SV *sv, const char *name)
{
    dSP;
    SV *ret;

    ENTER;

    PUSHMARK(SP);
    XPUSHs(sv);
    XPUSHs(sv_2mortal(newSVpv(name, 0)));
    PUTBACK;
    call_method("isa", G_SCALAR);
    SPAGAIN;
    ret = POPs;
    PUTBACK;

    LEAVE;

    return SvTRUE(ret);
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

#define parse_has() THX_parse_has(aTHX)
static OP *
THX_parse_has(pTHX)
{
    SV *name;
    UV ntraits;
    OP *default_value = NULL, *ret;
    struct mop_trait **traits;

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
        OP *default_op;

        lex_read_unichar(0);
        lex_read_space(0);
        floor = start_subparse(0, CVf_ANON);
        default_op = parse_fullexpr(0);
        if (default_op->op_type == OP_CONST) {
            default_value = default_op;
            LEAVE_SCOPE(floor);
        }
        else {
            default_value = newANONSUB(floor, NULL, default_op);
        }
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

    return ret;
}

/* }}} */
/* method parsing {{{ */

struct mop_signature_var {
    SV *name;
    OP *default_value;
};

static XOP init_attr_xop;

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

#define gen_init_attr_op(attr_name, meta_name, invocant_name) \
    THX_gen_init_attr_op(aTHX_ attr_name, meta_name, invocant_name)
static OP *
THX_gen_init_attr_op(pTHX_ SV *attr_name, SV *meta_name, SV *invocant_name)
{
    OP *introop, *fetchinvocantop, *initopargs;
    UNOP *initop;

    introop = intro_twigil_var(attr_name);

    initopargs = newSVOP(OP_CONST, 0, SvREFCNT_inc(attr_name));
    initopargs = op_append_elem(OP_LIST, initopargs,
                                newSVOP(OP_CONST, 0, newSVsv(meta_name)));
    fetchinvocantop = newOP(OP_PADSV, 0);
    fetchinvocantop->op_targ = pad_findmy_sv(invocant_name, 0);
    initopargs = op_append_elem(OP_LIST, initopargs, fetchinvocantop);
    NewOp(1101, initop, 1, UNOP);
    initop->op_type = OP_CUSTOM;
    initop->op_ppaddr = pp_init_attr;
    initop->op_flags = OPf_KIDS;
    initop->op_private = 1;
    initop->op_targ = introop->op_targ;
    initop->op_first = newANONLIST(initopargs);

    return newLISTOP(OP_LINESEQ, 0, introop, (OP *)initop);
}

#define parse_method() THX_parse_method(aTHX)
static OP *
THX_parse_method(pTHX)
{
    SV *name, *meta_name;
    AV *attrs;
    UV numvars, numtraits, i;
    IV j;
    int blk_floor;
    struct mop_signature_var **vars;
    struct mop_signature_var *invocant;
    struct mop_trait **traits;
    OP *body, *body_ref;
    OP *unpackargsop = NULL, *attrop = NULL;
    U8 errors;

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

    meta_name = current_meta_name();
    attrs = current_attributes();
    for (j = 0; j <= av_len(attrs); j++) {
        SV *attr_name = *av_fetch(attrs, j, 0);

        attrop = op_append_list(OP_LINESEQ,
                                attrop,
                                gen_init_attr_op(attr_name, meta_name, invocant->name));
    }
    Safefree(invocant);

    /* have to do this before the parse_block call */
    attrop = newSTATEOP(0, NULL, attrop);

    body = parse_block(0);
    body = op_prepend_elem(OP_LINESEQ, attrop, body);
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
/* namespace parsing {{{ */

static SV *default_class_metaclass_hint_key_sv,
    *default_role_metaclass_hint_key_sv;
static U32 default_class_metaclass_hint_key_hash,
    default_role_metaclass_hint_key_hash;

#define default_metaclass(is_class) THX_default_metaclass(aTHX_ is_class)
static SV *
THX_default_metaclass(pTHX_ bool is_class)
{
    SV *hint_key_sv = is_class
        ? default_class_metaclass_hint_key_sv : default_role_metaclass_hint_key_sv;
    U32 hint_key_hash = is_class
        ? default_class_metaclass_hint_key_hash : default_role_metaclass_hint_key_hash;
    HE *he = hv_fetch_ent(GvHV(PL_hintgv), hint_key_sv, 0, hint_key_hash);

    if (!he)
        return is_class ? newSVpvs_share("mop::class") : newSVpvs_share("mop::role");

    return sv_2mortal(SvREFCNT_inc(HeVAL(he)));
}

#define new_meta(metaclass, name, version, roles, superclass) \
    THX_new_meta(aTHX_ metaclass, name, version, roles, superclass)
static SV *
THX_new_meta(pTHX_ SV *metaclass, SV *name, SV *version, AV *roles, SV *superclass)
{
    dSP;
    SV *ret, *roles_ref = newRV_inc((SV *)roles);

    ENTER;
    PUSHMARK(SP);
    XPUSHs(metaclass);
    XPUSHs(name);
    XPUSHs(version ? version : &PL_sv_undef);
    XPUSHs(roles_ref);
    if (superclass)
        XPUSHs(superclass);
    PUTBACK;
    call_pv("mop::internals::syntax::new_meta", G_SCALAR);
    SPAGAIN;
    ret = SvREFCNT_inc(POPs);
    PUTBACK;
    LEAVE;

    SvREFCNT_dec(roles_ref);
    return sv_2mortal(ret);
}

static void
restore_name_keyword(void *p)
{
    GV *name_gv = (GV *)p;
    GvCV_set(name_gv, NULL);
}

#define parse_namespace(is_class, pkgp) \
    THX_parse_namespace(aTHX_ is_class, pkgp)
static OP *
THX_parse_namespace(pTHX_ bool is_class, SV **pkgp)
{
    I32 floor;
    SV *name, *version, *extends, *metaclass, *meta, *name_keyword;
    AV *classes_to_load, *with;
    GV *name_gv, *meta_gv;
    struct mop_trait **traits;
    UV numtraits;
    const char *caller, *err = NULL;
    STRLEN versionlen, callerlen;
    OP *body, *body_ref;

    lex_read_space(0);

    name = parse_name(is_class ? "class" : "role",
                      (is_class ? sizeof("class") : sizeof("role")) - 1,
                      PARSE_NAME_ALLOW_PACKAGE);

    caller = SvPV(PL_curstname, callerlen);
    if (!memchr(SvPV_nolen(name), ':', SvCUR(name))
     && strnNE(caller, "main", sizeof("main") - 1)) {
        name = sv_2mortal(newSVpvf("%.*s::%"SVf, (int)callerlen, caller, SVfARG(name)));
    }

    lex_read_space(0);

    versionlen = peek_version(PL_parser->bufptr, &err);
    if (versionlen) {
        version = parse_version(PL_parser->bufptr, versionlen);
        lex_read_to(PL_parser->bufptr + versionlen);
    }
    else if (err) {
        syntax_error(newSVpv(err, 0));
    }
    else {
        version = NULL;
    }

    lex_read_space(0);
    classes_to_load = (AV *)sv_2mortal((SV *)newAV());
    if (is_class) {
        if ((extends = parse_modifier_with_single_value("extends", sizeof("extends") - 1))) {
            av_push(classes_to_load, SvREFCNT_inc(extends));
        }
        else {
            extends = sv_2mortal(newSVpvs("mop::object"));
        }

        lex_read_space(0);
    }
    else {
        SV *s = lex_peek_sv(7); /* FIXME */

        if (sv_cmp(s, sv_2mortal(newSVpvs("extends"))) == 0)
            syntax_error(sv_2mortal(newSVpvs("Roles cannot use 'extends'")));
    }

    if ((with = parse_modifier_with_multiple_values("with", sizeof("with") - 1))) {
        I32 i, plen = av_len(classes_to_load) + 1;
        av_extend(classes_to_load, av_len(classes_to_load) + av_len(with));
        for (i = 0; i <= av_len(with); i++)
            av_store(classes_to_load, plen + i, SvREFCNT_inc(*av_fetch(with, i, 0)));
    }
    lex_read_space(0);

    if ((metaclass = parse_modifier_with_single_value("meta", sizeof("meta") - 1)))
        av_push(classes_to_load, SvREFCNT_inc(metaclass));
    else
        metaclass = default_metaclass(is_class);
    lex_read_space(0);

    traits = parse_traits(&numtraits);
    lex_read_space(0);

    load_classes(classes_to_load);

    if (lex_peek_unichar(0) != '{')
        syntax_error(sv_2mortal(newSVpvf("%s must be followed by a block",
                                         is_class ? "class" : "role")));

    /* NOTE: *not* sv_derived_from - that's broken because it doesn't check
     * for overridden isa methods */
    if (!isa(metaclass, is_class ? "mop::class" : "mop::role"))
        syntax_error(sv_2mortal(newSVpvf("The metaclass for %"SVf" (%"SVf") does not inherit from %s", SVfARG(name), SVfARG(metaclass), is_class ? "mop::class" : "mop::role")));

    meta = new_meta(metaclass, name, version, with, is_class ? extends : NULL);
    *pkgp = name;

    name_keyword = sv_2mortal(newSVpvf("%s::__%s__",
                                       caller,
                                       is_class ? "CLASS" : "ROLE"));
    name_gv = gv_fetchsv(name_keyword, GV_ADD, SVt_PVCV);
    /* XXX pretty sure there's a better way to do this than SAVEDESTRUCTOR
     * (SAVEt_GVSLOT maybe?) but none of the save stack stuff is documented
     * and this works for now */
    SAVEDESTRUCTOR(restore_name_keyword, name_gv);
    GvCV_set(name_gv, newCONSTSUB(NULL, NULL, name));

    meta_gv = gv_fetchpvs("mop::internals::syntax::CURRENT_META", 0, SVt_NULL);
    save_scalar(meta_gv);
    sv_setsv(GvSV(meta_gv), meta);
    floor = start_subparse(0, 0);

    body = parse_block(0);

    body_ref = newANONSUB(floor, NULL, newSTATEOP(0, NULL, body));

    return gen_traits_ops(op_append_elem(OP_LIST,
                                         newSVOP(OP_CONST, 0, meta),
                                         body_ref),
                          traits, numtraits);
}

/* }}} */
/* keyword checkers {{{ */

static OP *
compile_keyword_away(pTHX_ OP *o, GV *namegv, SV *ckobj)
{
    PERL_UNUSED_ARG(namegv);
    PERL_UNUSED_ARG(ckobj);

    op_free(o);
    return newOP(OP_NULL, 0);
}

static OP *
return_true(pTHX_ OP *o, GV *namegv, SV *ckobj)
{
    PERL_UNUSED_ARG(namegv);
    PERL_UNUSED_ARG(ckobj);

    op_free(o);
    return newSVOP(OP_CONST, 0, &PL_sv_yes);
}

/* }}} */
/* keyword parsers {{{ */

static OP *
run_has(pTHX_ GV *namegv, SV *psobj, U32 *flagsp)
{
    GV *gv = gv_fetchpvs("mop::internals::syntax::add_attribute", 0, SVt_PVCV);
    I32 floor;
    OP *o;
    CV *cv;

    PERL_UNUSED_ARG(namegv);
    PERL_UNUSED_ARG(psobj);

    *flagsp = CALLPARSER_STATEMENT;

    floor = start_subparse(0, CVf_ANON);

    o = newUNOP(OP_ENTERSUB, OPf_STACKED,
                op_append_elem(OP_LIST, parse_has(),
                               newUNOP(OP_RV2CV, 0,
                                       newGVOP(OP_GV, 0, gv))));
    cv = newATTRSUB(floor, NULL, NULL, NULL, newSTATEOP(0, NULL, o));
    if (CvCLONE(cv))
        cv = cv_clone(cv);

    {
        dSP;
        ENTER;
        PUSHMARK(SP);
        call_sv((SV *)cv, G_VOID);
        LEAVE;
    }

    return newOP(OP_NULL, 0);
}

static OP *
run_method(pTHX_ GV *namegv, SV *psobj, U32 *flagsp)
{
    GV *gv = gv_fetchpvs("mop::internals::syntax::add_method", 0, SVt_PVCV);
    I32 floor;
    OP *o;
    CV *cv;

    PERL_UNUSED_ARG(namegv);
    PERL_UNUSED_ARG(psobj);

    *flagsp = CALLPARSER_STATEMENT;

    floor = start_subparse(0, CVf_ANON);

    o = newUNOP(OP_ENTERSUB, OPf_STACKED,
                op_append_elem(OP_LIST, parse_method(),
                               newUNOP(OP_RV2CV, 0,
                                       newGVOP(OP_GV, 0, gv))));
    cv = newATTRSUB(floor, NULL, NULL, NULL, o);
    if (CvCLONE(cv))
        cv = cv_clone(cv);

    {
        dSP;
        ENTER;
        PUSHMARK(SP);
        call_sv((SV *)cv, G_VOID);
        LEAVE;
    }

    return newOP(OP_NULL, 0);
}

static void
remove_meta(pTHX_ void *p)
{
    SV **pkgp = (SV **)p;

    if (*pkgp)
        unset_meta(*pkgp);
}

static OP *
run_namespace(pTHX_ GV *namegv, SV *psobj, U32 *flagsp)
{
    GV *gv = gv_fetchpvs("mop::internals::syntax::build_meta", 0, SVt_PVCV);
    SV *pkg = NULL;
    I32 floor;
    OP *o;
    CV *cv;

    PERL_UNUSED_ARG(psobj);

    *flagsp = CALLPARSER_STATEMENT;

    ENTER;
    SAVEDESTRUCTOR_X(remove_meta, &pkg);

    floor = start_subparse(0, CVf_ANON);

    o = parse_namespace(strnEQ(GvNAME(namegv), "class", sizeof("class")), &pkg);
    o = newUNOP(OP_ENTERSUB, OPf_STACKED,
                op_append_elem(OP_LIST, o,
                               newUNOP(OP_RV2CV, 0,
                                       newGVOP(OP_GV, 0, gv))));

    cv = newATTRSUB(floor, NULL, NULL, NULL, o);
    if (CvCLONE(cv))
        cv = cv_clone(cv);

    {
        dSP;
        ENTER;
        PUSHMARK(SP);
        call_sv((SV *)cv, G_VOID);
        LEAVE;
    }

    pkg = NULL;

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

    class  = get_cv("mop::internals::syntax::class",  GV_ADD);
    role   = get_cv("mop::internals::syntax::role",   GV_ADD);
    has    = get_cv("mop::internals::syntax::has",    GV_ADD);
    method = get_cv("mop::internals::syntax::method", GV_ADD);

    cv_set_call_parser(class,  run_namespace, &PL_sv_undef);
    cv_set_call_parser(role,   run_namespace, &PL_sv_undef);
    cv_set_call_parser(has,    run_has,       &PL_sv_undef);
    cv_set_call_parser(method, run_method,    &PL_sv_undef);

    cv_set_call_checker(class,  return_true,          &PL_sv_undef);
    cv_set_call_checker(role,   return_true,          &PL_sv_undef);
    cv_set_call_checker(has,    compile_keyword_away, &PL_sv_undef);
    cv_set_call_checker(method, compile_keyword_away, &PL_sv_undef);

    twigils_hint_key_sv = newSVpvs_share("mop::internals::syntax/twigils");
    twigils_hint_key_hash = SvSHARED_HASH(twigils_hint_key_sv);
    default_class_metaclass_hint_key_sv = newSVpvs_share("mop/default_class_metaclass");
    default_class_metaclass_hint_key_hash
        = SvSHARED_HASH(default_class_metaclass_hint_key_sv);
    default_role_metaclass_hint_key_sv = newSVpvs_share("mop/default_role_metaclass");
    default_role_metaclass_hint_key_hash
        = SvSHARED_HASH(default_role_metaclass_hint_key_sv);

    wrap_op_checker(OP_RV2SV, myck_rv2sv_twigils, &old_rv2sv_checker);

    XopENTRY_set(&init_attr_xop, xop_name, "init_attr");
    XopENTRY_set(&init_attr_xop, xop_desc, "attribute initialization");
    XopENTRY_set(&init_attr_xop, xop_class, OA_UNOP);
    Perl_custom_op_register(aTHX_ pp_init_attr, &init_attr_xop);
}

# }}}
