#!/usr/bin/awk -f

BEGIN {
    tty = system("test ! -t 2");

    Q = "\047";
    QQ = "\042";
    BS = "\134";
    CR = "\r";
    LF = "\n";
    SP = "\040";
    HTAB = "\011";

    # ALPHA =  %x41-5A / %x61-7A   ; A-Z / a-z
    alpha = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz";

    # DIGIT =  %x30-39 ; 0-9
    digit = "0123456789";

    # VCHAR =  %x21-7E ; visible (printing) characters
    split("!" QQ "#$%&'()*+,-./" alpha digit \
        ":;<=>?@[" BS "]^_`{|}~", arr_vchar, "");

    # US-ASCII control characters that do not include the carriage return,
    # line feed, and white space characters
    obs_no_ws_ctl = "\001\002\003\004\005\006\007\010" \
        "\013\014" \
        "\016\017" \
        "\020\021\022\023\024\025\026\027" \
        "\030\031\032\033\034\035\036\037";

    split(obs_no_ws_ctl, arr_obs_no_ws_ctl, "");

    # atext = ALPHA / DIGIT /    ; Printable US-ASCII
    #         "!" / "#" /        ;  characters not including
    #         "$" / "%" /        ;  specials.  Used for atoms.
    #         "&" / "'" /
    #         "*" / "+" /
    #         "-" / "/" /
    #         "=" / "?" /
    #         "^" / "_" /
    #         "`" / "{" /
    #         "|" / "}" /
    #         "~"
    atext = alpha digit "!#$%&'*+-/=?^_`{|}~";

    # ctext = %d33-39 /          ; Printable US-ASCII
    #         %d42-91 /          ;  characters not including
    #         %d93-126 /         ;  "(", ")", or "\"
    #         obs-ctext
    ctext = "!" QQ "#$%&'" alpha digit "*+,-./:;<=>? @[" \
        "]^_`{|}~" obs_no_ws_ctl;

    # dtext = %d33-90 /          ; Printable US-ASCII
    #         %d94-126 /         ;  characters not including
    #         obs-dtext          ;  "[", "]", or "\"
    dtext = "!" QQ "#$%&'()*+,-./:;<=>?@" alpha digit "^_`{|}~";

    # ftext = %d33-57 /          ; Printable US-ASCII
    #         %d59-126           ;  characters not including
    #                            ;  ":".
    ftext = "!" QQ "#$%&'()*+,-./" ";<=>?@[" alpha digit BS "]^_`{|}~";

    # qtext = %d33 /             ; Printable US-ASCII
    #         %d35-91 /          ;  characters not including
    #         %d93-126 /         ;  "\" or the quote character
    #         obs-qtext
    #
    # obs-qtext = obs-NO-WS-CTL
    qtext = "!#$%&'()*+,-./:;<=>?@[]" alpha digit "^_`{|}~" obs_no_ws_ctl;


    # WSP = SP / HTAB ; white space
    wsp = SP HTAB;

    arr_wsp[1] = SP;
    arr_wsp[2] = HTAB;

    split("Mon Tue Wed Thu Fri Sat Sun", arr_week, SP);
    split("Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec", arr_month, SP);
    split("UT GMT EST EDT CST CDT MST MDT PST PDT", arr_obs_zone, SP);

    field = "";
    buf = "";
    gbuf = "";
    obuf = "";
    ebuf = "";
    error = 0;
    header_nr = 0;
}

# https://unix.stackexchange.com/a/363471/53620
# is_true_zero
function z(obj, _, _x, _i, _z) {
    if (obj) { return 0; }

    _["found_delim"] = 0;

    _["convfmt"] = CONVFMT;
    CONVFMT = "% g";
    split(SP obj "\1" obj, _x, "\1");

    _["size"] = 0;
    for (_i in _x) { _["size"]++; }

    if (_["size"] > 2) {
        _["found_delim"] = 1;
    }
    else {
        _x[1] = obj == _x[1];
        _x[2] = obj == _x[2];
        _x[3] = obj == 0;
        _x[4] = obj "" == +obj;
    }

    CONVFMT = _["convfmt"];

    if (_["found_delim"]) { return 0; }

    _z["0001"] = _z["1101"] = _z["1111"] = "number";
    _z["0100"] = _z["0101"] = _z["0111"] = "string";
    _z["1100"] = _z["1110"] = "strnum";
    _z["0110"] = "undefined";

    return _z[_x[1] _x[2] _x[3] _x[4]] == "number";
}

function optional(strnum) {
    if (z(strnum)) {
        return "";
    }

    return strnum;
}

function emphasize(str) {
    if (tty) {
        return "\033[31m" "\033[4m" str "\033[24m" "\033[0m";
    }

    return str;
}

function ltrim(str) {
    sub(/^[ \t\r\n]+/, "", str);
    return str;
}

function rtrim(str) {
    sub(/[ \t\r\n]+$/, "", str);
    return str;
}

function trim(str) {
    return rtrim(ltrim(str));
}

function diag(str) {
    print str > "/dev/stderr";
}

function quote(str) {
    gsub(Q, Q BS Q Q, str);
    return Q str Q;
}

function stack(key, value) {
    obuf = obuf quote(key) SP quote(trim(value)) SP BS LF;
}

function flush() {
    if (buf) { stack("unstructured", buf); }
    buf = "";
    printf("%s", obuf);
    obuf = "";
}

function markout(stash, anchor) {
    stash["buf"] = buf;
    stash["obuf"] = obuf;
    if (anchor) { stack("---", anchor); }
    return 1;
}

function _clear(stash) {
    buf = stash["buf"];
    obuf = stash["obuf"];
    return 1;
}

function fatal(stash, _) {
    if (ebuf == "") {
        _["pos"] = length(gbuf) - length(stash["buf"]);

        ebuf = "pos:" _["pos"] SP "[" field "]:" \
            substr(gbuf, 0, _["pos"]) \
            emphasize(substr(gbuf, _["pos"] + 1));
    }

    _clear(stash)
    return 1;
}

function fallback(stash) {
    ebuf = "";
    _clear(stash);
    return 1;
}

function next_token(chars, _) {
    _["len"] = length(buf);
    for (_["pos"] = 0; _["pos"]++ < _["len"];) {
        if (index(chars, substr(buf, _["pos"], 1)) < 1) {
            _["tmp"] = substr(buf, 0, _["pos"] - 1);
            buf = substr(buf, _["pos"]);
            return _["tmp"];
        }
    }

    _["tmp"] = buf;
    buf = "";

    return _["tmp"];
}

function next_token_arr(array, _i, _) {
    _["tmp"] = "";
    do {
        _["seen"] = 0;
        for (_i in array) {
            _["token"] = next_str(array[_i]);
            if (!z(_["token"])) {
                _["seen"] = 1;
                _["tmp"] = _["tmp"] _["token"];
                break;
            }
        }
    } while(_["seen"])

    return _["tmp"];
}

function next_str(str, _) {
    split("", _); markout(_);

    _["str_len"] = length(str);
    if (length(buf) >= _["str_len"] && _["str_len"] > 0) {
        _["pre"] = substr(buf, 0, _["str_len"]);
        if (_["pre"] == str) {
            buf = substr(buf, _["str_len"] + 1);
            return _["pre"];
        }
    }

    fatal(_);
    return 0;
}

