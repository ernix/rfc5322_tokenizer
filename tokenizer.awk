#!/usr/bin/awk

BEGIN {
    Q = "\047";
    QQ = "\042";
    BS = "\134";
    CR = "\r";
    LF = "\n";
    SP = "\040";

    split("!" QQ \
        "#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[" \
        BS "]^_`abcdefghijklmnopqrstuvwxyz{|}~", arr_vchar, "");

    ftext = "!" QQ "#$%&'()*+,-./0123456789" \
         ";<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[" BS \
         "]^_`abcdefghijklmnopqrstuvwxyz{|}~";


    # US-ASCII control characters that do not include the carriage return,
    # line feed, and white space characters
    obs_no_ws_ctl = "\001\002\003\004\005\006\007\010" \
        "\013\014" \
        "\016\017" \
        "\020\021\022\023\024\025\026\027" \
        "\030\031\032\033\034\035\036\037";

    split(obs_no_ws_ctl, arr_obs_no_ws_ctl, "");

    ctext = "!" QQ "#$%&'" \
        "*+,-./0123456789:;<=>? @ABCDEFGHIJKLMNOPQRSTUVWXYZ[" \
        "]^_`abcdefghijklmnopqrstuvwxyz{|}~" \
        obs_no_ws_ctl;

    atext = "ABCDEFGHIJKLMNOPQRSTUVWXYZ" \
        "abcdefghijklmnopqrstuvwxyz" \
        "0123456789" \
        "!#$%&'*+-/=?^_`{|}~";

    qtext = "!#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[]" \
        "^_`abcdefghijklmnopqrstuvwxyz{|}~";

    dtext = "!" QQ "#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ" \
        "^_`abcdefghijklmnopqrstuvwxyz{|}~";

    split("Mon Tue Wed Thu Fri Sat Sun", arr_week, SP);
    split("Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec", arr_month, SP);
    split("\t| ", arr_wsp, "|");
    split("0123456789", arr_digit, "");
    split("UT GMT EST EDT CST CDT MST MDT PST PDT", arr_obs_zone, SP);

    field = "";
    buf = "";
    obuf = "";
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

function next_token(chars, _) {
    _["len"] = length(buf);
    for (_["pos"] = 0; _["pos"]++ < _["len"];) {
        if (index(chars, substr(buf, _["pos"], 1)) < 1) {
            _["tmp"] = substr(buf, 0, _["pos"] - 1);
            buf = substr(buf, _["pos"], _["len"]);
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
    _["len"] = length(buf);
    _["str_len"] = length(str);
    if (_["len"] >= _["str_len"] && _["str_len"] > 0) {
        _["pre"] = substr(buf, 0, _["str_len"]);
        if (_["pre"] == str) {
            buf = substr(buf, _["str_len"] + 1, _["len"]);
            return _["pre"];
        }
    }

    return 0;
}

function next_arr(array, _i, _) {
    _["buf"] = buf;
    _["obuf"] = obuf;

    for (_i in array) {
        _["tmp"] = next_str(array[_i]);
        if (!z(_["tmp"])) {
            return _["tmp"];
        }
    }

    buf = _["buf"];
    obuf = _["obuf"];
    return 0;
}

# [*WSP CRLF] 1*WSP
function _consume_fws(_) {
    _["buf"] = buf;
    _["obuf"] = obuf;

    _["wsp1"] = next_token_arr(arr_wsp);
    _["crlf"] = next_str(CR LF);
    _["wsp2"] = next_token_arr(arr_wsp);

    # wsp2 can be empty when crlf is not exists
    if (_["wsp1"] == "" && _["wsp2"] == "") {
        buf = _["buf"];
        obuf = _["obuf"];
        return 0;
    }

    if (z(_["crlf"])) { _["crlf"] = ""; }

    _["tmp"] = _["wsp1"] _["crlf"] _["wsp2"];
    return _["tmp"];
}

# obs-FWS = 1*WSP *(CRLF 1*WSP)
function _consume_obs_fws(_) {
    _["buf"] = buf;
    _["obuf"] = obuf;

    _["tmp"] = next_token_arr(arr_wsp);
    if (_["tmp"] == "") {
        buf = _["buf"];
        obuf = _["obuf"];
        return 0;
    }

    while (1) {
        _["crlf"] = next_str(CR LF);
        if (z(_["crlf"])) { break; }

        _["tmp"] = _["tmp"] _["crlf"];
        _["wsp2"] = next_token_arr(arr_wsp);
        if (_["wsp2"] == "") {
            buf = _["buf"];
            obuf = _["obuf"];
            return 0
        }
        _["tmp"] = _["tmp"] _["wsp2"];
    }

    return _["tmp"];
}

# FWS = ([*WSP CRLF] 1*WSP) / obs-FWS
function consume_fws(_) {
    _["buf"] = buf;
    _["obuf"] = obuf;

    _["fws"] = _consume_fws();
    if (z(_["fws"])) {
        buf = _["buf"];
        obuf = _["obuf"];
        _["fws"] = _consume_obs_fws();
    }

    if (z(_["fws"])) {
        _["fws"] = "";
    }

    return _["fws"];
}

# "\" (VCHAR / WSP)
function _consume_quoted_pair(_) {
    _["buf"] = buf;
    _["obuf"] = obuf;

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

    buf = _["buf"];
    obuf = _["obuf"];
    return 0;
}

# obs-qp = "\" (%d0 / obs-NO-WS-CTL / LF / CR)
function _consume_obs_qp(_) {
    _["buf"] = buf;
    _["obuf"] = obuf;

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

    buf = _["buf"];
    obuf = _["obuf"];
    return 0;
}

# quoted-pair = ("\" (VCHAR / WSP)) / obs-qp
function consume_quoted_pair(_) {
    _["buf"] = buf;
    _["obuf"] = obuf;

    _["tmp"] = _consume_quoted_pair();
    if (z(_["tmp"])) {
        buf = _["buf"];
        obuf = _["obuf"];
        _["tmp"] = _consume_obs_qp();
    }

    if (z(_["tmp"])) {
        buf = _["buf"];
        obuf = _["obuf"];
        return 0;
    }

    return _["tmp"];
}

# ccontent = ctext / quoted-pair / comment
function consume_ccontent(_) {
    _["buf"] = buf;
    _["obuf"] = obuf;

    _["tmp"] = next_token(ctext);
    if (_["tmp"] != "") { return _["tmp"]; }

    _["tmp"] = consume_quoted_pair();
    if (!z(_["tmp"])) { return _["tmp"]; }

    _["tmp"] = consume_comment();
    if (!z(_["tmp"])) { return _["tmp"]; }

    buf = _["buf"];
    obuf = _["obuf"];
    return 0;
}

# comment = "(" *([FWS] ccontent) [FWS] ")"
function consume_comment(_) {
    _["buf"] = buf;
    _["obuf"] = obuf;

    _["tmp"] = "";

    _["op_brace"] = next_str("(");
    if (z(_["op_brace"])) {
        buf = _["buf"];
        obuf = _["obuf"];
        return 0;
    }
    _["tmp"] = _["tmp"] _["op_brace"];

    while (1) {
        _["fws"] = consume_fws();
        if (!z(_["fws"])) {
            _["tmp"] = _["tmp"] _["fws"];
        }

        _["ccontent"] = consume_ccontent();
        if (z(_["ccontent"])) { break; }
        _["tmp"] = _["tmp"] _["ccontent"];
    }

    _["cl_brace"] = next_str(")");
    if (z(_["cl_brace"])) {
        buf = _["buf"];
        obuf = _["obuf"];
        return 0;
    }

    return _["tmp"] _["cl_brace"];
}

# CFWS = (1*([FWS] comment) [FWS]) / FWS
function consume_cfws(_) {
    _["tmp"] = "";
    _["comment_found"] = 0;

    while (1) {
        _["fws"] = consume_fws();
        if (!z(_["fws"])) {
            _["tmp"] = _["tmp"] _["fws"];
        }

        _["comment"] = consume_comment();
        if (!z(_["comment"])) {
            stack("comment", _["comment"]);
            # Skip comments, loved by only spammers
            _["comment_found"]++;
        }
        else {
            break;
        }
    }

    _["fws"] = consume_fws();
    if (!z(_["fws"])) {
        _["tmp"] = _["tmp"] _["fws"];
    }

    if (_["tmp"] || _["comment_found"]) {
        return _["tmp"];
    }
    else {
        return 0;
    }
}

# [FWS] day-name
function _consume_day_of_week(_) {
    _["buf"] = buf;
    _["obuf"] = obuf;

    _["fws"] = consume_fws();
    if (z(_["fws"])) {
        _["fws"] = "";
    }

    _["day_name"] = next_arr(arr_week);
    if (z(_["day_name"])) {
        buf = _["buf"];
        obuf = _["obuf"];
        return 0;
    }

    stack("day-name", _["day_name"]);
    return _["fws"] _["day_name"];
}

# obs-day-of-week = [CFWS] day-name [CFWS]
function _consume_obs_day_of_week(_) {
    _["buf"] = buf;
    _["obuf"] = obuf;

    _["cfws1"] = consume_cfws();
    if (z(_["cfws1"])) {
        _["cfws1"] = "";
    }

    _["day_name"] = next_arr(arr_week);
    if (z(_["day_name"])) {
        buf = _["buf"];
        obuf = _["obuf"];
        return 0;
    }

    _["cfws2"] = consume_cfws();
    if (z(_["cfws2"])) {
        _["cfws2"] = "";
    }

    stack("day-name", _["day_name"]);
    return _["cfws1"] _["day_name"] _["cfws2"];
}

# day-of-week = ([FWS] day-name) / obs-day-of-week
function consume_day_of_week(_) {
    _["buf"] = buf;
    _["obuf"] = obuf;

    _["dow"] = _consume_day_of_week();
    if (z(_["dow"])) {
        buf = _["buf"];
        obuf = _["obuf"];
        _["dow"] = _consume_obs_day_of_week();
    }

    if (z(_["dow"])) {
        buf = _["buf"];
        obuf = _["obuf"];
        return 0;
    }

    return _["dow"];
}

# [FWS] 1*2DIGIT FWS
function _consume_day(_) {
    _["buf"] = buf;
    _["obuf"] = obuf;

    _["fws1"] = consume_fws();
    _["d1"] = next_arr(arr_digit);

    _["d2"] = next_arr(arr_digit);
    if (z(_["d2"])) {
        _["d2"] = "";
    }

    _["fws2"] = consume_fws();
    if (z(_["fws2"])) {
        _["fws2"] = "";
    }

    if (z(_["d1"]) || z(_["fws1"])) {
        buf = _["buf"];
        obuf = _["obuf"];
        return 0;
    }

    stack("day", _["d1"] _["d2"]);
    return _["fws1"] _["d1"] _["d2"] _["fws2"];
}

# obs-day = [CFWS] 1*2DIGIT [CFWS]
function _consume_obs_day(_) {
    _["buf"] = buf;
    _["obuf"] = obuf;

    _["cfws1"] = consume_cfws();
    if (z(_["cfws1"])) {
        _["cfws1"] = "";
    }

    _["d1"] = next_arr(arr_digit);

    _["d2"] = next_arr(arr_digit);
    if (z(_["d2"])) {
        _["d2"] = "";
    }

    _["cfws2"] = consume_cfws();
    if (z(_["cfws2"])) {
        _["cfws2"] = "";
    }

    if (z(_["d1"])) {
        buf = _["buf"];
        obuf = _["obuf"];
        return 0;
    }

    _["obs_day"] = _["d1"] _["d2"];

    stack("obs-day", _["obs_day"]);
    return _["cfws1"] _["obs_day"] _["cfws2"];
}

# day = ([FWS] 1*2DIGIT FWS) / obs-day
function consume_day(_) {
    _["buf"] = buf;
    _["obuf"] = obuf;

    _["day"] = _consume_day();
    if (z(_["day"])) {
        buf = _["buf"];
        obuf = _["obuf"];
        _["day"] = _consume_obs_day();
    }

    if (z(_["day"])) {
        buf = _["buf"];
        obuf = _["obuf"];
        return 0;
    }

    return _["day"];
}

# month =   "Jan" / "Feb" / "Mar" / "Apr" /
#           "May" / "Jun" / "Jul" / "Aug" /
#           "Sep" / "Oct" / "Nov" / "Dec"
function consume_month(_) {
    _["buf"] = buf;
    _["obuf"] = obuf;

    _["tmp"] = next_arr(arr_month);
    if (z(_["tmp"])) {
        buf = _["buf"];
        obuf = _["obuf"];
        return 0;
    }

    stack("month", _["tmp"]);
    return _["tmp"];
}

# FWS 4*DIGIT FWS
function _consume_year(_) {
    _["buf"] = buf;
    _["obuf"] = obuf;

    _["fws1"] = consume_fws();
    _["year"] = next_token_arr(arr_digit);
    _["fws2"] = consume_fws();

    if (z(_["fws1"]) || length(_["year"]) < 4 || z(_["fws2"])) {
        buf = _["buf"];
        obuf = _["obuf"];
        return 0;
    }

    stack("year", _["year"]);
    return _["year"];
}

# obs-year = [CFWS] 2*DIGIT [CFWS]
function _consume_obs_year(_) {
    _["buf"] = buf;
    _["obuf"] = obuf;

    _["cfws1"] = consume_cfws();
    if (z(_["cfws1"])) {
        _["cfws1"] = "";
    }

    _["year"] = next_token_arr(arr_digit);

    _["cfws2"] = consume_cfws();
    if (z(_["cfws2"])) {
        _["cfws2"] = "";
    }

    if (length(_["year"]) < 2) {
        buf = _["buf"];
        obuf = _["obuf"];
        return 0;
    }

    stack("obs-year", _["year"]);
    return _["cfws1"] _["year"] _["cfws2"];
}

# year = (FWS 4*DIGIT FWS) / obs-year
function consume_year(_) {
    _["buf"] = buf;
    _["obuf"] = obuf;

    _["year"] = _consume_year();
    if (z(_["year"])) {
        buf = _["buf"];
        obuf = _["obuf"];
        _["year"] = _consume_obs_year();
    }

    if (z(_["year"])) {
        buf = _["buf"];
        obuf = _["obuf"];
        return 0;
    }

    return _["year"];
}

# date = day month year
function consume_date(_) {
    _["buf"] = buf;
    _["obuf"] = obuf;

    _["day"] = consume_day();
    _["month"] = consume_month();
    _["year"] = consume_year();

    if (z(_["day"]) || z(_["month"]) || z(_["year"])) {
        buf = _["buf"];
        obuf = _["obuf"];
        return 0;
    }

    return _["day"] _["month"] _["year"];
}

# 2DIGIT
function _consume_hour(_) {
    _["buf"] = buf;
    _["obuf"] = obuf;

    _["hour"] = next_token_arr(arr_digit);
    if (length(_["hour"]) != 2) {
        buf = _["buf"];
        obuf = _["obuf"];
        return 0;
    }

    stack("hour", _["hour"]);
    return _["hour"];
}

# obs-hour = [CFWS] 2DIGIT [CFWS]
function _consume_obs_hour(_) {
    _["buf"] = buf;
    _["obuf"] = obuf;

    _["cfws1"] = consume_cfws();
    if (z(_["cfws1"])) {
        _["cfws1"] = "";
    }

    _["hour"] = next_token_arr(arr_digit);

    _["cfws2"] = consume_cfws();
    if (z(_["cfws2"])) {
        _["cfws2"] = "";
    }

    if (length(_["hour"]) != 2) {
        buf = _["buf"];
        obuf = _["obuf"];
        return 0;
    }

    stack("obs-hour", _["hour"]);
    return _["cfws1"] _["hour"] _["cfws2"];
}

# hour = 2DIGIT / obs-hour
function consume_hour(_) {
    _["buf"] = buf;
    _["obuf"] = obuf;

    _["hour"] = _consume_hour();
    if (z(_["hour"])) {
        buf = _["buf"];
        obuf = _["obuf"];
        _["hour"] = _consume_obs_hour();
    }

    if (z(_["hour"])) {
        buf = _["buf"];
        obuf = _["obuf"];
        return 0;
    }

    return _["hour"];
}

# 2DIGIT
function _consume_minute(_) {
    _["buf"] = buf;
    _["obuf"] = obuf;

    _["minute"] = next_token_arr(arr_digit);

    if (length(_["minute"]) != 2) {
        buf = _["buf"];
        obuf = _["obuf"];
        return 0;
    }

    stack("minute", _["minute"]);
    return _["minute"];
}

# obs-minute = [CFWS] 2DIGIT [CFWS]
function _consume_obs_minute(_) {
    _["buf"] = buf;
    _["obuf"] = obuf;

    _["cfws1"] = consume_cfws();
    if (z(_["cfws1"])) {
        _["cfws1"] = "";
    }

    _["minute"] = next_token_arr(arr_digit);

    _["cfws2"] = consume_cfws();
    if (z(_["cfws2"])) {
        _["cfws2"] = "";
    }

    if (length(_["minute"]) != 2) {
        buf = _["buf"];
        obuf = _["obuf"];
        return 0;
    }

    stack("obs-minute", _["minute"]);
    return _["cfws1"] _["minute"] _["cfws2"];
}

# minute = 2DIGIT / obs-minute
function consume_minute(_) {
    _["buf"] = buf;
    _["obuf"] = obuf;

    _["minute"] = _consume_minute();
    if (z(_["minute"])) {
        buf = _["buf"];
        obuf = _["obuf"];
        _["minute"] = _consume_obs_minute();
    }

    if (z(_["minute"])) {
        buf = _["buf"];
        obuf = _["obuf"];
        return 0;
    }

    return _["minute"];
}

# 2DIGIT
function _consume_second(_) {
    _["buf"] = buf;
    _["obuf"] = obuf;

    _["second"] = next_token_arr(arr_digit);

    if (length(_["second"]) != 2) {
        buf = _["buf"];
        obuf = _["obuf"];
        return 0;
    }

    stack("second", _["second"]);
    return _["second"];
}

# obs-second = [CFWS] 2DIGIT [CFWS]
function _consume_obs_second(_) {
    _["buf"] = buf;
    _["obuf"] = obuf;

    _["cfws1"] = consume_cfws();
    if (z(_["cfws1"])) {
        _["cfws1"] = "";
    }

    _["minute"] = next_token_arr(arr_digit);

    _["cfws2"] = consume_cfws();
    if (z(_["cfws2"])) {
        _["cfws2"] = "";
    }

    if (length(_["minute"]) != 2) {
        buf = _["buf"];
        obuf = _["obuf"];
        return 0;
    }

    stack("obs-second", _["minute"]);
    return _["cfws1"] _["minute"] _["cfws2"];
}

# second = 2DIGIT / obs-second
function consume_second(_) {
    _["buf"] = buf;
    _["obuf"] = obuf;

    _["second"] = _consume_second();
    if (z(_["second"])) {
        buf = _["buf"];
        obuf = _["obuf"];
        _["second"] = _consume_obs_second();
    }

    if (z(_["second"])) {
        buf = _["buf"];
        obuf = _["obuf"];
        return 0;
    }

    return _["second"];
}

# FWS ( "+" / "-" ) 4DIGIT
function _consume_zone(_) {
    _["buf"] = buf;
    _["obuf"] = obuf;

    _["fws"] = consume_fws();
    if (z(_["fws"])) {
        _["fws"] = "";
    }

    _["sign"] = next_str("+");
    if (z(_["sign"])) {
        _["sign"] = next_str("-");
    }

    if (z(_["sign"])) {
        buf = _["buf"];
        obuf = _["obuf"];
        return 0;
    }

    _["digit"] = next_token_arr(arr_digit);

    if (length(_["digit"]) != 4) {
        buf = _["buf"];
        obuf = _["obuf"];
        return 0;
    }

    _["zone"] = _["sign"] _["digit"];

    stack("zone", _["zone"]);
    return _["zone"];
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
    _["buf"] = buf;
    _["obuf"] = obuf;

    _["zone"] = next_arr(arr_obs_zone);
    if (z(_["zone"])) {
        buf = _["buf"];
        obuf = _["obuf"];
        return 0;
    }

    stack("obs-zone", _["zone"]);
    return _["zone"];
}

# zone = (FWS ( "+" / "-" ) 4DIGIT) / obs-zone
function consume_zone(_) {
    _["buf"] = buf;
    _["obuf"] = obuf;

    _["tmp"] = _consume_zone();
    if (z(_["tmp"])) {
        buf = _["buf"];
        obuf = _["obuf"];
        _["tmp"] = _consume_obs_zone();
    }

    if (z(_["tmp"])) {
        buf = _["buf"];
        obuf = _["obuf"];
        return 0;
    }

    return _["tmp"];
}

# time-of-day = hour ":" minute [ ":" second ]
function consume_time_of_day(_) {
    _["buf"] = buf;
    _["obuf"] = obuf;

    _["tmp"] = "";

    _["hour"] = consume_hour();
    if (z(_["hour"])) {
        buf = _["buf"];
        obuf = _["obuf"];
        return 0;
    }
    _["tmp"] = _["tmp"] _["hour"];

    _["colon1"] = next_str(":");
    if (z(_["colon1"])) {
        buf = _["buf"];
        obuf = _["obuf"];
        return 0;
    }
    _["tmp"] = _["tmp"] _["colon1"];

    _["minute"] = consume_minute();
    if (z(_["minute"])) {
        buf = _["buf"];
        obuf = _["obuf"];
        return 0;
    }
    _["tmp"] = _["tmp"] _["minute"];

    _["colon2"] = next_str(":");
    if (!z(_["colon2"])) {
        _["tmp"] = _["tmp"] _["colon2"];
        _["second"] = consume_second();
        if (z(_["second"])) {
            buf = _["buf"];
            obuf = _["obuf"];
            return 0;
        }
        _["tmp"] = _["tmp"] _["second"];
    }

    return _["tmp"];
}

# time = time-of-day zone
function consume_time(_) {
    _["buf"] = buf;
    _["obuf"] = obuf;

    _["tmp"] = "";

    _["tod"] = consume_time_of_day();
    if (z(_["tod"])) {
        buf = _["buf"];
        obuf = _["obuf"];
        return 0;
    }
    _["tmp"] = _["tmp"] _["tod"];

    _["zone"] = consume_zone();
    if (z(_["zone"])) {
        buf = _["buf"];
        obuf = _["obuf"];
        return 0
    }
    _["tmp"] = _["tmp"] _["zone"];

    return _["tmp"];
}

# date-time = [ day-of-week "," ] date time [CFWS]
function consume_date_time(_) {
    _["buf"] = buf;
    _["obuf"] = obuf;

    _["dow"] = consume_day_of_week();
    _["comma"] = "";
    if (!z(_["dow"])) {
        _["comma"] = next_str(",");
        if (z(_["comma"])) {
            buf = _["buf"];
            obuf = _["obuf"];
            return 0;
        }
    }

    _["date"] = consume_date();
    if (z(_["date"])) {
        buf = _["buf"];
        obuf = _["obuf"];
        return 0;
    }

    _["time"] = consume_time();
    if (z(_["time"])) {
        buf = _["buf"];
        obuf = _["obuf"];
        return 0;
    }

    _["cfws"] = consume_cfws();
    if (z(_["cfws"])) { _["cfws"] = ""; }

    return _["dow"] _["comma"] _["date"] _["time"] _["cfws"];
}

# mailbox *("," mailbox)
function _consume_mailbox_list(_) {
    _["buf"] = buf;
    _["obuf"] = obuf;

    _["tmp"] = "";

    do {
        _["mbox"] = consume_mailbox();
        if (z(_["mbox"])) {
            buf = _["buf"];
            obuf = _["obuf"];
            return 0;
        }

        _["tmp"] = _["tmp"] _["mbox"];
        _["comma"] = next_str(",");
    } while (!z(_["comma"]))

    return _["tmp"];
}

# obs-mbox-list = *([CFWS] ",") mailbox *("," [mailbox / CFWS])
function _consume_obs_mbox_list(_) {
    _["buf"] = buf;
    _["obuf"] = obuf;

    _["tmp"] = "";

    do {
        _["cfws"] = consume_cfws();
        if (z(_["cfws"])) {
            _["cfws"] = "";
        }
        _["tmp"] = _["tmp"] _["cfws"];

        _["comma"] = next_str(",");
        if (!z(_["comma"])) {
            _["tmp"] = _["tmp"] _["comma"];
        }
    } while (!z(_["comma"]))

    _["mbox"] = consume_mailbox();
    if (z(_["mbox"])) {
        buf = _["buf"];
        obuf = _["obuf"];
        return 0;
    }

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
            _["cfws"] = consume_cfws();
            if (z(_["cfws"])) {
                _["cfws"] = "";
            }
            _["tmp"] = _["tmp"] _["cfws"];
        }
    }

    return _["tmp"];
}

# mailbox-list = (mailbox *("," mailbox)) / obs-mbox-list
function consume_mailbox_list(_) {
    _["buf"] = buf;
    _["obuf"] = obuf;

    _["tmp"] = _consume_mailbox_list();
    if (z(_["tmp"])) {
        buf = _["buf"];
        obuf = _["obuf"];
        _["tmp"] = _consume_obs_mbox_list();
    }

    if (z(_["tmp"])) {
        buf = _["buf"];
        obuf = _["obuf"];
        return 0;
    }

    return _["tmp"];
}

# atom = [CFWS] 1*atext [CFWS]
function consume_atom(_) {
    _["buf"] = buf;
    _["obuf"] = obuf;

    _["cfws1"] = consume_cfws();
    if (z(_["cfws1"])) {
        _["cfws1"] = "";
    }

    _["atom"] = next_token(atext);
    if (_["atom"] == "") {
        buf = _["buf"];
        obuf = _["obuf"];
        return 0;
    }

    _["cfws2"] = consume_cfws();
    if (z(_["cfws2"])) {
        _["cfws2"] = "";
    }

    return _["cfws1"] _["atom"] _["cfws2"];
}

# qcontent = qtext / quoted-pair
function consume_qcontent(_) {
    _["buf"] = buf;
    _["obuf"] = obuf;

    _["tmp"] = next_token(qtext);
    if (_["tmp"] == "") {
        buf = _["buf"];
        obuf = _["obuf"];
        _["tmp"] = consume_quoted_pair();
    }

    if (z(_["tmp"])) {
        buf = _["buf"];
        obuf = _["obuf"];
        return 0;
    }

    return _["tmp"];
}

# quoted-string = [CFWS]
#                 DQUOTE *([FWS] qcontent) [FWS] DQUOTE
#                 [CFWS]
function consume_quoted_string(_) {
    _["buf"] = buf;
    _["obuf"] = obuf;

    _["tmp"] = ""

    _["cfws"] = consume_cfws();
    if (z(_["cfws"])) {
        _["cfws"] = "";
    }
    _["tmp"] = _["tmp"] _["cfws"];

    _["DQUOTE"] = next_str(QQ);
    if (z(_["DQUOTE"])) {
        buf = _["buf"];
        obuf = _["obuf"];
        return 0;
    }
    _["tmp"] = _["tmp"] _["DQUOTE"];

    while (1) {
        _["fws"] = consume_fws();
        if (!z(_["fws"])) {
            _["tmp"] = _["tmp"] _["fws"];
        }

        _["qcontent"] = consume_qcontent();
        if (z(_["qcontent"])) { break; }
        _["tmp"] = _["tmp"] _["qcontent"];
    }

    _["fws"] = consume_fws();
    if (!z(_["fws"])) {
        _["tmp"] = _["tmp"] _["fws"];
    }

    _["DQUOTE"] = next_str(QQ);
    if (z(_["DQUOTE"])) {
        buf = _["buf"];
        obuf = _["obuf"];
        return 0;
    }
    _["tmp"] = _["tmp"] _["DQUOTE"];

    _["cfws"] = consume_cfws();
    if (z(_["cfws"])) {
        _["cfws"] = "";
    }
    _["tmp"] = _["tmp"] _["cfws"];

    return _["tmp"];
}

# word = atom / quoted-string
function consume_word(_) {
    _["buf"] = buf;
    _["obuf"] = obuf;

    _["tmp"] = consume_atom();
    if (z(_["tmp"])) {
        buf = _["buf"];
        obuf = _["obuf"];
        _["tmp"] = consume_quoted_string();
    }

    if (z(_["tmp"])) {
        buf = _["buf"];
        obuf = _["obuf"];
        return 0;
    }

    return _["tmp"];
}

# 1*word
function _consume_phrase(_) {
    _["buf"] = buf;
    _["obuf"] = obuf;

    _["tmp"] = "";
    while (1) {
        _["word"] = consume_word();
        if (z(_["word"])) { break; }
        _["tmp"] = _["tmp"] _["word"];
    }

    if (!_["tmp"]) {
        buf = _["buf"];
        obuf = _["obuf"];
        return 0;
    }

    stack("phrase", _["tmp"]);
    return _["tmp"];
}

# obs-phrase = word *(word / "." / CFWS)
function _consume_obs_phrase(_) {
    _["buf"] = buf;
    _["obuf"] = obuf;

    _["tmp"] = consume_word();
    if (z(_["tmp"])) {
        buf = _["buf"];
        obuf = _["obuf"];
        return 0;
    }

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
    _["buf"] = buf;
    _["obuf"] = obuf;

    _["tmp"] = _consume_phrase();
    if (z(_["tmp"])) {
        buf = _["buf"];
        obuf = _["obuf"];
        _["tmp"] = _consume_obs_phrase();
    }

    if (z(_["tmp"])) {
        buf = _["buf"];
        obuf = _["obuf"];
        return 0;
    }

    return _["tmp"];
}

# display-name = phrase
function consume_display_name(_) {
    _["buf"] = buf;
    _["obuf"] = obuf;

    _["tmp"] = consume_phrase();
    if (z(_["tmp"])) {
        buf = _["buf"];
        obuf = _["obuf"];
        return 0;
    }

    return _["tmp"];
}

# [CFWS] "<" addr-spec ">" [CFWS]
function _consume_angle_addr(_) {
    _["buf"] = buf;
    _["obuf"] = obuf;

    _["cfws1"] = consume_cfws();
    if (z(_["cfws1"])) { _["cfws1"] = ""; }

    _["op_angle"] = next_str("<");
    _["addr_spec"] = consume_addr_spec();
    _["cl_angle"] = next_str(">");

    if (z(_["op_angle"]) || z(_["addr_spec"]) || z(_["cl_angle"])) {
        buf = _["buf"];
        obuf = _["obuf"];
        return 0;
    }

    _["angle_addr"] = _["op_angle"] _["addr_spec"] _["cl_angle"];

    _["cfws2"] = consume_cfws();
    if (z(_["cfws2"])) { _["cfws2"] = ""; }

    return _["cfws1"] _["angle_addr"] _["cfws2"];
}

# obs-domain-list = *(CFWS / ",") "@" domain
#                   *("," [CFWS] ["@" domain])
function consume_obs_domain_list(_) {
    _["buf"] = buf;
    _["obuf"] = obuf;

    _["tmp"] = "";

    while (1) {
        _["cfws"] = consume_cfws();
        if (z(_["cfws"])) { _["cfws"] = ""; }
        _["tmp"] = _["tmp"] _["cfws"];

        _["comma"] = next_str(",");
        if (z(_["comma"])) { break; }
        _["tmp"] = _["tmp"] _["comma"];
    }

    _["at"] = next_str("@");
    if (!z(_["at"])) {
        buf = _["buf"];
        obuf = _["obuf"];
        return 0;
    }
    _["tmp"] = _["tmp"] _["at"];

    _["domain"] = consume_domain();
    if (!z(_["domain"])) {
        buf = _["buf"];
        obuf = _["obuf"];
        return 0;
    }
    _["tmp"] = _["tmp"] _["domain"];

    while (1) {
        _["comma"] = next_str(",");
        if (z(_["comma"])) { break; }
        _["tmp"] = _["tmp"] _["comma"];

        _["cfws"] = consume_cfws();
        if (z(_["cfws"])) { _["cfws"] = ""; }
        _["tmp"] = _["tmp"] _["cfws"];

        _["at"] = next_str("@");
        if (z(_["at"])) { continue; }
        _["tmp"] = _["tmp"] _["at"];

        _["domain"] = consume_domain();
        if (z(_["domain"])) {
            buf = _["buf"];
            obuf = _["obuf"];
            return 0;
        }
        _["tmp"] = _["tmp"] _["domain"];
    }

    return _["tmp"];
}

# obs-route = obs-domain-list ":"
function consume_obs_route(_) {
    _["buf"] = buf;
    _["obuf"] = obuf;

    _["obs_domain_list"] = consume_obs_domain_list();
    _["colon"] = next_str(":");

    if (z(_["obs_domain_list"]) || z(_["colon"])) {
        buf = _["buf"];
        obuf = _["obuf"];
        return 0;
    }

    return _["obs_domain_list"] _["colon"];
}

# obs-angle-addr = [CFWS] "<" obs-route addr-spec ">" [CFWS]
function _consume_obs_angle_addr(_) {
    _["buf"] = buf;
    _["obuf"] = obuf;

    _["cfws"] = consume_cfws();
    if (z(_["cfws"])) { _["cfws"] = ""; }

    _["op_angle"] = next_str("<");
    _["obs_route"] = consume_obs_route();
    _["addr_spec"] = consume_addr_spec();
    _["cl_angle"] = next_str(">");

    if (z(_["op_angle"]) || z(_["obs_route"]) || z(_["addr_spec"]) || z(_["cl_angle"])) {
        buf = _["buf"];
        obuf = _["obuf"];
        return 0;
    }

    _["obs_angle_addr"] = _["op_angle"] _["obs_route"] _["addr_spec"] _["cl_angle"];

    stack("addr-spec", _["addr_spec"]);
    return _["cfws"] _["obs_angle_addr"];
}

# angle-addr = [CFWS] "<" addr-spec ">" [CFWS] /
#              obs-angle-addr
function consume_angle_addr(_) {
    _["buf"] = buf;
    _["obuf"] = obuf;

    _["tmp"] = _consume_angle_addr();

    if (z(_["tmp"])) {
        buf = _["buf"];
        obuf = _["obuf"];
        _["tmp"] = _consume_obs_angle_addr();
    }

    if (z(_["tmp"])) {
        buf = _["buf"];
        obuf = _["obuf"];
        return 0;
    }

    return _["tmp"];
}

# name-addr = [display-name] angle-addr
function consume_name_addr(_) {
    _["buf"] = buf;
    _["obuf"] = obuf;

    _["tmp"] = consume_display_name();
    if (z(_["tmp"])) {
        _["tmp"] = "";
    }

    _["angle_addr"] = consume_angle_addr();
    if(z(_["angle_addr"])) {
        buf = _["buf"];
        obuf = _["obuf"];
        return 0;
    }

    return _["tmp"] _["angle_addr"];
}

# dot-atom-text = 1*atext *("." 1*atext)
function consume_dot_atom_text(_) {
    _["buf"] = buf;
    _["obuf"] = obuf;

    _["tmp"] = next_token(atext);
    if (_["tmp"] == "") {
        buf = _["buf"];
        obuf = _["obuf"];
        return 0;
    }

    while (1) {
        _["dot"] = next_str(".");
        if (z(_["dot"])) { break; }
        _["tmp"] = _["tmp"] _["dot"];

        _["atext"] = next_token(atext);
        if (_["atext"] == "") {
            buf = _["buf"];
            obuf = _["obuf"];
            return 0;
        }
        _["tmp"] = _["tmp"] _["atext"];
    }

    return _["tmp"];
}

# dot-atom = [CFWS] dot-atom-text [CFWS]
function consume_dot_atom(_) {
    _["buf"] = buf;
    _["obuf"] = obuf;

    _["cfws1"] = consume_cfws();
    if (z(_["cfws1"])) { _["cfws1"] = ""; }

    _["dot_atom_text"] = consume_dot_atom_text();
    if (z(_["dot_atom_text"])) {
        buf = _["buf"];
        obuf = _["obuf"];
        return 0;
    }

    _["cfws2"] = consume_cfws();
    if (z(_["cfws2"])) { _["cfws2"] = ""; }

    return _["cfws1"] _["dot_atom_text"] _["cfws2"];
}

# obs-local-part = word *("." word)
function consume_obs_local_part(_) {
    _["buf"] = buf;
    _["obuf"] = obuf;

    _["tmp"] = consume_word();
    if (z(_["tmp"])) {
        buf = _["buf"];
        obuf = _["obuf"];
        return 0;
    }

    while (1) {
        _["dot"] = next_str(".");
        if (z(_["dot"])) { break; }
        _["tmp"] = _["tmp"] _["dot"];

        _["word"] = consume_word();
        if (z(_["word"])) {
            buf = _["buf"];
            obuf = _["obuf"];
            return 0;
        }
        _["tmp"] = _["tmp"] _["word"];
    }

    return _["tmp"];
}

# local-part = dot-atom / quoted-string / obs-local-part
function consume_local_part(_) {
    _["buf"] = buf;
    _["obuf"] = obuf;

    _["tmp"] = consume_dot_atom();
    if (!z(_["tmp"])) { return _["tmp"]; }

    buf = _["buf"];
    obuf = _["obuf"];

    _["tmp"] = consume_quoted_string();
    if (!z(_["tmp"])) { return _["tmp"]; }

    buf = _["buf"];
    obuf = _["obuf"];

    _["tmp"] = consume_obs_local_part();
    if (!z(_["tmp"])) { return _["tmp"]; }

    buf = _["buf"];
    obuf = _["obuf"];

    return 0;
}

# dtext
function _consume_dtext(_) {
    _["buf"] = buf;
    _["obuf"] = obuf;

    _["tmp"] = next_token(dtext);
    if (_["tmp"] == "") {
        buf = _["buf"];
        obuf = _["obuf"];
        return 0;
    }

    return _["tmp"];
}

# obs-dtext = obs-NO-WS-CTL / quoted-pair
function _consume_obs_dtext(_) {
    _["buf"] = buf;
    _["obuf"] = obuf;

    _["tmp"] = next_arr(arr_obs_no_ws_ctl);
    if (z(_["tmp"])) {
        buf = _["buf"];
        obuf = _["obuf"];
        _["tmp"] = consume_quoted_pair();
    }

    if (z(_["tmp"])) {
        buf = _["buf"];
        obuf = _["obuf"];
        return 0;
    }

    return _["tmp"];
}

# dtext = %d33-90 /  ; Printable US-ASCII
#         %d94-126 / ;  characters not including
#         obs-dtext  ;  "[", "]", or "\"
function consume_dtext(_) {
    _["buf"] = buf;
    _["obuf"] = obuf;

    _["tmp"] = _consume_dtext();
    if (z(_["tmp"])) {
        buf = _["buf"];
        obuf = _["obuf"];
        _["tmp"] = _consume_obs_dtext();
    }

    if (z(_["tmp"])) {
        buf = _["buf"];
        obuf = _["obuf"];
        return 0;
    }

    return _["tmp"];
}

# domain-literal = [CFWS] "[" *([FWS] dtext) [FWS] "]" [CFWS]
function consume_domain_literal(_) {
    _["buf"] = buf;
    _["obuf"] = obuf;

    _["tmp"] = "";

    _["cfws"] = consume_cfws();
    if (z(_["cfws"])) { _["cfws"] = ""; }
    _["tmp"] = _["tmp"] _["cfws"];

    _["op_bracket"] = next_str("[");
    if (z(_["op_bracket"])) {
        buf = _["buf"];
        obuf = _["obuf"];
        return 0;
    }
    _["tmp"] = _["tmp"] _["op_bracket"];

    while (1) {
        _["fws"] = consume_fws();
        if (z(_["fws"])) { _["fws"] = ""; }
        _["tmp"] = _["tmp"] _["fws"];

        _["dtext"] = consume_dtext();
        if (z(_["dtext"])) { break; }
        _["tmp"] = _["tmp"] _["dtext"];
    }

    _["fws"] = consume_fws();
    if (z(_["fws"])) { _["fws"] = ""; }
    _["tmp"] = _["tmp"] _["fws"];

    _["cl_bracket"] = next_str("]");
    if (z(_["cl_bracket"])) {
        buf = _["buf"];
        obuf = _["obuf"];
        return 0;
    }
    _["tmp"] = _["tmp"] _["cl_bracket"];

    _["cfws"] = consume_cfws();
    if (z(_["cfws"])) { _["cfws"] = ""; }
    _["tmp"] = _["tmp"] _["cfws"];

    return _["tmp"];
}

# obs-domain = atom *("." atom)
function consume_obs_domain(_) {
    _["buf"] = buf;
    _["obuf"] = obuf;

    _["tmp"] = consume_atom();
    if (z(_["tmp"])) {
        buf = _["buf"];
        obuf = _["obuf"];
        return 0;
    }

    while (1) {
        _["dot"] = next_str(".");
        if (z(_["dot"])) { break; }
        _["tmp"] = _["tmp"] _["dot"];

        _["atom"] = consume_atom();
        if (z(_["atom"])) {
            buf = _["buf"];
            obuf = _["obuf"];
            return 0;
        }
        _["tmp"] = _["tmp"] _["atom"];
    }

    return _["tmp"];
}

# domain = dot-atom / domain-literal / obs-domain
function consume_domain(_) {
    _["buf"] = buf;
    _["obuf"] = obuf;

    _["tmp"] = consume_dot_atom();
    if (!z(_["tmp"])) { return _["tmp"]; }

    buf = _["buf"];
    obuf = _["obuf"];

    _["tmp"] = consume_domain_literal();
    if (!z(_["tmp"])) { return _["tmp"]; }

    buf = _["buf"];
    obuf = _["obuf"];

    _["tmp"] = consume_obs_domain();
    if (!z(_["tmp"])) { return _["tmp"]; }

    buf = _["buf"];
    obuf = _["obuf"];

    return 0;
}

# addr-spec = local-part "@" domain
function consume_addr_spec(_) {
    _["buf"] = buf;
    _["obuf"] = obuf;

    _["local_part"] = consume_local_part();
    _["at"] = next_str("@");
    _["domain"] = consume_domain();

    if (z(_["local_part"]) || z(_["at"]) || z(_["domain"])) {
        buf = _["buf"];
        obuf = _["obuf"];
        return 0;
    }

    _["addr_spec"] = _["local_part"] _["at"] _["domain"];

    stack("addr-spec", _["addr_spec"]);
    return _["addr_spec"];
}

# mailbox = name-addr / addr-spec
function consume_mailbox(_) {
    _["buf"] = buf;
    _["obuf"] = obuf;
    stack("---", "mailbox");

    _["tmp"] = consume_name_addr();
    if (z(_["tmp"])) {
        buf = _["buf"];
        obuf = _["obuf"];
        _["tmp"] = consume_addr_spec();
    }

    if (z(_["tmp"])) {
        buf = _["buf"];
        obuf = _["obuf"];
        return 0;
    }

    return _["tmp"];
}

# obs-group-list = 1*([CFWS] ",") [CFWS]
function consume_obs_group_list(_) {
    _["buf"] = buf;
    _["obuf"] = obuf;

    _["tmp"] = "";

    while (1) {
        _["cfws"] = consume_cfws();
        if (z(_["cfws"])) { _["cfws"] = ""; }
        _["tmp"] = _["tmp"] _["cfws"];

        _["comma"] = next_str(",");
        if (z(_["comma"])) { break; }
        _["tmp"] = _["tmp"] _["comma"];
    }

    if (!_["tmp"]) {
        buf = _["buf"];
        obuf = _["obuf"];
        return 0;
    }

    _["cfws"] = consume_cfws();
    if (z(_["cfws"])) { _["cfws"] = ""; }
    _["tmp"] = _["tmp"] _["cfws"];

    return _["tmp"];
}

# group-list = mailbox-list / CFWS / obs-group-list
function consume_group_list(_) {
    _["buf"] = buf;
    _["obuf"] = obuf;
    stack("---", "group-list");

    _["tmp"] = consume_mailbox_list();
    if (!z(_["tmp"])) { return _["tmp"]; }

    _["tmp"] = consume_cfws();
    if (!z(_["tmp"])) { return _["tmp"]; }

    _["tmp"] = consume_obs_group_list();
    if (!z(_["tmp"])) { return _["tmp"]; }

    buf = _["buf"];
    obuf = _["obuf"];

    return 0;
}

# group = display-name ":" [group-list] ";" [CFWS]
function consume_group(_) {
    _["buf"] = buf;
    _["obuf"] = obuf;
    stack("---", "group");

    _["tmp"] = consume_display_name();
    if (z(_["tmp"])) {
        buf = _["buf"];
        obuf = _["obuf"];
        return 0;
    }

    _["colon"] = next_str(":");

    _["group_list"] = consume_group_list();
    if (z(_["group_list"])) { _["group_list"] = ""; }

    _["semicolon"] = next_str(";");

    if (z(_["colon"]) || z(_["semicolon"])) {
        buf = _["buf"];
        obuf = _["obuf"];
        return 0;
    }

    _["tmp"] = _["tmp"] _["colon"] _["group_list"] _["semicolon"];

    _["cfws"] = consume_cfws();
    if (z(_["cfws"])) { _["cfws"] = ""; }
    _["tmp"] = _["tmp"] _["cfws"];

    return _["tmp"];
}

# address = mailbox / group
function consume_address(_) {
    _["buf"] = buf;
    _["obuf"] = obuf;

    _["tmp"] = consume_mailbox();
    if (z(_["tmp"])) {
        buf = _["buf"];
        obuf = _["obuf"];
        _["tmp"] = consume_group();
    }

    if (z(_["tmp"])) {
        buf = _["buf"];
        obuf = _["obuf"];
        return 0;
    }

    return _["tmp"];
}

# address *("," address)
function _consume_address_list(_) {
    _["buf"] = buf;
    _["obuf"] = obuf;

    _["tmp"] = consume_address();
    if (z(_["tmp"])) {
        buf = _["buf"];
        obuf = _["obuf"];
        return 0;
    }

    while (1) {
        _["comma"] = next_str(",");
        if (z(_["comma"])) { break; }
        _["tmp"] = _["tmp"] _["comma"];

        _["addr"] = consume_address();
        if (z(_["addr"])) {
            buf = _["buf"];
            obuf = _["obuf"];
            return 0;
        }
        _["tmp"] = _["tmp"] _["addr"];
    }

    return _["tmp"];
}

# obs-addr-list = *([CFWS] ",") address *("," [address / CFWS])
function _consume_obs_addr_list(_) {
    _["buf"] = buf;
    _["obuf"] = obuf;

    _["tmp"] = "";

    while (1) {
        _["cfws"] = consume_cfws();
        if (z(_["cfws"])) { _["cfws"] = ""; }
        _["tmp"] = _["tmp"] _["cfws"];

        _["comma"] = next_str(",");
        if (z(_["comma"])) { break; }
        _["tmp"] = _["tmp"] _["comma"];
    }

    _["addr"] = consume_address();
    if (z(_["addr"])) {
        buf = _["buf"];
        obuf = _["obuf"];
        return 0;
    }
    _["tmp"] = _["tmp"] _["addr"];

    while (1) {
        _["comma"] = next_str(",");
        if (!_["comma"]) { break; }
        _["tmp"] = _["tmp"] _["comma"];

        _["addr"] = consume_address();
        if (z(_["addr"])) {
            _["cfws"] = consume_cfws();
            if (z(_["cfws"])) { _["cfws"] = ""; }
            _["tmp"] = _["tmp"] _["cfws"];
            continue;
        }
        _["tmp"] = _["tmp"] _["addr"];
    }

    return _["tmp"];
}

# address-list = (address *("," address)) / obs-addr-list
function consume_address_list(_) {
    _["buf"] = buf;
    _["obuf"] = obuf;

    _["tmp"] = _consume_address_list();
    if (z(_["tmp"])) {
        buf = _["buf"];
        obuf = _["obuf"];
        _["tmp"] = _consume_obs_addr_list();
    }

    if (z(_["tmp"])) {
        buf = _["buf"];
        obuf = _["obuf"];
        return 0;
    }

    return _["tmp"];
}

# bcc = "Bcc:" [address-list / CFWS] CRLF
function consume_bcc(_) {
    _["buf"] = buf;
    _["obuf"] = obuf;

    _["tmp"] = consume_address_list();
    if (z(_["tmp"])) {
        buf = _["buf"];
        obuf = _["obuf"];
        _["tmp"] = consume_cfws();
    }

    if (z(_["tmp"])) {
        buf = _["buf"];
        obuf = _["obuf"];
        return 0;
    }

    return _["tmp"];
}

# obs-id-left = local-part
function _consume_obs_id_left(_) {
    _["buf"] = buf;
    _["obuf"] = obuf;

    _["tmp"] = consume_local_part();
    if (z(_["tmp"])) {
        buf = _["buf"];
        obuf = _["obuf"];
        return 0;
    }

    return _["tmp"];
}

# id-left = dot-atom-text / obs-id-left
function consume_id_left(_) {
    _["buf"] = buf;
    _["obuf"] = obuf;

    _["tmp"] = consume_dot_atom_text();
    if (z(_["tmp"])) {
        buf = _["buf"];
        obuf = _["obuf"];
        _["tmp"] = _consume_obs_id_left();
    }

    if (z(_["tmp"])) {
        buf = _["buf"];
        obuf = _["obuf"];
        return 0;
    }

    return _["tmp"];
}

# no-fold-literal = "[" *dtext "]"
function consume_no_fold_literal(_) {
    _["buf"] = buf;
    _["obuf"] = obuf;

    _["op_bracket"] = next_str("[");
    _["dtext"] = next_token(dtext);
    _["cl_bracket"] = next_str("]");

    if (z(_["op_bracket"]) || _["dtext"] == "" || z(_["cl_bracket"])) {
        buf = _["buf"];
        obuf = _["obuf"];
        return 0;
    }

    return _["op_bracket"] _["dtext"] _["cl_bracket"];
}

# obs-id-right = domain
function _consume_obs_id_right(_) {
    _["buf"] = buf;
    _["obuf"] = obuf;

    _["tmp"] = consume_domain();
    if (z(_["tmp"])) {
        buf = _["buf"];
        obuf = _["obuf"];
        return 0;
    }

    return _["tmp"];
}

# id-right = dot-atom-text / no-fold-literal / obs-id-right
function consume_id_right(_) {
    _["buf"] = buf;
    _["obuf"] = obuf;

    _["tmp"] = consume_dot_atom_text();
    if (z(_["tmp"])) {
        buf = _["buf"];
        obuf = _["obuf"];
        _["tmp"] = consume_no_fold_literal();
    }

    if (z(_["tmp"])) {
        buf = _["buf"];
        obuf = _["obuf"];
        _["tmp"] = _consume_obs_id_right();
    }

    if (z(_["tmp"])) {
        buf = _["buf"];
        obuf = _["obuf"];
        return 0;
    }

    return _["tmp"];
}

# msg-id = [CFWS] "<" id-left "@" id-right ">" [CFWS]
function consume_msg_id(_) {
    _["buf"] = buf;
    _["obuf"] = obuf;

    _["cfws1"] = consume_cfws();
    if (z(_["cfws1"])) { _["cfws1"] = ""; }

    _["op_angle"] = next_str("<");
    _["id_left"] = consume_id_left();
    _["at"] = next_str("@");
    _["id_right"] = consume_id_right();
    _["cl_angle"] = next_str(">");

    if (z(_["op_angle"]) || z(_["id_left"]) || z(_["at"]) || z(_["id_right"]) || z(_["cl_angle"])) {
        buf = _["buf"];
        obuf = _["obuf"];
        return 0;
    }

    _["msg_id"] = _["id_left"] _["at"] _["id_right"];

    _["cfws2"] = consume_cfws();
    if (z(_["cfws2"])) { _["cfws2"] = ""; }

    stack("msg-id", _["msg_id"]);
    return _["cfws1"] _["op_angle"] _["msg_id"] _["cl_angle"] _["cfws2"];
}

# references = "References:" 1*msg-id CRLF
function consume_references(_) {
    _["buf"] = buf;
    _["obuf"] = obuf;

    _["tmp"] = 0;

    while (1) {
        _["msg_id"] = consume_msg_id();
        if (z(_["msg_id"])) { break; }
        _["tmp"] = _["tmp"] _["msg_id"];
    }

    if (z(_["tmp"])) {
        buf = _["buf"];
        obuf = _["obuf"];
        return 0;
    }

    return _["tmp"];
}

# path = angle-addr / ([CFWS] "<" [CFWS] ">" [CFWS])
function consume_path(_) {
    _["buf"] = buf;
    _["obuf"] = obuf;

    _["tmp"] = consume_angle_addr();
    if (!z(_["tmp"])) { return _["tmp"]; }

    buf = _["buf"];
    obuf = _["obuf"];

    _["tmp"] = "";

    _["cfws"] = consume_cfws();
    if (z(_["cfws"])) { _["cfws"] = ""; }
    _["tmp"] = _["tmp"] _["cfws"];

    _["op_angle"] = next_str("<");
    if (z(_["op_angle"])) {
        buf = _["buf"];
        obuf = _["obuf"];
        return 0;
    }
    _["tmp"] = _["tmp"] _["op_angle"];

    _["cfws"] = consume_cfws();
    if (z(_["cfws"])) { _["cfws"] = ""; }
    _["tmp"] = _["tmp"] _["cfws"];

    _["cl_angle"] = next_str(">");
    if (z(_["cl_angle"])) {
        buf = _["buf"];
        obuf = _["obuf"];
        return 0;
    }
    _["tmp"] = _["tmp"] _["cl_angle"];

    _["cfws"] = consume_cfws();
    if (z(_["cfws"])) { _["cfws"] = ""; }
    _["tmp"] = _["tmp"] _["cfws"];


    return _["tmp"];
}

# received-token = word / angle-addr / addr-spec / domain
function consume_received_token(_) {
    _["buf"] = buf;
    _["obuf"] = obuf;

    _["angle_addr"] = consume_angle_addr();
    if (!z(_["angle_addr"])) { return _["angle_addr"]; }

    buf = _["buf"];
    obuf = _["obuf"];

    _["addr_spec"] = consume_addr_spec();
    if (!z(_["addr_spec"])) { return _["addr_spec"]; }

    buf = _["buf"];
    obuf = _["obuf"];

    _["domain"] = consume_domain();
    if (!z(_["domain"])) { return _["domain"]; }

    buf = _["buf"];
    obuf = _["obuf"];

    # XXX: `domain` starts with `word`
    _["word"] = consume_word();
    if (!z(_["word"])) { return _["word"]; }

    buf = _["buf"];
    obuf = _["obuf"];

    return 0;
}

# received = "Received:" *received-token ";" date-time CRLF
function consume_received(_) {
    _["buf"] = buf;
    _["obuf"] = obuf;

    _["tmp"] = "";

    while (1) {
        _["received_token"] = consume_received_token();
        if (z(_["received_token"])) { break; }
        _["tmp"] = _["tmp"] _["received_token"];
    }

    _["semicolon"] = next_str(";");
    if (z(_["semicolon"])) {
        buf = _["buf"];
        obuf = _["obuf"];
        return 0;
    }
    _["tmp"] = _["tmp"] _["semicolon"];

    _["date_time"] = consume_date_time();
    if (z(_["date_time"])) {
        buf = _["buf"];
        obuf = _["obuf"];
        return 0;
    }
    _["tmp"] = _["tmp"] _["date_time"];

    return _["tmp"];
}

# phrase *("," phrase)
function consume_keywords(_) {
    _["buf"] = buf;
    _["obuf"] = obuf;

    _["tmp"] = "";

    while (1) {
        _["phrase"] = consume_phrase();
        if (z(_["phrase"])) {
            buf = _["buf"];
            obuf = _["obuf"];
            return 0;
        }
        _["tmp"] = _["tmp"] _["phrase"];

        _["comma"] = next_str(",");
        if (z(_["comma"])) { break; }
        _["tmp"] = _["tmp"] _["comma"];
    }

    return _["tmp"];
}

function consume(nr, _) {
    _["success"] = 0;

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
        diag(nr ": Parse error: " field);
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
            buf = substr(str, _["idx"] + 1, length(str));
            header_nr = nr;
            return 1;
        }
    }

    diag(nr ": Malformed header line: " str);
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
    consume(NR);
    print SP;  # dismiss last backslash produced by `stack()`
    exit error;
}