function next_arr(array, _i, _) {
    split("", _); markout(_);

    for (_i in array) {
        _["tmp"] = next_str(array[_i]);
        if (!z(_["tmp"])) {
            return _["tmp"];
        }
    }

    fatal(_);
    return 0;
}

# [*WSP CRLF] 1*WSP
function _consume_fws(_) {
    split("", _); markout(_);

    _["wsp1"] = next_token(wsp);
    _["crlf"] = next_str(CR LF);
    _["wsp2"] = next_token(wsp);

    # wsp2 can be empty when crlf is not exists
    if (_["wsp1"] == "" && _["wsp2"] == "") {
        fatal(_);
        return 0;
    }

    if (z(_["crlf"])) { _["crlf"] = ""; }

    _["tmp"] = _["wsp1"] _["crlf"] _["wsp2"];
    return _["tmp"];
}

# obs-FWS = 1*WSP *(CRLF 1*WSP)
function _consume_obs_fws(_) {
    split("", _); markout(_);

    _["tmp"] = next_token(wsp);
    if (_["tmp"] == "") { fatal(_); return 0; }

    while (1) {
        _["crlf"] = next_str(CR LF);
        if (z(_["crlf"])) { break; }
        _["tmp"] = _["tmp"] _["crlf"];

        _["wsp2"] = next_token(wsp);
        if (_["wsp2"] == "") { fatal(_); return 0 }
        _["tmp"] = _["tmp"] _["wsp2"];
    }

    return _["tmp"];
}

# FWS = ([*WSP CRLF] 1*WSP) / obs-FWS
function consume_fws(_) {
    split("", _); markout(_);

    _["fws"] = _consume_fws();
    if (z(_["fws"])) { fallback(_); _["fws"] = _consume_obs_fws(); }
    if (z(_["fws"])) { _["fws"] = ""; }

    return _["fws"];
}

# "\" (VCHAR / WSP)
function _consume_quoted_pair(_) {
    split("", _); markout(_);

    _["tmp"] = next_str(BS);
    if (!z(_["tmp"])) {
        _["tmp2"] = next_arr(arr_vchar);
        if (z(_["tmp2"])) {
            _["tmp2"] = next_arr(arr_wsp);
        }

        if (!z(_["tmp2"])) {
            return _["tmp"] _["tmp2"];
        }
    }

    fatal(_);
    return 0;
}

# obs-qp = "\" (%d0 / obs-NO-WS-CTL / LF / CR)
function _consume_obs_qp(_) {
    split("", _); markout(_);

    _["tmp"] = next_str(BS);
    if (!z(_["tmp"])) {
        _["nul"] = next_str("\000");
        if (!z(_["nul"])) { return _["tmp"] _["nul"]; }

        _["c"] = next_arr(arr_obs_no_ws_ctl);
        if (!z(_["c"])) { return _["tmp"] _["c"]; }

        _["lf"] = next_str(LF);
        if (!z(_["lf"])) { return _["tmp"] _["lf"]; }

        _["cr"] = next_str(CR);
        if (!z(_["cr"])) { return _["tmp"] _["cr"]; }
    }

    fatal(_);
    return 0;
}

# quoted-pair = ("\" (VCHAR / WSP)) / obs-qp
function consume_quoted_pair(_) {
    split("", _); markout(_);

    _["tmp"] = _consume_quoted_pair();
    if (z(_["tmp"])) { fallback(_); _["tmp"] = _consume_obs_qp(); }
    if (z(_["tmp"])) { fatal(_); return 0; }

    return _["tmp"];
}

# ccontent = ctext / quoted-pair / comment
function consume_ccontent(_) {
    split("", _); markout(_);

    _["tmp"] = next_token(ctext);
    if (_["tmp"] != "") { return _["tmp"]; }

    _["tmp"] = consume_quoted_pair();
    if (!z(_["tmp"])) { return _["tmp"]; }

    _["tmp"] = consume_comment();
    if (!z(_["tmp"])) { return _["tmp"]; }

    fatal(_);
    return 0;
}

# comment = "(" *([FWS] ccontent) [FWS] ")"
function consume_comment(_) {
    split("", _); markout(_);

    _["tmp"] = "";

    _["op_brace"] = next_str("(");
    if (z(_["op_brace"])) { fatal(_); return 0; }
    _["tmp"] = _["tmp"] _["op_brace"];

    _["comment"] = "";
    while (1) {
        _["fws"] = consume_fws();
        if (!z(_["fws"])) {
            _["comment"] = _["comment"] _["fws"];
        }

        _["ccontent"] = consume_ccontent();
        if (z(_["ccontent"])) { break; }
        _["comment"] = _["comment"] _["ccontent"];
    }

    stack("comment", _["comment"]);
    _["tmp"] = _["tmp"] _["comment"];

    _["cl_brace"] = next_str(")");
    if (z(_["cl_brace"])) { fatal(_); return 0; }

    return _["tmp"] _["cl_brace"];
}

# CFWS = (1*([FWS] comment) [FWS]) / FWS
function consume_cfws(_) {
    split("", _); markout(_);

    _["tmp"] = "";
    _["comment_found"] = 0;

    while (1) {
        _["tmp"] = _["tmp"] optional(consume_fws());

        _["comment"] = consume_comment();
        if (!z(_["comment"])) {
            # Skip comments
            _["comment_found"]++;
        }
        else {
            break;
        }
    }

    _["tmp"] = _["tmp"] optional(consume_fws());

    if (_["tmp"] || _["comment_found"]) {
        return _["tmp"];
    }
    else {
        fatal(_);
        return 0;
    }
}

# [FWS] day-name
function _consume_day_of_week(_) {
    split("", _); markout(_);

    _["tmp"] = "";

    _["tmp"] = _["tmp"] optional(consume_fws());

    _["day_name"] = next_arr(arr_week);
    if (z(_["day_name"])) { fatal(_); return 0; }
    _["tmp"] = _["tmp"] _["day_name"];

    stack("day-name", _["day_name"]);
    return _["tmp"];
}

# obs-day-of-week = [CFWS] day-name [CFWS]
function _consume_obs_day_of_week(_) {
    split("", _); markout(_);

    _["tmp"] = "";

    _["tmp"] = _["tmp"] optional(consume_cfws());

    _["day_name"] = next_arr(arr_week);
    if (z(_["day_name"])) { fatal(_); return 0; }
    _["tmp"] = _["tmp"] _["day_name"];

    _["tmp"] = _["tmp"] optional(consume_cfws());

    stack("day-name", _["day_name"]);
    return _["tmp"];
}

# day-of-week = ([FWS] day-name) / obs-day-of-week
function consume_day_of_week(_) {
    split("", _); markout(_);

    _["dow"] = _consume_day_of_week();
    if (z(_["dow"])) { fallback(_); _["dow"] = _consume_obs_day_of_week(); }
    if (z(_["dow"])) { fatal(_); return 0; }

    return _["dow"];
}

# [FWS] 1*2DIGIT FWS
function _consume_day(_) {
    split("", _); markout(_);

    _["tmp"] = "";

    _["tmp"] = _["tmp"] optional(consume_fws());

    _["digit"] = next_token(digit);
    _["len"] = length(_["digit"]);
    if (_["len"] < 1) { fatal(_); return 0; }
    if (_["len"] > 2) { fatal(_); return 0; }
    _["tmp"] = _["tmp"] _["digit"];

    _["fws"] = consume_fws();
    if (z(_["fws"])) { fatal(_); return 0; }
    _["tmp"] = _["tmp"] _["fws"];

    stack("day", _["digit"]);
    return _["tmp"];
}

# obs-day = [CFWS] 1*2DIGIT [CFWS]
function _consume_obs_day(_) {
    split("", _); markout(_);

    _["tmp"] = "";

    _["tmp"] = _["tmp"] optional(consume_cfws());

    _["digit"] = next_token(digit);
    _["len"] = length(_["digit"]);
    if (_["len"] < 1) { fatal(_); return 0; }
    if (_["len"] > 2) { fatal(_); return 0; }
    _["tmp"] = _["tmp"] _["digit"];

    _["tmp"] = _["tmp"] optional(consume_cfws());

    stack("obs-day", _["digit"]);
    return _["tmp"];
}

# day = ([FWS] 1*2DIGIT FWS) / obs-day
function consume_day(_) {
    split("", _); markout(_);

    _["day"] = _consume_day();
    if (z(_["day"])) { fallback(_); _["day"] = _consume_obs_day(); }
    if (z(_["day"])) { fatal(_); return 0; }

    return _["day"];
}

# month =   "Jan" / "Feb" / "Mar" / "Apr" /
#           "May" / "Jun" / "Jul" / "Aug" /
#           "Sep" / "Oct" / "Nov" / "Dec"
function consume_month(_) {
    split("", _); markout(_);

    _["tmp"] = next_arr(arr_month);
    if (z(_["tmp"])) { fatal(_); return 0; }

    stack("month", _["tmp"]);
    return _["tmp"];
}

# FWS 4*DIGIT FWS
function _consume_year(_) {
    split("", _); markout(_);

    _["tmp"] = "";

    _["fws"] = consume_fws();
    if (z(_["fws"])) { fatal(_); return 0; }
    _["tmp"] = _["tmp"] _["fws"];

    _["year"] = next_token(digit);
    if (length(_["year"]) < 4 ) { fatal(_); return 0; }
    _["tmp"] = _["tmp"] _["year"];

    _["fws"] = consume_fws();
    if (z(_["fws"])) { fatal(_); return 0; }
    _["tmp"] = _["tmp"] _["fws"];

    stack("year", _["year"]);
    return _["tmp"];
}

# obs-year = [CFWS] 2*DIGIT [CFWS]
function _consume_obs_year(_) {
    split("", _); markout(_);

    _["tmp"] = "";

    _["tmp"] = _["tmp"] optional(consume_cfws());

    _["year"] = next_token(digit);
    if (length(_["year"]) < 2) { fatal(_); return 0; }
    _["tmp"] = _["tmp"] _["year"];

    _["tmp"] = _["tmp"] optional(consume_cfws());

    stack("obs-year", _["year"]);
    return _["tmp"];
}

# year = (FWS 4*DIGIT FWS) / obs-year
function consume_year(_) {
    split("", _); markout(_);

    _["year"] = _consume_year();
    if (z(_["year"])) { fallback(_); _["year"] = _consume_obs_year(); }
    if (z(_["year"])) { fatal(_); return 0; }

    return _["year"];
}

# date = day month year
function consume_date(_) {
    split("", _); markout(_);

    _["tmp"] = "";

    _["day"] = consume_day();
    if (z(_["day"])) { fatal(_); return 0; }
    _["tmp"] = _["tmp"] _["day"];

    _["month"] = consume_month();
    if (z(_["month"])) { fatal(_); return 0; }
    _["tmp"] = _["tmp"] _["month"];

    _["year"] = consume_year();
    if (z(_["year"])) { fatal(_); return 0; }
    _["tmp"] = _["tmp"] _["year"];

    return _["tmp"];
}

# 2DIGIT
function _consume_hour(_) {
    split("", _); markout(_);

    _["hour"] = next_token(digit);
    if (length(_["hour"]) != 2) { fatal(_); return 0; }

    stack("hour", _["hour"]);
    return _["hour"];
}

# obs-hour = [CFWS] 2DIGIT [CFWS]
function _consume_obs_hour(_) {
    split("", _); markout(_);

    _["tmp"] = "";

    _["tmp"] = _["tmp"] optional(consume_cfws());

    _["hour"] = next_token(digit);
    if (length(_["hour"]) != 2) { fatal(_); return 0; }
    _["tmp"] = _["tmp"] _["hour"];

    _["tmp"] = _["tmp"] optional(consume_cfws());

    stack("obs-hour", _["hour"]);
    return _["tmp"];
}

# hour = 2DIGIT / obs-hour
function consume_hour(_) {
    split("", _); markout(_);

    _["hour"] = _consume_hour();
    if (z(_["hour"])) { fallback(_); _["hour"] = _consume_obs_hour(); }
    if (z(_["hour"])) { fatal(_); return 0; }

    return _["hour"];
}

# 2DIGIT
function _consume_minute(_) {
    split("", _); markout(_);

    _["minute"] = next_token(digit);
    if (length(_["minute"]) != 2) { fatal(_); return 0; }

    stack("minute", _["minute"]);
    return _["minute"];
}

# obs-minute = [CFWS] 2DIGIT [CFWS]
function _consume_obs_minute(_) {
    split("", _); markout(_);

    _["tmp"] = "";

    _["tmp"] = _["tmp"] optional(consume_cfws());

    _["minute"] = next_token(digit);
    if (length(_["minute"]) != 2) { fatal(_); return 0; }
    _["tmp"] = _["tmp"] _["minute"];

    _["tmp"] = _["tmp"] optional(consume_cfws());

    stack("obs-minute", _["minute"]);
    return _["tmp"];
}

# minute = 2DIGIT / obs-minute
function consume_minute(_) {
    split("", _); markout(_);

    _["minute"] = _consume_minute();
    if (z(_["minute"])) { fallback(_); _["minute"] = _consume_obs_minute(); }
    if (z(_["minute"])) { fatal(_); return 0; }

    return _["minute"];
}

# 2DIGIT
function _consume_second(_) {
    split("", _); markout(_);

    _["second"] = next_token(digit);
    if (length(_["second"]) != 2) { fatal(_); return 0; }

    stack("second", _["second"]);
    return _["second"];
}

# obs-second = [CFWS] 2DIGIT [CFWS]
function _consume_obs_second(_) {
    split("", _); markout(_);

    _["tmp"] = "";

    _["tmp"] = _["tmp"] optional(consume_cfws());

    _["minute"] = next_token(digit);
    if (length(_["minute"]) != 2) { fatal(_); return 0; }
    _["tmp"] = _["tmp"] _["minute"];

    _["tmp"] = _["tmp"] optional(consume_cfws());

    stack("obs-second", _["minute"]);
    return _["tmp"];
}

# second = 2DIGIT / obs-second
function consume_second(_) {
    split("", _); markout(_);

    _["second"] = _consume_second();
    if (z(_["second"])) { fallback(_); _["second"] = _consume_obs_second(); }
    if (z(_["second"])) { fatal(_); return 0; }

    return _["second"];
}

# FWS ( "+" / "-" ) 4DIGIT
function _consume_zone(_) {
    split("", _); markout(_);

    _["tmp"] = "";

    _["fws"] = consume_fws();
    if (z(_["fws"])) { fatal(_); return 0; }
    _["tmp"] = _["tmp"] _["fws"];

    _["sign"] = next_str("+");
    if (z(_["sign"])) { _["sign"] = next_str("-"); }
    if (z(_["sign"])) { fatal(_); return 0; }
    _["tmp"] = _["tmp"] _["sign"];

    _["digit"] = next_token(digit);
    if (length(_["digit"]) != 4) { fatal(_); return 0; }
    _["tmp"] = _["tmp"] _["digit"];

    stack("zone", _["sign"] _["digit"]);
    return _["tmp"];
}

# obs-zone = "UT" / "GMT" /  ; Universal Time
#                            ; North American UT
#                            ; offsets
#            "EST" / "EDT" / ; Eastern:  - 5/ - 4
#            "CST" / "CDT" / ; Central:  - 6/ - 5
#            "MST" / "MDT" / ; Mountain: - 7/ - 6
#            "PST" / "PDT" / ; Pacific:  - 8/ - 7
#                            ;
function _consume_obs_zone(_) {
    split("", _); markout(_);

    _["tmp"] = "";

    # https://www.rfc-editor.org/errata/eid6639
    _["tmp"] = _["tmp"] optional(consume_fws());

    _["zone"] = next_arr(arr_obs_zone);
    if (z(_["zone"])) { fatal(_); return 0; }
    _["tmp"] = _["tmp"] _["zone"];

    stack("obs-zone", _["zone"]);
    return _["tmp"];
}

# zone = (FWS ( "+" / "-" ) 4DIGIT) / obs-zone
function consume_zone(_) {
    split("", _); markout(_);

    _["tmp"] = _consume_zone();
    if (z(_["tmp"])) { fallback(_); _["tmp"] = _consume_obs_zone(); }
    if (z(_["tmp"])) { fatal(_); return 0; }

    return _["tmp"];
}

# time-of-day = hour ":" minute [ ":" second ]
function consume_time_of_day(_) {
    split("", _); markout(_);

    _["tmp"] = "";

    _["hour"] = consume_hour();
    if (z(_["hour"])) { fatal(_); return 0; }
    _["tmp"] = _["tmp"] _["hour"];

    _["colon"] = next_str(":");
    if (z(_["colon"])) { fatal(_); return 0; }
    _["tmp"] = _["tmp"] _["colon"];

    _["minute"] = consume_minute();
    if (z(_["minute"])) { fatal(_); return 0; }
    _["tmp"] = _["tmp"] _["minute"];

    _["colon"] = next_str(":");
    if (z(_["colon"])) { return _["tmp"]; }
    _["tmp"] = _["tmp"] _["colon"];

    _["second"] = consume_second();
    if (z(_["second"])) { fatal(_); return 0; }
    _["tmp"] = _["tmp"] _["second"];

    return _["tmp"];
}

# time = time-of-day zone
function consume_time(_) {
    split("", _); markout(_);

    _["tmp"] = "";

    _["tod"] = consume_time_of_day();
    if (z(_["tod"])) { fatal(_); return 0; }
    _["tmp"] = _["tmp"] _["tod"];

    _["zone"] = consume_zone();
    if (z(_["zone"])) { fatal(_); return 0 }
    _["tmp"] = _["tmp"] _["zone"];

    return _["tmp"];
}

# date-time = [ day-of-week "," ] date time [CFWS]
function consume_date_time(_) {
    split("", _); markout(_);

    _["tmp"] = "";

    _["dow"] = consume_day_of_week();
    _["comma"] = "";
    if (!z(_["dow"])) {
        _["comma"] = next_str(",");
        if (z(_["comma"])) { fatal(_); return 0; }
    }
    _["tmp"] = _["tmp"] _["dow"] _["comma"];

    _["date"] = consume_date();
    if (z(_["date"])) { fatal(_); return 0; }
    _["tmp"] = _["tmp"] _["date"];

    _["time"] = consume_time();
    if (z(_["time"])) { fatal(_); return 0; }
    _["tmp"] = _["tmp"] _["time"];

    _["tmp"] = _["tmp"] optional(consume_cfws());

    return _["tmp"];
}

# mailbox *("," mailbox)
function _consume_mailbox_list(_) {
    split("", _); markout(_);

    _["tmp"] = "";

    while (1) {
        _["mbox"] = consume_mailbox();
        if (z(_["mbox"])) { fatal(_); return 0; }
        _["tmp"] = _["tmp"] _["mbox"];

        _["comma"] = next_str(",");
        if (z(_["comma"])) { break; }
        _["tmp"] = _["tmp"] _["comma"];
    }

    return _["tmp"];
}

# obs-mbox-list = *([CFWS] ",") mailbox *("," [mailbox / CFWS])
function _consume_obs_mbox_list(_) {
    split("", _); markout(_);

    _["tmp"] = "";

    while (1) {
        _["tmp"] = _["tmp"] optional(consume_cfws());

        _["comma"] = next_str(",");
        if (z(_["comma"])) { break; }
        _["tmp"] = _["tmp"] _["comma"];
    }

    _["mbox"] = consume_mailbox();
    if (z(_["mbox"])) { fatal(_); return 0; }
    _["tmp"] = _["tmp"] _["mbox"];

    while (1) {
        _["comma"] = next_str(",");
        if (z(_["comma"])) { break; }
        _["tmp"] = _["tmp"] _["comma"];

        _["mbox"] = consume_mailbox();
        if (!z(_["mbox"])) {
            _["tmp"] = _["tmp"] _["mbox"];
        }
        else {
            _["tmp"] = _["tmp"] optional(consume_cfws());
        }
    }

    return _["tmp"];
}

# mailbox-list = (mailbox *("," mailbox)) / obs-mbox-list
function consume_mailbox_list(_) {
    split("", _); markout(_);

    _["tmp"] = _consume_mailbox_list();
    if (z(_["tmp"])) { fallback(_); _["tmp"] = _consume_obs_mbox_list(); }
    if (z(_["tmp"])) { fatal(_); return 0; }

    return _["tmp"];
}

# atom = [CFWS] 1*atext [CFWS]
function consume_atom(_) {
    split("", _); markout(_);

    _["tmp"] = "";

    _["tmp"] = _["tmp"] optional(consume_cfws());

    _["atom"] = next_token(atext);
    if (_["atom"] == "") { fatal(_); return 0; }
    _["tmp"] = _["tmp"] _["atom"];

    _["tmp"] = _["tmp"] optional(consume_cfws());

    return _["tmp"];
}

# qcontent = qtext / quoted-pair
function consume_qcontent(_) {
    split("", _); markout(_);

    _["tmp"] = next_token(qtext);
    if (_["tmp"] == "") { fallback(_); _["tmp"] = consume_quoted_pair(); }
    if (z(_["tmp"])) { fatal(_); return 0; }

    return _["tmp"];
}

# quoted-string = [CFWS]
#                 DQUOTE *([FWS] qcontent) [FWS] DQUOTE
#                 [CFWS]
function consume_quoted_string(_) {
    split("", _); markout(_);

    _["tmp"] = ""

    _["tmp"] = _["tmp"] optional(consume_cfws());

    _["DQUOTE"] = next_str(QQ);
    if (z(_["DQUOTE"])) { fatal(_); return 0; }
    _["tmp"] = _["tmp"] _["DQUOTE"];

    while (1) {
        _["tmp"] = _["tmp"] optional(consume_fws());

        _["qcontent"] = consume_qcontent();
        if (z(_["qcontent"])) { break; }
        _["tmp"] = _["tmp"] _["qcontent"];
    }

    _["tmp"] = _["tmp"] optional(consume_fws());

    _["DQUOTE"] = next_str(QQ);
    if (z(_["DQUOTE"])) { fatal(_); return 0; }
    _["tmp"] = _["tmp"] _["DQUOTE"];

    _["tmp"] = _["tmp"] optional(consume_cfws());

    return _["tmp"];
}

# word = atom / quoted-string
function consume_word(_) {
    split("", _); markout(_);

    _["tmp"] = consume_atom();
    if (z(_["tmp"])) { fallback(_); _["tmp"] = consume_quoted_string(); }
    if (z(_["tmp"])) { fatal(_); return 0; }

    return _["tmp"];
}

# 1*word
function _consume_phrase(_) {
    split("", _); markout(_);

    _["tmp"] = "";

    while (1) {
        _["word"] = consume_word();
        if (z(_["word"])) { break; }
        _["tmp"] = _["tmp"] _["word"];
    }

    if (!_["tmp"]) { fatal(_); return 0; }

    stack("phrase", _["tmp"]);
    return _["tmp"];
}

# obs-phrase = word *(word / "." / CFWS)
function _consume_obs_phrase(_) {
    split("", _); markout(_);

    _["tmp"] = consume_word();
    if (z(_["tmp"])) { fatal(_); return 0; }

    while (1) {
        _["rest"] = consume_word();
        if (!z(_["rest"])) {
            _["tmp"] = _["tmp"] _["rest"];
            continue;
        }

        _["rest"] = next_str(".");
        if (!z(_["rest"])) {
            _["tmp"] = _["tmp"] _["rest"];
            continue;
        }

        _["rest"] = consume_cfws();
        if (!z(_["rest"])) {
            _["tmp"] = _["tmp"] _["rest"];
            continue;
        }

        break;
    }

    stack("obs-phrase", _["tmp"]);
    return _["tmp"];
}

# phrase = 1*word / obs-phrase
function consume_phrase(_) {
    split("", _); markout(_);

    _["tmp"] = _consume_phrase();
    if (z(_["tmp"])) { fallback(_); _["tmp"] = _consume_obs_phrase(); }
    if (z(_["tmp"])) { fatal(_); return 0; }

    return _["tmp"];
}

# display-name = phrase
function consume_display_name(_) {
    split("", _); markout(_);

    _["tmp"] = consume_phrase();
    if (z(_["tmp"])) { fatal(_); return 0; }

    return _["tmp"];
}

# [CFWS] "<" addr-spec ">" [CFWS]
function _consume_angle_addr(_) {
    split("", _); markout(_);

    _["tmp"] = "";

    _["tmp"] = _["tmp"] optional(consume_cfws());

    _["op_angle"] = next_str("<");
    if (z(_["op_angle"])) { fatal(_); return 0; }
    _["tmp"] = _["tmp"] _["op_angle"];

    _["addr_spec"] = consume_addr_spec();
    if (z(_["addr_spec"])) { fatal(_); return 0; }
    _["tmp"] = _["tmp"] _["addr_spec"];

    _["cl_angle"] = next_str(">");
    if (z(_["cl_angle"])) { fatal(_); return 0; }
    _["tmp"] = _["tmp"] _["cl_angle"];

    _["tmp"] = _["tmp"] optional(consume_cfws());

    return _["tmp"];
}

# obs-domain-list = *(CFWS / ",") "@" domain
#                   *("," [CFWS] ["@" domain])
function consume_obs_domain_list(_) {
    split("", _); markout(_);

    _["tmp"] = "";

    while (1) {
        _["tmp"] = _["tmp"] optional(consume_cfws());

        _["comma"] = next_str(",");
        if (z(_["comma"])) { break; }
        _["tmp"] = _["tmp"] _["comma"];
    }

    _["at"] = next_str("@");
    if (!z(_["at"])) { fatal(_); return 0; }
    _["tmp"] = _["tmp"] _["at"];

    _["domain"] = consume_domain();
    if (!z(_["domain"])) { fatal(_); return 0; }
    _["tmp"] = _["tmp"] _["domain"];

    while (1) {
        _["comma"] = next_str(",");
        if (z(_["comma"])) { break; }
        _["tmp"] = _["tmp"] _["comma"];

        _["tmp"] = _["tmp"] optional(consume_cfws());

        _["at"] = next_str("@");
        if (z(_["at"])) { continue; }
        _["tmp"] = _["tmp"] _["at"];

        _["domain"] = consume_domain();
        if (z(_["domain"])) { fatal(_); return 0; }
        _["tmp"] = _["tmp"] _["domain"];
    }

    return _["tmp"];
}

# obs-route = obs-domain-list ":"
function consume_obs_route(_) {
    split("", _); markout(_);

    _["tmp"] = "";

    _["obs_domain_list"] = consume_obs_domain_list();
    if (z(_["obs_domain_list"])) { fatal(_); return 0; }
    _["tmp"] = _["tmp"] _["obs_domain_list"];

    _["colon"] = next_str(":");
    if (z(_["colon"])) { fatal(_); return 0; }
    _["tmp"] = _["tmp"] _["colon"];

    return _["tmp"];
}

# obs-angle-addr = [CFWS] "<" obs-route addr-spec ">" [CFWS]
function _consume_obs_angle_addr(_) {
    split("", _); markout(_);

    _["tmp"] = "";

    _["tmp"] = _["tmp"] optional(consume_cfws());

    _["op_angle"] = next_str("<");
    if (z(_["op_angle"])) { fatal(_); return 0; }
    _["tmp"] = _["tmp"] _["op_angle"];

    _["obs_route"] = consume_obs_route();
    if (z(_["obs_route"])) { fatal(_); return 0; }
    _["tmp"] = _["tmp"] _["obs_route"];

    _["addr_spec"] = consume_addr_spec();
    if (z(_["addr_spec"])) { fatal(_); return 0; }
    _["tmp"] = _["tmp"] _["addr_spec"];

    _["cl_angle"] = next_str(">");
    if (z(_["cl_angle"])) { fatal(_); return 0; }
    _["tmp"] = _["tmp"] _["cl_angle"];

    _["tmp"] = _["tmp"] optional(consume_cfws());

    stack("addr-spec", _["addr_spec"]);
    return _["tmp"];
}

# angle-addr = [CFWS] "<" addr-spec ">" [CFWS] /
#              obs-angle-addr
function consume_angle_addr(_) {
    split("", _); markout(_);

    _["tmp"] = _consume_angle_addr();
    if (z(_["tmp"])) { fallback(_); _["tmp"] = _consume_obs_angle_addr(); }
    if (z(_["tmp"])) { fatal(_); return 0; }

    return _["tmp"];
}

# name-addr = [display-name] angle-addr
function consume_name_addr(_) {
    split("", _); markout(_);

    _["tmp"] = "";

    _["tmp"] = _["tmp"] optional(consume_display_name());

    _["angle_addr"] = consume_angle_addr();
    if(z(_["angle_addr"])) { fatal(_); return 0; }
    _["tmp"] = _["tmp"] _["angle_addr"];

    return _["tmp"];
}

# dot-atom-text = 1*atext *("." 1*atext)
function consume_dot_atom_text(_) {
    split("", _); markout(_);

    _["tmp"] = next_token(atext);
    if (_["tmp"] == "") { fatal(_); return 0; }

    while (1) {
        _["dot"] = next_str(".");
        if (z(_["dot"])) { break; }
        _["tmp"] = _["tmp"] _["dot"];

        _["atext"] = next_token(atext);
        if (_["atext"] == "") { fatal(_); return 0; }
        _["tmp"] = _["tmp"] _["atext"];
    }

    return _["tmp"];
}

# dot-atom = [CFWS] dot-atom-text [CFWS]
function consume_dot_atom(_) {
    split("", _); markout(_);

    _["tmp"] = "";

    _["tmp"] = _["tmp"] optional(consume_cfws());

    _["dot_atom_text"] = consume_dot_atom_text();
    if (z(_["dot_atom_text"])) { fatal(_); return 0; }
    _["tmp"] = _["tmp"] _["dot_atom_text"];

    _["tmp"] = _["tmp"] optional(consume_cfws());

    return _["tmp"];
}

# obs-local-part = word *("." word)
function consume_obs_local_part(_) {
    split("", _); markout(_);

    _["tmp"] = consume_word();
    if (z(_["tmp"])) { fatal(_); return 0; }

    while (1) {
        _["dot"] = next_str(".");
        if (z(_["dot"])) { break; }
        _["tmp"] = _["tmp"] _["dot"];

        _["word"] = consume_word();
        if (z(_["word"])) { fatal(_); return 0; }
        _["tmp"] = _["tmp"] _["word"];
    }

    return _["tmp"];
}

# local-part = dot-atom / quoted-string / obs-local-part
function consume_local_part(_) {
    split("", _); markout(_);

    _["tmp"] = consume_dot_atom();
    if (!z(_["tmp"])) { return _["tmp"]; }

    fallback(_);

    _["tmp"] = consume_quoted_string();
    if (!z(_["tmp"])) { return _["tmp"]; }

    fallback(_);

    _["tmp"] = consume_obs_local_part();
    if (!z(_["tmp"])) { return _["tmp"]; }

    fatal(_);
    return 0;
}

# dtext
function _consume_dtext(_) {
    split("", _); markout(_);

    _["tmp"] = next_token(dtext);
    if (_["tmp"] == "") { fatal(_); return 0; }

    return _["tmp"];
}

# obs-dtext = obs-NO-WS-CTL / quoted-pair
function _consume_obs_dtext(_) {
    split("", _); markout(_);

    _["tmp"] = next_arr(arr_obs_no_ws_ctl);
    if (z(_["tmp"])) { fallback(_); _["tmp"] = consume_quoted_pair(); }
    if (z(_["tmp"])) { fatal(_); return 0; }

    return _["tmp"];
}

# dtext = %d33-90 /  ; Printable US-ASCII
#         %d94-126 / ;  characters not including
#         obs-dtext  ;  "[", "]", or "\"
function consume_dtext(_) {
    split("", _); markout(_);

    _["tmp"] = _consume_dtext();
    if (z(_["tmp"])) { fallback(_); _["tmp"] = _consume_obs_dtext(); }
    if (z(_["tmp"])) { fatal(_); return 0; }

    return _["tmp"];
}

# domain-literal = [CFWS] "[" *([FWS] dtext) [FWS] "]" [CFWS]
function consume_domain_literal(_) {
    split("", _); markout(_);

    _["tmp"] = "";

    _["tmp"] = _["tmp"] optional(consume_cfws());

    _["op_bracket"] = next_str("[");
    if (z(_["op_bracket"])) { fatal(_); return 0; }
    _["tmp"] = _["tmp"] _["op_bracket"];

    while (1) {
        _["tmp"] = _["tmp"] optional(consume_fws());

        _["dtext"] = consume_dtext();
        if (z(_["dtext"])) { break; }
        _["tmp"] = _["tmp"] _["dtext"];
    }

    _["tmp"] = _["tmp"] optional(consume_fws());

    _["cl_bracket"] = next_str("]");
    if (z(_["cl_bracket"])) { fatal(_); return 0; }
    _["tmp"] = _["tmp"] _["cl_bracket"];

    _["tmp"] = _["tmp"] optional(consume_cfws());

    return _["tmp"];
}

# obs-domain = atom *("." atom)
function consume_obs_domain(_) {
    split("", _); markout(_);

    _["tmp"] = consume_atom();
    if (z(_["tmp"])) { fatal(_); return 0; }

    while (1) {
        _["dot"] = next_str(".");
        if (z(_["dot"])) { break; }
        _["tmp"] = _["tmp"] _["dot"];

        _["atom"] = consume_atom();
        if (z(_["atom"])) { fatal(_); return 0; }
        _["tmp"] = _["tmp"] _["atom"];
    }

    return _["tmp"];
}

# domain = dot-atom / domain-literal / obs-domain
function consume_domain(_) {
    split("", _); markout(_);

    _["tmp"] = consume_dot_atom();
    if (!z(_["tmp"])) { return _["tmp"]; }

    fallback(_);

    _["tmp"] = consume_domain_literal();
    if (!z(_["tmp"])) { return _["tmp"]; }

    fallback(_);

    _["tmp"] = consume_obs_domain();
    if (!z(_["tmp"])) { return _["tmp"]; }

    fatal(_);
    return 0;
}

# addr-spec = local-part "@" domain
function consume_addr_spec(_) {
    split("", _); markout(_);

    _["tmp"] = "";

    _["local_part"] = consume_local_part();
    if (z(_["local_part"])) { fatal(_); return 0; }
    _["tmp"] = _["tmp"] _["local_part"];

    _["at"] = next_str("@");
    if (z(_["at"])) { fatal(_); return 0; }
    _["tmp"] = _["tmp"] _["at"];

    _["domain"] = consume_domain();
    if (z(_["domain"])) { fatal(_); return 0; }
    _["tmp"] = _["tmp"] _["domain"];

    stack("addr-spec", _["tmp"]);
    return _["tmp"];
}

# mailbox = name-addr / addr-spec
function consume_mailbox(_) {
    split("", _); markout(_, "mailbox");

    _["tmp"] = consume_name_addr();
    if (z(_["tmp"])) { fallback(_); _["tmp"] = consume_addr_spec(); }
    if (z(_["tmp"])) { fatal(_); return 0; }

    return _["tmp"];
}

# obs-group-list = 1*([CFWS] ",") [CFWS]
function consume_obs_group_list(_) {
    split("", _); markout(_);

    _["tmp"] = "";

    _["seen"] = 0;
    while (1) {
        _["tmp"] = _["tmp"] optional(consume_cfws());

        _["comma"] = next_str(",");
        if (z(_["comma"])) { break; }
        _["tmp"] = _["tmp"] _["comma"];

        _["seen"]++;
    }

    if (!_["seen"]) { fatal(_); return 0; }

    _["tmp"] = _["tmp"] optional(consume_cfws());

    return _["tmp"];
}

# group-list = mailbox-list / CFWS / obs-group-list
function consume_group_list(_) {
    split("", _); markout(_, "group-list");

    _["tmp"] = consume_mailbox_list();
    if (!z(_["tmp"])) { return _["tmp"]; }

    fallback(_)

    _["tmp"] = consume_cfws();
    if (!z(_["tmp"])) { return _["tmp"]; }

    fallback(_)

    _["tmp"] = consume_obs_group_list();
    if (!z(_["tmp"])) { return _["tmp"]; }

    fatal(_);
    return 0;
}

# group = display-name ":" [group-list] ";" [CFWS]
function consume_group(_) {
    split("", _); markout(_, "group");

    _["tmp"] = "";

    _["display_name"] = consume_display_name();
    if (z(_["display_name"])) { fatal(_); return 0; }
    _["tmp"] = _["tmp"] _["display_name"];

    _["colon"] = next_str(":");
    if (z(_["colon"])) { fatal(_); return 0; }
    _["tmp"] = _["tmp"] _["colon"];

    _["tmp"] = _["tmp"] optional(consume_group_list());

    _["semicolon"] = next_str(";");
    if (z(_["semicolon"])) { fatal(_); return 0; }
    _["tmp"] = _["tmp"] _["semicolon"];

    _["tmp"] = _["tmp"] optional(consume_cfws());

    return _["tmp"];
}

# address = mailbox / group
function consume_address(_) {
    split("", _); markout(_);

    _["tmp"] = consume_mailbox();
    if (z(_["tmp"])) { fallback(_); _["tmp"] = consume_group(); }
    if (z(_["tmp"])) { fatal(_); return 0; }

    return _["tmp"];
}

# address *("," address)
function _consume_address_list(_) {
    split("", _); markout(_);

    _["tmp"] = consume_address();
    if (z(_["tmp"])) { fatal(_); return 0; }

    while (1) {
        _["comma"] = next_str(",");
        if (z(_["comma"])) { break; }
        _["tmp"] = _["tmp"] _["comma"];

        _["addr"] = consume_address();
        if (z(_["addr"])) { fatal(_); return 0; }
        _["tmp"] = _["tmp"] _["addr"];
    }

    return _["tmp"];
}

# obs-addr-list = *([CFWS] ",") address *("," [address / CFWS])
function _consume_obs_addr_list(_) {
    split("", _); markout(_);

    _["tmp"] = "";

    while (1) {
        _["tmp"] = _["tmp"] optional(consume_cfws());

        _["comma"] = next_str(",");
        if (z(_["comma"])) { break; }
        _["tmp"] = _["tmp"] _["comma"];
    }

    _["addr"] = consume_address();
    if (z(_["addr"])) { fatal(_); return 0; }
    _["tmp"] = _["tmp"] _["addr"];

    while (1) {
        _["comma"] = next_str(",");
        if (!_["comma"]) { break; }
        _["tmp"] = _["tmp"] _["comma"];

        _["addr"] = consume_address();
        if (z(_["addr"])) {
            _["tmp"] = _["tmp"] optional(consume_cfws());
            continue;
        }
        _["tmp"] = _["tmp"] _["addr"];
    }

    return _["tmp"];
}

# address-list = (address *("," address)) / obs-addr-list
function consume_address_list(_) {
    split("", _); markout(_);

    _["tmp"] = _consume_address_list();
    if (z(_["tmp"])) { fallback(_); _["tmp"] = _consume_obs_addr_list(); }
    if (z(_["tmp"])) { fatal(_); return 0; }

    return _["tmp"];
}

# [address-list / CFWS]
function consume_bcc(_) {
    split("", _); markout(_);

    _["tmp"] = consume_address_list();
    if (z(_["tmp"])) { fallback(_); _["tmp"] = consume_cfws(); }
    if (z(_["tmp"])) { fatal(_); return 0; }

    return _["tmp"];
}

# obs-id-left = local-part
function _consume_obs_id_left(_) {
    split("", _); markout(_);

    _["tmp"] = consume_local_part();
    if (z(_["tmp"])) { fatal(_); return 0; }

    return _["tmp"];
}

# id-left = dot-atom-text / obs-id-left
function consume_id_left(_) {
    split("", _); markout(_);

    _["tmp"] = consume_dot_atom_text();
    if (z(_["tmp"])) { fallback(_); _["tmp"] = _consume_obs_id_left(); }
    if (z(_["tmp"])) { fatal(_); return 0; }

    return _["tmp"];
}

# no-fold-literal = "[" *dtext "]"
function consume_no_fold_literal(_) {
    split("", _); markout(_);

    _["tmp"] = "";

    _["op_bracket"] = next_str("[");
    if (z(_["op_bracket"])) { fatal(_); return 0; }
    _["tmp"] = _["tmp"] _["op_bracket"];

    _["tmp"] = _["tmp"] next_token(dtext);

    _["cl_bracket"] = next_str("]");
    if (z(_["cl_bracket"])) { fatal(_); return 0; }
    _["tmp"] = _["tmp"] _["cl_bracket"];

    return _["tmp"];
}

# obs-id-right = domain
function _consume_obs_id_right(_) {
    split("", _); markout(_);

    _["tmp"] = consume_domain();
    if (z(_["tmp"])) { fatal(_); return 0; }

    return _["tmp"];
}

# id-right = dot-atom-text / no-fold-literal / obs-id-right
function consume_id_right(_) {
    split("", _); markout(_);

    _["tmp"] = consume_dot_atom_text();
    if (z(_["tmp"])) { fallback(_); _["tmp"] = consume_no_fold_literal(); }
    if (z(_["tmp"])) { fallback(_); _["tmp"] = _consume_obs_id_right(); }
    if (z(_["tmp"])) { fatal(_); return 0; }

    return _["tmp"];
}

# msg-id = [CFWS] "<" id-left "@" id-right ">" [CFWS]
function consume_msg_id(_) {
    split("", _); markout(_);

    _["tmp"] = "";

    _["tmp"] = _["tmp"] optional(consume_cfws());

    _["op_angle"] = next_str("<");
    if (z(_["op_angle"])) { fatal(_); return 0; }
    _["tmp"] = _["tmp"] _["op_angle"];

    _["id_left"] = consume_id_left();
    if (z(_["id_left"])) { fatal(_); return 0; }
    _["tmp"] = _["tmp"] _["id_left"];

    _["at"] = next_str("@");
    if (z(_["at"])) { fatal(_); return 0; }
    _["tmp"] = _["tmp"] _["at"];

    _["id_right"] = consume_id_right();
    if (z(_["id_right"])) { fatal(_); return 0; }
    _["tmp"] = _["tmp"] _["id_right"];

    _["cl_angle"] = next_str(">");
    if (z(_["cl_angle"])) { fatal(_); return 0; }
    _["tmp"] = _["tmp"] _["cl_angle"];

    _["tmp"] = _["tmp"] optional(consume_cfws());

    _["msg_id"] = _["id_left"] _["at"] _["id_right"];

    stack("msg-id", _["msg_id"]);
    return _["tmp"];
}

# references = "References:" 1*msg-id CRLF
function consume_references(_) {
    split("", _); markout(_);

    _["tmp"] = "";

    _["seen"] = 0;
    while (1) {
        _["msg_id"] = consume_msg_id();
        if (z(_["msg_id"])) { break; }
        _["tmp"] = _["tmp"] _["msg_id"];

        _["seen"]++;
    }

    if (!_["seen"]) { fatal(_); return 0; }

    return _["tmp"];
}

# path = angle-addr / ([CFWS] "<" [CFWS] ">" [CFWS])
function consume_path(_) {
    split("", _); markout(_);

    _["angle_addr"] = consume_angle_addr();
    if (!z(_["angle_addr"])) { return _["angle_addr"]; }

    fallback(_);

    _["tmp"] = "";

    _["tmp"] = _["tmp"] optional(consume_cfws());

    _["op_angle"] = next_str("<");
    if (z(_["op_angle"])) { fatal(_); return 0; }
    _["tmp"] = _["tmp"] _["op_angle"];

    _["tmp"] = _["tmp"] optional(consume_cfws());

    _["cl_angle"] = next_str(">");
    if (z(_["cl_angle"])) { fatal(_); return 0; }
    _["tmp"] = _["tmp"] _["cl_angle"];

    _["tmp"] = _["tmp"] optional(consume_cfws());

    return _["tmp"];
}

# received-token = word / angle-addr / addr-spec / domain
function consume_received_token(_) {
    split("", _); markout(_);

    _["angle_addr"] = consume_angle_addr();
    if (!z(_["angle_addr"])) { return _["angle_addr"]; }

    fallback(_);

    _["addr_spec"] = consume_addr_spec();
    if (!z(_["addr_spec"])) { return _["addr_spec"]; }

    fallback(_);

    _["domain"] = consume_domain();
    if (!z(_["domain"])) {
        # XXX: `domain` includes part of `word`
        # This code mistakes dot-less domains such as `localhost` for a word
        # but it is a matter of RFC 5321, not RFC 5322.
        if (index(_["domain"], ".") > 0) {
            stack("domain", _["domain"]);
            return _["domain"];
        }
    }

    fallback(_);

    _["word"] = consume_word();
    if (!z(_["word"])) {
        stack("word", _["word"]);
        return _["word"];
    }

    fatal(_);
    return 0;
}

# Errata 3979: https://www.rfc-editor.org/errata/eid3979
# received = "Received:" [1*received-token / CFWS]
#              ";" date-time CRLF
function consume_received(_) {
    split("", _); markout(_);

    _["tmp"] = "";

    _["seen"] = 0;
    while (1) {
        _["received_token"] = consume_received_token();
        if (z(_["received_token"])) { break; }
        _["tmp"] = _["tmp"] _["received_token"];
        _["seen"]++;
    }

    if (!_["seen"]) {
        _["tmp"] = _["tmp"] optional(consume_cfws());
    }

    _["semicolon"] = next_str(";");
    if (z(_["semicolon"])) { fatal(_); return 0; }
    _["tmp"] = _["tmp"] _["semicolon"];

    _["date_time"] = consume_date_time();
    if (z(_["date_time"])) { fatal(_); return 0; }
    _["tmp"] = _["tmp"] _["date_time"];

    return _["tmp"];
}

# phrase *("," phrase)
function consume_keywords(_) {
    split("", _); markout(_);

    _["tmp"] = "";

    while (1) {
        _["phrase"] = consume_phrase();
        if (z(_["phrase"])) { fatal(_); return 0; }
        _["tmp"] = _["tmp"] _["phrase"];

        _["comma"] = next_str(",");
        if (z(_["comma"])) { break; }
        _["tmp"] = _["tmp"] _["comma"];
    }

    return _["tmp"];
}

function consume(nr, _) {
    _["success"] = 0;
    gbuf = buf;

    if (field == "Date") { _["success"] = consume_date_time(); }
    else if (field == "From") { _["success"] = consume_mailbox_list(); }
    else if (field == "Sender") { _["success"] = consume_mailbox(); }
    else if (field == "Reply-To") { _["success"] = consume_address_list(); }
    else if (field == "To") { _["success"] = consume_address_list(); }
    else if (field == "Cc") { _["success"] = consume_address_list(); }
    else if (field == "Bcc") { _["success"] = consume_bcc(); }
    else if (field == "Message-ID") { _["success"] = consume_msg_id(); }
    else if (field == "References") { _["success"] = consume_references(); }
    else if (field == "Recent-Date") { _["success"] = consume_date_time(); }
    else if (field == "Recent-From") { _["success"] = consume_mailbox_list(); }
    else if (field == "Recent-Sender") { _["success"] = consume_mailbox(); }
    else if (field == "Recent-To") { _["success"] = consume_address_list(); }
    else if (field == "Recent-Cc") { _["success"] = consume_address_list(); }
    else if (field == "Recent-Bcc") { _["success"] = consume_bcc(); }
    else if (field == "Recent-Message-ID") { _["success"] = consume_msg_id(); }
    else if (field == "Return-Path") { _["success"] = consume_path(); }
    else if (field == "Received") { _["success"] = consume_received(); }
    else if (field == "Keywords") { _["success"] = consume_keywords(); }
    else { _["success"] = 1; } # unknown header

    if (!_["success"]) {
        diag("ERROR: line:" nr SP ebuf);
        error = 1;
    }

    flush();

    return 1;
}

function within(str, chars, _) {
    for (_["i"] = 0; _["i"]++ < length(str);) {
        if (index(chars, substr(str, _["i"], 1)) < 1) {
            # `str` contains characters that not in `chars`
            return 0;
        }
    }

    return 1;
}

function main(nr, str, _) {
    if (str ~ /^[\t ]/ && field != "") {
        # concat folded lines
        buf = buf CR LF str;
        return 1;
    }

    # field-name = 1*ftext
    _["idx"] = index(str, ":");
    if (_["idx"] > 1) {
        if (field != "") {
            consume(header_nr);
        }

        field = substr(str, 1, _["idx"] - 1);
        if (within(field, ftext)) {
            stack("field-name", field);
            flush();
            buf = substr(str, _["idx"] + 1);
            header_nr = nr;
            return 1;
        }
    }

    if (!_["idx"]) { _["idx"] = length(str); }
    msg = "ERROR: line:" nr " pos:0 [(Malformed)]: " \
        emphasize(substr(str, 0, _["idx"])) \
        substr(str, _["idx"] + 1);
    diag(msg);

    field = "";
    buf = "";
    error = 1;
    return 0;
}

/\r$/ {
    # Remove trailing CR if exists
    $0 = substr($0, 1, length($0) - 1);
}
NR == 1 && /^From / {
    # Skip MBOX separater line, see RFC 4155.
    next;
}
/^$/ {
    # End of header
    exit;
}
{ main(NR, $0); }
END {
    consume(header_nr);
    print SP;  # dismiss last backslash produced by `stack()`
    exit error;
}
