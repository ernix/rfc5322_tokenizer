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
    obuf = obuf quote(key) SP quote(value) SP BS LF;
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
            if (_["token"]) {
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

    return "";
}

function next_arr(array, _i, _) {
    _["buf"] = buf;
    _["obuf"] = obuf;

    for (_i in array) {
        _["tmp"] = next_str(array[_i]);
        if (_["tmp"]) {
            return _["tmp"];
        }
    }

    buf = _["buf"];
    obuf = _["obuf"];
    return "";
}

function _consume_fws(_) {
    _["buf"] = buf;
    _["obuf"] = obuf;

    _["wsp1"] = next_token_arr(arr_wsp);
    _["crlf"] = next_str(CR LF);
    _["wsp2"] = next_token_arr(arr_wsp);

    if (!_["wsp1"] && !_["wsp2"]) {
        buf = _["buf"];
        obuf = _["obuf"];
        return "";
    }

    _["tmp"] = _["wsp1"] _["crlf"] _["wsp2"];
    return _["tmp"];
}

function _consume_obs_fws(_) {
    _["buf"] = buf;
    _["obuf"] = obuf;

    _["tmp"] = next_token_arr(arr_wsp);

    if (!_["tmp"]) {
        buf = _["buf"];
        obuf = _["obuf"];
        return "";
    }

    while (1) {
        _["crlf"] = next_str(CR LF);
        if (!_["crlf"]) { break; }

        _["tmp"] = _["tmp"] _["crlf"];
        _["wsp2"] = next_token_arr(arr_wsp);
        if (!_["wsp2"]) {
            buf = _["buf"];
            obuf = _["obuf"];
            return "";
        }
        _["tmp"] = _["tmp"] _["wsp2"];
    }

    return _["tmp"];
}

function consume_fws(_) {
    _["buf"] = buf;
    _["obuf"] = obuf;

    _["fws"] = _consume_fws();
    if (!_["fws"]) {
        buf = _["buf"];
        obuf = _["obuf"];
        _["fws"] = _consume_obs_fws();
    }

    return _["fws"];
}

function _consume_quoted_pair(_) {
    _["buf"] = buf;
    _["obuf"] = obuf;

    _["tmp"] = next_str(BS);
    if (_["tmp"]) {
        _["tmp2"] = next_arr(arr_vchar);
        if (!_["tmp2"]) {
            _["tmp2"] = next_arr(arr_wsp);
        }

        if (_["tmp2"]) {
            return _["tmp"] _["tmp2"];
        }
    }

    buf = _["buf"];
    obuf = _["obuf"];
    return "";
}

function _consume_obs_qp(_) {
    _["buf"] = buf;
    _["obuf"] = obuf;

    _["tmp"] = next_str(BS);
    if (_["tmp"]) {
        _["nul"] = next_str("\000");
        if (_["nul"]) { return _["tmp"] _["nul"]; }

        _["c"] = next_arr(arr_obs_no_ws_ctl);
        if (_["c"]) { return _["tmp"] _["c"]; }

        _["lf"] = next_str(LF);
        if (_["lf"]) { return _["tmp"] _["lf"]; }

        _["cr"] = next_str(CR);
        if (_["cr"]) { return _["tmp"] _["cr"]; }
    }

    buf = _["buf"];
    obuf = _["obuf"];
    return "";
}

function consume_quoted_pair(_) {
    _["buf"] = buf;
    _["obuf"] = obuf;

    _["tmp"] = _consume_quoted_pair();
    if (!_["tmp"]) {
        buf = _["buf"];
        obuf = _["obuf"];
        _["tmp"] = _consume_obs_qp();
    }

    if (!_["tmp"]) {
        buf = _["buf"];
        obuf = _["obuf"];
        return "";
    }

    return _["tmp"];
}

function consume_ccontent(_) {
    _["buf"] = buf;
    _["obuf"] = obuf;

    _["tmp"] = next_token(ctext);
    if (_["tmp"]) { return _["tmp"]; }

    _["tmp"] = consume_quoted_pair();
    if (_["tmp"]) { return _["tmp"]; }

    _["tmp"] = consume_comment();
    if (_["tmp"]) { return _["tmp"]; }

    buf = _["buf"];
    obuf = _["obuf"];
    return "";
}

function consume_comment(_) {
    _["buf"] = buf;
    _["obuf"] = obuf;

    _["tmp"] = "";

    _["op_brace"] = next_str("(");
    if (!_["op_brace"]) {
        buf = _["buf"];
        obuf = _["obuf"];
        return "";
    }
    _["tmp"] = _["tmp"] _["op_brace"];

    while (1) {
        _["tmp"] = _["tmp"] consume_fws();

        _["ccontent"] = consume_ccontent();
        if (!_["ccontent"]) { break; }
        _["tmp"] = _["tmp"] _["ccontent"];
    }

    _["cl_brace"] = next_str(")");
    if (!_["cl_brace"]) {
        buf = _["buf"];
        obuf = _["obuf"];
        return "";
    }

    return _["tmp"] _["cl_brace"];
}

function consume_cfws(_) {
    _["tmp"] = "";

    while (1) {
        _["tmp"] = _["tmp"] consume_fws();

        _["comment"] = consume_comment();
        if (_["comment"]) {
            stack("comment", _["comment"]);
            _["tmp"] = _["tmp"] _["comment"];
        }
        else {
            break;
        }
    }

    _["tmp"] = _["tmp"] consume_fws();

    return _["tmp"];
}

function consume_day_of_week(_) {
    _["buf"] = buf;
    _["obuf"] = obuf;

    consume_fws();

    _["day_name"] = next_arr(arr_week);
    if (!_["day_name"]) {
        buf = _["buf"];
        obuf = _["obuf"];
        return "";
    }

    stack("day-name", _["day_name"]);
    return _["day_name"];
}

function _consume_day(_) {
    _["buf"] = buf;
    _["obuf"] = obuf;

    consume_fws();

    _["d1"] = next_arr(arr_digit);
    _["d2"] = next_arr(arr_digit);

    # XXX: require fws
    _["fws"] = consume_fws();

    if (!_["d1"] || !_["fws"]) {
        buf = _["buf"];
        obuf = _["obuf"];
        return "";
    }

    stack("day", _["d1"] _["d2"]);
    return _["d1"] _["d2"];
}

function _consume_obs_day(_) {
    _["buf"] = buf;
    _["obuf"] = obuf;

    consume_cfws();

    _["d1"] = next_arr(arr_digit);
    _["d2"] = next_arr(arr_digit);

    consume_cfws();

    if (!_["d1"]) {
        buf = _["buf"];
        obuf = _["obuf"];
        return "";
    }

    _["obs_day"] = _["d1"] _["d2"];

    stack("obs-day", _["obs_day"]);
    return _["obs_day"];
}

function consume_day(_) {
    _["buf"] = buf;
    _["obuf"] = obuf;

    _["day"] = _consume_day();
    if (!_["day"]) {
        buf = _["buf"];
        obuf = _["obuf"];
        _["day"] = _consume_obs_day();
    }

    if (!_["day"]) {
        buf = _["buf"];
        obuf = _["obuf"];
        return "";
    }

    return _["day"];
}

function consume_month(_) {
    _["buf"] = buf;
    _["obuf"] = obuf;

    _["tmp"] = next_arr(arr_month);
    if (!_["tmp"]) {
        buf = _["buf"];
        obuf = _["obuf"];
        return "";
    }

    stack("month", _["tmp"]);
    return _["tmp"];
}

function _consume_year(_) {
    _["buf"] = buf;
    _["obuf"] = obuf;

    _["fws1"] = consume_fws();
    _["d1"] = next_arr(arr_digit);
    _["d2"] = next_arr(arr_digit);
    _["d3"] = next_arr(arr_digit);
    _["d4"] = next_arr(arr_digit);
    _["tmp"] = next_token_arr(arr_digit);
    _["fws2"] = consume_fws();

    if (!_["fws1"] || !_["d1"] || !_["d2"] || !_["d3"] || !_["d4"] || !_["fws2"]) {
        buf = _["buf"];
        obuf = _["obuf"];
        return "";
    }

    _["year"] = _["d1"] _["d2"] _["d3"] _["d4"] _["tmp"];

    stack("year", _["year"]);
    return _["year"];
}

function _consume_obs_year(_) {
    _["buf"] = buf;
    _["obuf"] = obuf;

    consume_cfws();
    _["d1"] = next_arr(arr_digit);
    _["d2"] = next_arr(arr_digit);
    _["rest"] = next_token_arr(arr_digit);
    consume_cfws();

    if (!_["d1"] || !_["d2"]) {
        buf = _["buf"];
        obuf = _["obuf"];
        return "";
    }

    _["obs_year"] = _["d1"] _["d2"] _["rest"];

    stack("obs-year", _["obs_year"]);
    return _["obs_year"];
}

function consume_year(_) {
    _["buf"] = buf;
    _["obuf"] = obuf;

    _["year"] = _consume_year();
    if (!_["year"]) {
        buf = _["buf"];
        obuf = _["obuf"];
        _["year"] = _consume_obs_year();
    }

    if (!_["year"]) {
        buf = _["buf"];
        obuf = _["obuf"];
        return "";
    }

    return _["year"];
}

function consume_date(_) {
    _["buf"] = buf;
    _["obuf"] = obuf;

    _["day"] = consume_day();
    _["month"] = consume_month();
    _["year"] = consume_year();
    if (!_["day"] || !_["month"] || !_["year"]) {
        buf = _["buf"];
        obuf = _["obuf"];
        return "";
    }

    return _["day"] _["month"] _["year"];
}

function _consume_hour(_) {
    _["buf"] = buf;
    _["obuf"] = obuf;

    _["d1"] = next_arr(arr_digit);
    _["d2"] = next_arr(arr_digit);

    if (!_["d1"] || !_["d2"]) {
        buf = _["buf"];
        obuf = _["obuf"];
        return "";
    }

    stack("hour", _["d1"] _["d2"]);
    return _["d1"] _["d2"];
}

function _consume_obs_hour(_) {
    _["buf"] = buf;
    _["obuf"] = obuf;

    consume_cfws();
    _["d1"] = next_arr(arr_digit);
    _["d2"] = next_arr(arr_digit);
    consume_cfws();

    if (!_["d1"] || !_["d2"]) {
        buf = _["buf"];
        obuf = _["obuf"];
        return "";
    }

    _["obs_hour"] = _["d1"] _["d2"];

    stack("obs-hour", _["obs_hour"]);
    return _["obs_hour"];
}

function consume_hour(_) {
    _["buf"] = buf;
    _["obuf"] = obuf;

    _["hour"] = _consume_hour();
    if (!_["hour"]) {
        buf = _["buf"];
        obuf = _["obuf"];
        _["hour"] = _consume_obs_hour();
    }

    if (!_["hour"]) {
        buf = _["buf"];
        obuf = _["obuf"];
        return "";
    }

    return _["hour"];
}

function _consume_minute(_) {
    _["buf"] = buf;
    _["obuf"] = obuf;

    _["d1"] = next_arr(arr_digit);
    _["d2"] = next_arr(arr_digit);

    if (!_["d1"] || !_["d2"]) {
        buf = _["buf"];
        obuf = _["obuf"];
        return "";
    }

    stack("minute", _["d1"] _["d2"]);
    return _["d1"] _["d2"];
}

function _consume_obs_minute(_) {
    _["buf"] = buf;
    _["obuf"] = obuf;

    consume_cfws();
    _["d1"] = next_arr(arr_digit);
    _["d2"] = next_arr(arr_digit);
    consume_cfws();

    if (!_["d1"] || !_["d2"]) {
        buf = _["buf"];
        obuf = _["obuf"];
        return "";
    }

    _["obs_minute"] = _["d1"] _["d2"];

    stack("obs-minute", _["obs_minute"]);
    return _["obs_minute"];
}

function consume_minute(_) {
    _["buf"] = buf;
    _["obuf"] = obuf;

    _["minute"] = _consume_minute();
    if (!_["minute"]) {
        buf = _["buf"];
        obuf = _["obuf"];
        _["minute"] = _consume_obs_minute();
    }

    if (!_["minute"]) {
        buf = _["buf"];
        obuf = _["obuf"];
        return "";
    }

    return _["minute"];
}

function _consume_second(_) {
    _["buf"] = buf;
    _["obuf"] = obuf;

    _["d1"] = next_arr(arr_digit);
    _["d2"] = next_arr(arr_digit);

    if (!_["d1"] || !_["d2"]) {
        buf = _["buf"];
        obuf = _["obuf"];
        return "";
    }

    stack("second", _["d1"] _["d2"]);
    return _["d1"] _["d2"];
}

function _consume_obs_second(_) {
    _["buf"] = buf;
    _["obuf"] = obuf;

    consume_cfws();
    _["d1"] = next_arr(arr_digit);
    _["d2"] = next_arr(arr_digit);
    consume_cfws();

    if (!_["d1"] || !_["d2"]) {
        buf = _["buf"];
        obuf = _["obuf"];
        return "";
    }

    _["obs_second"] = _["d1"] _["d2"];

    stack("obs-second", _["obs_second"]);
    return _["obs_second"];
}

function consume_second(_) {
    _["buf"] = buf;
    _["obuf"] = obuf;

    _["second"] = _consume_second();
    if (!_["second"]) {
        buf = _["buf"];
        obuf = _["obuf"];
        _["second"] = _consume_obs_second();
    }

    if (!_["second"]) {
        buf = _["buf"];
        obuf = _["obuf"];
        return "";
    }

    return _["second"];
}

function _consume_zone(_) {
    _["buf"] = buf;
    _["obuf"] = obuf;

    consume_fws();

    _["sign"] = next_str("+");
    if (!_["sign"]) {
        _["sign"] = next_str("-");
    }

    if (!_["sign"]) {
        buf = _["buf"];
        obuf = _["obuf"];
        return "";
    }

    _["d1"] = next_arr(arr_digit);
    _["d2"] = next_arr(arr_digit);
    _["d3"] = next_arr(arr_digit);
    _["d4"] = next_arr(arr_digit);

    if (!_["d1"] || !_["d2"] || !_["d3"] || !_["d4"]) {
        buf = _["buf"];
        obuf = _["obuf"];
        return "";
    }

    _["zone"] = _["sign"] _["d1"] _["d2"] _["d3"] _["d4"];

    stack("zone", _["zone"]);
    return _["zone"];
}

function _consume_obs_zone(_) {
    _["buf"] = buf;
    _["obuf"] = obuf;

    _["zone"] = next_arr(arr_obs_zone);
    if (!_["zone"]) {
        buf = _["buf"];
        obuf = _["obuf"];
        return "";
    }

    stack("obs-zone", _["zone"]);
    return _["zone"];
}

function consume_zone(_) {
    _["buf"] = buf;
    _["obuf"] = obuf;

    _["tmp"] = _consume_zone();
    if (!_["tmp"]) {
        buf = _["buf"];
        obuf = _["obuf"];
        _["tmp"] = _consume_obs_zone();
    }

    if (!_["tmp"]) {
        buf = _["buf"];
        obuf = _["obuf"];
        return "";
    }

    return _["tmp"];
}

function consume_time_of_day(_) {
    _["buf"] = buf;
    _["obuf"] = obuf;

    _["tmp"] = "";

    _["hour"] = consume_hour();
    if (!_["hour"]) {
        buf = _["buf"];
        obuf = _["obuf"];
        return "";
    }
    _["tmp"] = _["tmp"] _["hour"];

    _["colon1"] = next_str(":");
    if (!_["colon1"]) {
        buf = _["buf"];
        obuf = _["obuf"];
        return "";
    }
    _["tmp"] = _["tmp"] _["colon1"];

    _["minute"] = consume_minute();
    if (!_["minute"]) {
        buf = _["buf"];
        obuf = _["obuf"];
        return "";
    }
    _["tmp"] = _["tmp"] _["minute"];

    _["colon2"] = next_str(":");
    if (_["colon2"]) {
        _["tmp"] = _["tmp"] _["colon2"];
        _["second"] = consume_second();
        if (!_["second"]) {
            buf = _["buf"];
            obuf = _["obuf"];
            return "";
        }
    }

    return _["tmp"];
}

function consume_time(_) {
    _["buf"] = buf;
    _["obuf"] = obuf;

    _["tmp"] = "";

    _["tod"] = consume_time_of_day();
    if (!_["tod"]) {
        buf = _["buf"];
        obuf = _["obuf"];
        return "";
    }
    _["tmp"] = _["tmp"] _["tod"];

    _["zone"] = consume_zone();
    if (!_["zone"]) {
        buf = _["buf"];
        obuf = _["obuf"];
        return "";
    }
    _["tmp"] = _["tmp"] _["zone"];

    return _["tmp"];
}

function consume_date_time(_) {
    _["buf"] = buf;
    _["obuf"] = obuf;

    _["dow"] = consume_day_of_week();
    _["comma"] = "";
    if (_["dow"]) {
        _["comma"] = next_str(",");
        if (!_["comma"]) {
            buf = _["buf"];
            obuf = _["obuf"];
            return "";
        }
    }

    _["date"] = consume_date();
    if (!_["date"]) {
        buf = _["buf"];
        obuf = _["obuf"];
        return "";
    }

    _["time"] = consume_time();
    if (!_["time"]) {
        buf = _["buf"];
        obuf = _["obuf"];
        return "";
    }

    consume_cfws();

    return _["dow"] _["comma"] _["date"] _["time"];
}

function _consume_mailbox_list(_) {
    _["buf"] = buf;
    _["obuf"] = obuf;

    _["tmp"] = "";

    do {
        _["mbox"] = consume_mailbox();
        if (!_["mbox"]) {
            buf = _["buf"];
            obuf = _["obuf"];
            return "";
        }

        _["tmp"] = _["tmp"] _["mbox"];
        _["comma"] = next_str(",");
    } while (_["comma"])

    return _["tmp"];
}

function _consume_obs_mbox_list(_) {
    _["buf"] = buf;
    _["obuf"] = obuf;

    _["tmp"] = "";

    do {
        consume_cfws();
        _["comma"] = next_str(",");
        if (_["comma"]) {
            _["tmp"] = _["tmp"] _["comma"];
        }
    } while (_["comma"])

    _["mbox"] = consume_mailbox();
    if (!_["mbox"]) {
        buf = _["buf"];
        obuf = _["obuf"];
        return "";
    }

    _["tmp"] = _["tmp"] _["mbox"];

    do {
        _["comma"] = next_str(",");
        if (_["comma"]) {
            _["tmp"] = _["tmp"] _["comma"];
        }
        else {
            break;
        }

        _["mbox"] = consume_mailbox();
        if (_["mbox"]) {
            _["tmp"] = _["tmp"] _["mbox"];
        }
        else {
            consume_cfws();
        }
    } while (_["comma"])

    return _["tmp"];
}

function consume_mailbox_list(_) {
    _["buf"] = buf;
    _["obuf"] = obuf;

    _["tmp"] = _consume_mailbox_list();
    if (!_["tmp"]) {
        buf = _["buf"];
        obuf = _["obuf"];
        _["tmp"] = _consume_obs_mbox_list();
    }

    if (!_["tmp"]) {
        buf = _["buf"];
        obuf = _["obuf"];
        return "";
    }

    return _["tmp"];
}

function consume_atom(_) {
    _["buf"] = buf;
    _["obuf"] = obuf;

    _["cfws1"] = consume_cfws();

    _["atom"] = next_token(atext);
    if (!_["atom"]) {
        buf = _["buf"];
        obuf = _["obuf"];
        return "";
    }

    _["cfws2"] = consume_cfws();

    return _["cfws1"] _["atom"] _["cfws2"];
}

function consume_qcontent(_) {
    _["buf"] = buf;
    _["obuf"] = obuf;

    _["tmp"] = next_token(qtext);
    if (!_["tmp"]) {
        buf = _["buf"];
        obuf = _["obuf"];
        _["tmp"] = consume_quoted_pair();
    }

    if (!_["tmp"]) {
        buf = _["buf"];
        obuf = _["obuf"];
        return "";
    }

    return _["tmp"];
}

function consume_quoted_string(_) {
    _["buf"] = buf;
    _["obuf"] = obuf;

    _["tmp"] = ""

    consume_cfws();

    _["DQUOTE"] = next_str(QQ);
    if (!_["DQUOTE"]) {
        buf = _["buf"];
        obuf = _["obuf"];
        return "";
    }
    _["tmp"] = _["tmp"] _["DQUOTE"];

    do {
        _["tmp"] = _["tmp"] consume_fws();

        _["qcontent"] = consume_qcontent();
        if (_["qcontent"]) {
            _["tmp"] = _["tmp"] _["qcontent"];
        }
        else {
            break;
        }
    } while (_["qcontent"])

    _["tmp"] = _["tmp"] consume_fws();

    _["DQUOTE"] = next_str(QQ);
    if (!_["DQUOTE"]) {
        buf = _["buf"];
        obuf = _["obuf"];
        return "";
    }
    _["tmp"] = _["tmp"] _["DQUOTE"];

    consume_cfws();

    return _["tmp"];
}

function consume_word(_) {
    _["buf"] = buf;
    _["obuf"] = obuf;

    _["tmp"] = consume_atom();
    if (!_["tmp"]) {
        buf = _["buf"];
        obuf = _["obuf"];

        _["tmp"] = consume_quoted_string();
    }

    if (!_["tmp"]) {
        buf = _["buf"];
        obuf = _["obuf"];
        return "";
    }

    return _["tmp"];
}

function _consume_phrase(_) {
    _["buf"] = buf;
    _["obuf"] = obuf;

    _["tmp"] = "";
    while (1) {
        _["word"] = consume_word();
        if (!_["word"]) { break; }
        _["tmp"] = _["tmp"] _["word"];
    }

    if (!_["tmp"]) {
        buf = _["buf"];
        obuf = _["obuf"];
        return "";
    }

    # According to 3.2.5, leading/trailing CFWS is a part of `phrase`,
    # but for practical reason these are better to be trimmed.
    stack("phrase", trim(_["tmp"]));
    return _["tmp"];
}

function _consume_obs_phrase(_) {
    _["buf"] = buf;
    _["obuf"] = obuf;

    _["tmp"] = consume_word();
    if (!_["tmp"]) {
        buf = _["buf"];
        obuf = _["obuf"];
        return "";
    }

    while (1) {
        _["rest"] = consume_word();
        if (_["rest"]) {
            _["tmp"] = _["tmp"] _["rest"];
            continue;
        }

        _["rest"] = next_str(".");
        if (_["rest"]) {
            _["tmp"] = _["tmp"] _["rest"];
            continue;
        }

        _["rest"] = consume_cfws();
        if (_["rest"]) {
            _["tmp"] = _["tmp"] _["rest"];
            continue;
        }

        break;
    }

    stack("obs-phrase", trim(_["tmp"]));
    return _["tmp"];
}

function consume_phrase(_) {
    _["buf"] = buf;
    _["obuf"] = obuf;

    _["tmp"] = _consume_phrase();
    if (!_["tmp"]) {
        buf = _["buf"];
        obuf = _["obuf"];
        _["tmp"] = _consume_obs_phrase();
    }

    if (!_["tmp"]) {
        buf = _["buf"];
        obuf = _["obuf"];
        return "";
    }

    return _["tmp"];
}

function consume_display_name(_) {
    _["buf"] = buf;
    _["obuf"] = obuf;

    _["tmp"] = consume_phrase();
    if (!_["tmp"]) {
        buf = _["buf"];
        obuf = _["obuf"];
        return "";
    }

    return _["tmp"];
}

function _consume_angle_addr(_) {
    _["buf"] = buf;
    _["obuf"] = obuf;

    consume_cfws();

    _["op_angle"] = next_str("<");
    _["addr_spec"] = consume_addr_spec();
    _["cl_angle"] = next_str(">");

    if (!_["op_angle"] || !_["addr_spec"] || !_["cl_angle"]) {
        buf = _["buf"];
        obuf = _["obuf"];
        return "";
    }

    _["angle_addr"] = _["op_angle"] _["addr_spec"] _["cl_angle"];

    consume_cfws();

    return _["angle_addr"];
}

function consume_obs_domain_list(_) {
    _["buf"] = buf;
    _["obuf"] = obuf;

    _["tmp"] = "";

    while (1) {
        consume_cfws();
        _["comma"] = next_str(",");
        if (!_["comma"]) { break; }
        _["tmp"] = _["tmp"] _["comma"];
    }

    _["at"] = next_str("@");
    if (_["at"]) {
        buf = _["buf"];
        obuf = _["obuf"];
        return "";
    }
    _["tmp"] = _["tmp"] _["at"];

    _["domain"] = consume_domain();
    if (_["domain"]) {
        buf = _["buf"];
        obuf = _["obuf"];
        return "";
    }
    _["tmp"] = _["tmp"] _["domain"];

    while (1) {
        _["comma"] = next_str(",");
        if (!_["comma"]) { break; }
        _["tmp"] = _["tmp"] _["comma"];

        consume_cfws();

        _["at"] = next_str("@");
        if (!_["at"]) { continue; }
        _["tmp"] = _["tmp"] _["at"];

        _["domain"] = consume_domain();
        if (_["domain"]) {
            buf = _["buf"];
            obuf = _["obuf"];
            return "";
        }
        _["tmp"] = _["tmp"] _["domain"];
    }

    return _["tmp"];
}

function consume_obs_route(_) {
    _["buf"] = buf;
    _["obuf"] = obuf;

    _["obs_domain_list"] = consume_obs_domain_list();
    _["colon"] = next_str(":");

    if (!_["obs_domain_list"] || !_["colon"]) {
        buf = _["buf"];
        obuf = _["obuf"];
        return "";
    }

    return _["obs_domain_list"] _["colon"];
}

function _consume_obs_angle_addr(_) {
    _["buf"] = buf;
    _["obuf"] = obuf;

    consume_cfws();

    _["op_angle"] = next_str("<");
    _["obs_route"] = consume_obs_route();
    _["addr_spec"] = consume_addr_spec();
    _["cl_angle"] = next_str(">");

    if (!_["op_angle"] || !_["obs_route"] || !_["addr_spec"] || !_["cl_angle"]) {
        buf = _["buf"];
        obuf = _["obuf"];
        return "";
    }

    _["obs_angle_addr"] = _["op_angle"] _["obs_route"] _["addr_spec"] _["cl_angle"];

    stack("addr-spec", _["addr_spec"]);
    return _["obs_angle_addr"];
}

function consume_angle_addr(_) {
    _["buf"] = buf;
    _["obuf"] = obuf;

    _["tmp"] = _consume_angle_addr();

    if (!_["tmp"]) {
        buf = _["buf"];
        obuf = _["obuf"];
        _["tmp"] = _consume_obs_angle_addr();
    }

    if (!_["tmp"]) {
        buf = _["buf"];
        obuf = _["obuf"];
        return "";
    }

    return _["tmp"];
}

function consume_name_addr(_) {
    _["buf"] = buf;
    _["obuf"] = obuf;

    _["tmp"] = consume_display_name();

    _["angle_addr"] = consume_angle_addr();
    if(!_["angle_addr"]) {
        buf = _["buf"];
        obuf = _["obuf"];
        return "";
    }

    return _["tmp"] _["angle_addr"];
}

function consume_dot_atom_text(_) {
    _["buf"] = buf;
    _["obuf"] = obuf;

    _["tmp"] = next_token(atext);
    if (!_["tmp"]) {
        buf = _["buf"];
        obuf = _["obuf"];
        return "";
    }

    while (1) {
        _["dot"] = next_str(".");
        if (!_["dot"]) { break; }
        _["tmp"] = _["tmp"] _["dot"];

        _["atext"] = next_token(atext);
        if (!_["atext"]) {
            buf = _["buf"];
            obuf = _["obuf"];
            return "";
        }
        _["tmp"] = _["tmp"] _["atext"];
    }

    return _["tmp"];
}

function consume_dot_atom(_) {
    _["buf"] = buf;
    _["obuf"] = obuf;

    consume_cfws();

    _["dot_atom_text"] = consume_dot_atom_text();
    if (!_["dot_atom_text"]) {
        buf = _["buf"];
        obuf = _["obuf"];
        return "";
    }

    consume_cfws();

    return _["dot_atom_text"];
}

function consume_obs_local_part(_) {
    _["buf"] = buf;
    _["obuf"] = obuf;

    _["tmp"] = consume_word();
    if (!_["tmp"]) {
        buf = _["buf"];
        obuf = _["obuf"];
        return "";
    }

    while (1) {
        _["dot"] = next_str(".");
        if (!_["dot"]) { break; }
        _["tmp"] = _["tmp"] _["dot"];

        _["word"] = consume_word();
        if (!_["word"]) {
            buf = _["buf"];
            obuf = _["obuf"];
            return "";
        }
        _["tmp"] = _["tmp"] _["word"];
    }

    return _["tmp"];
}

function consume_local_part(_) {
    _["buf"] = buf;
    _["obuf"] = obuf;

    _["tmp"] = consume_dot_atom();
    if (_["tmp"]) {
        return _["tmp"];
    }

    buf = _["buf"];
    obuf = _["obuf"];

    _["tmp"] = consume_quoted_string();
    if (_["tmp"]) {
        return _["tmp"];
    }

    buf = _["buf"];
    obuf = _["obuf"];

    _["tmp"] = consume_obs_local_part();
    if (_["tmp"]) {
        return _["tmp"];
    }

    buf = _["buf"];
    obuf = _["obuf"];
    return "";
}

function _consume_dtext(_) {
    _["buf"] = buf;
    _["obuf"] = obuf;

    _["tmp"] = next_token(dtext);
    if (!_["tmp"]) {
        buf = _["buf"];
        obuf = _["obuf"];
        return "";
    }

    return _["tmp"];
}

function _consume_obs_dtext(_) {
    _["buf"] = buf;
    _["obuf"] = obuf;

    _["tmp"] = next_arr(arr_obs_no_ws_ctl);
    if (!_["tmp"]) {
        buf = _["buf"];
        obuf = _["obuf"];
        _["tmp"] = consume_quoted_pair();
    }

    if (!_["tmp"]) {
        buf = _["buf"];
        obuf = _["obuf"];
        return "";
    }

    return _["tmp"];
}

function consume_dtext(_) {
    _["buf"] = buf;
    _["obuf"] = obuf;

    _["tmp"] = _consume_dtext();
    if (!_["tmp"]) {
        buf = _["buf"];
        obuf = _["obuf"];
        _["tmp"] = _consume_obs_dtext();
    }

    if (!_["tmp"]) {
        buf = _["buf"];
        obuf = _["obuf"];
        return "";
    }

    return _["tmp"];
}

function consume_domain_literal(_) {
    _["buf"] = buf;
    _["obuf"] = obuf;

    _["tmp"] = "";

    consume_cfws();

    _["op_bracket"] = next_str("[");
    if (!_["op_bracket"]) {
        buf = _["buf"];
        obuf = _["obuf"];
        return "";
    }
    _["tmp"] = _["tmp"] _["op_bracket"];

    while (1) {
        _["tmp"] = _["tmp"] consume_fws();

        _["dtext"] = consume_dtext();
        if (!_["dtext"]) { break; }
        _["tmp"] = _["tmp"] _["dtext"];
    }

    _["tmp"] = _["tmp"] consume_fws();

    _["cl_bracket"] = next_str("]");
    if (!_["cl_bracket"]) {
        buf = _["buf"];
        obuf = _["obuf"];
        return "";
    }
    _["tmp"] = _["tmp"] _["cl_bracket"];

    consume_cfws();

    return _["tmp"];
}

function consume_obs_domain(_) {
    _["buf"] = buf;
    _["obuf"] = obuf;

    _["tmp"] = consume_atom();
    if (!_["tmp"]) {
        buf = _["buf"];
        obuf = _["obuf"];
        return "";
    }

    while (1) {
        _["dot"] = next_str(".");
        if (!_["dot"]) { break; }
        _["tmp"] = _["tmp"] _["dot"];

        _["atom"] = consume_atom();
        if (!_["atom"]) {
            buf = _["buf"];
            obuf = _["obuf"];
            return "";
        }
        _["tmp"] = _["tmp"] _["atom"];
    }

    return _["tmp"];
}

function consume_domain(_) {
    _["buf"] = buf;
    _["obuf"] = obuf;

    _["tmp"] = consume_dot_atom();
    if (_["tmp"]) {
        return _["tmp"];
    }

    buf = _["buf"];
    obuf = _["obuf"];

    _["tmp"] = consume_domain_literal();
    if (_["tmp"]) {
        return _["tmp"];
    }

    buf = _["buf"];
    obuf = _["obuf"];

    _["tmp"] = consume_obs_domain();
    if (_["tmp"]) {
        return _["tmp"];
    }

    buf = _["buf"];
    obuf = _["obuf"];
    return "";
}

function consume_addr_spec(_) {
    _["buf"] = buf;
    _["obuf"] = obuf;

    _["local_part"] = consume_local_part();
    _["at"] = next_str("@");
    _["domain"] = consume_domain();

    if (!_["local_part"] || !_["at"] || !_["domain"]) {
        buf = _["buf"];
        obuf = _["obuf"];
        return "";
    }

    _["addr_spec"] = _["local_part"] _["at"] _["domain"];

    stack("addr-spec", _["addr_spec"]);
    return _["addr_spec"];
}

function consume_mailbox(_) {
    _["buf"] = buf;
    _["obuf"] = obuf;

    _["tmp"] = consume_name_addr();
    if (!_["tmp"]) {
        buf = _["buf"];
        obuf = _["obuf"];
        _["tmp"] = consume_addr_spec();
    }

    if (!_["tmp"]) {
        buf = _["buf"];
        obuf = _["obuf"];
        return "";
    }

    return _["tmp"];
}

function consume_obs_group_list(_) {
    _["buf"] = buf;
    _["obuf"] = obuf;

    _["tmp"] = "";

    while (1) {
        consume_cfws();
        _["comma"] = next_str(",");
        if (!_["comma"]) { break; }
        _["tmp"] = _["tmp"] _["comma"];
    }

    if (!_["tmp"]) {
        buf = _["buf"];
        obuf = _["obuf"];
        return "";
    }

    consume_cfws();

    return _["tmp"];
}

function consume_group_list(_) {
    _["buf"] = buf;
    _["obuf"] = obuf;

    _["tmp"] = consume_mailbox_list();
    if (_["tmp"]) { return _["tmp"]; }

    _["tmp"] = consume_cfws();
    if (_["tmp"]) { return _["tmp"]; }

    _["tmp"] = consume_obs_group_list();
    if (_["tmp"]) { return _["tmp"]; }

    buf = _["buf"];
    obuf = _["obuf"];
    return "";
}

function consume_group(_) {
    _["buf"] = buf;
    _["obuf"] = obuf;

    _["tmp"] = consume_display_name();
    if (!_["tmp"]) {
        buf = _["buf"];
        obuf = _["obuf"];
        return "";
    }

    _["colon"] = next_str(":");
    _["group_list"] = consume_group_list();
    _["semicolon"] = next_str(";");

    if (!_["colon"] || !_["semicolon"]) {
        buf = _["buf"];
        obuf = _["obuf"];
        return "";
    }

    _["tmp"] = _["tmp"] _["colon"] _["group_list"] _["semicolon"];

    consume_cfws();

    return _["tmp"];
}

function consume_address(_) {
    _["buf"] = buf;
    _["obuf"] = obuf;

    _["tmp"] = consume_mailbox();
    if (!_["tmp"]) {
        buf = _["buf"];
        obuf = _["obuf"];
        _["tmp"] = consume_group();
    }

    if (!_["tmp"]) {
        buf = _["buf"];
        obuf = _["obuf"];
        return "";
    }

    return _["tmp"];
}

function _consume_address_list(_) {
    _["buf"] = buf;
    _["obuf"] = obuf;

    _["tmp"] = consume_address();

    while (1) {
        _["comma"] = next_str(",");
        if (!_["comma"]) { break; }
        _["tmp"] = _["tmp"] _["comma"];

        _["addr"] = consume_address();
        if (!_["addr"]) {
            buf = _["buf"];
            obuf = _["obuf"];
            return "";
        }
        _["tmp"] = _["tmp"] _["addr"];
    }

    return _["tmp"];
}

function _consume_obs_addr_list(_) {
    _["buf"] = buf;
    _["obuf"] = obuf;

    _["tmp"] = "";

    while (1) {
        consume_cfws();
        _["comma"] = next_str(",");
        if (!_["comma"]) { break; }
    }

    _["addr"] = consume_address();
    if (_["addr"]) {
        buf = _["buf"];
        obuf = _["obuf"];
        return "";
    }
    _["tmp"] = _["tmp"] _["addr"];

    while (1) {
        _["comma"] = next_str(",");
        if (!_["comma"]) { break; }
        _["tmp"] = _["tmp"] _["comma"];

        _["addr"] = consume_address();
        if (!_["addr"]) {
            consume_cfws();
            continue;
        }
        _["tmp"] = _["tmp"] _["addr"];
    }

    return _["tmp"];
}

function consume_address_list(_) {
    _["buf"] = buf;
    _["obuf"] = obuf;

    _["tmp"] = _consume_address_list();
    if (!_["tmp"]) {
        buf = _["buf"];
        obuf = _["obuf"];
        _["tmp"] = _consume_obs_addr_list();
    }

    if (!_["tmp"]) {
        buf = _["buf"];
        obuf = _["obuf"];
        return "";
    }

    return _["tmp"];
}

function consume_bcc(_) {
    _["buf"] = buf;
    _["obuf"] = obuf;

    _["tmp"] = consume_address_list();
    if (!_["tmp"]) {
        buf = _["buf"];
        obuf = _["obuf"];
        _["tmp"] = consume_cfws();
    }

    if (!_["tmp"]) {
        buf = _["buf"];
        obuf = _["obuf"];
        return "";
    }

    return _["tmp"];
}

function _consume_obs_id_left(_) {
    _["buf"] = buf;
    _["obuf"] = obuf;

    _["tmp"] = consume_local_part();
    if (!_["tmp"]) {
        buf = _["buf"];
        obuf = _["obuf"];
        return "";
    }

    return _["tmp"];
}

function consume_id_left(_) {
    _["buf"] = buf;
    _["obuf"] = obuf;

    _["tmp"] = consume_dot_atom_text();
    if (!_["tmp"]) {
        buf = _["buf"];
        obuf = _["obuf"];
        _["tmp"] = _consume_obs_id_left();
    }

    if (!_["tmp"]) {
        buf = _["buf"];
        obuf = _["obuf"];
        return "";
    }

    return _["tmp"];
}

function consume_no_fold_literal(_) {
    _["buf"] = buf;
    _["obuf"] = obuf;

    _["op_bracket"] = next_str("[");
    _["dtext"] = next_token(dtext);
    _["cl_bracket"] = next_str("]");

    if (!_["op_bracket"] || !_["dtext"] || !_["cl_bracket"]) {
        buf = _["buf"];
        obuf = _["obuf"];
        return "";
    }

    return _["op_bracket"] _["dtext"] _["cl_bracket"];
}

function _consume_obs_id_right(_) {
    _["buf"] = buf;
    _["obuf"] = obuf;

    _["tmp"] = consume_domain();
    if (!_["tmp"]) {
        buf = _["buf"];
        obuf = _["obuf"];
        return "";
    }

    return _["tmp"];
}

function consume_id_right(_) {
    _["buf"] = buf;
    _["obuf"] = obuf;

    _["tmp"] = consume_dot_atom_text();
    if (!_["tmp"]) {
        buf = _["buf"];
        obuf = _["obuf"];
        _["tmp"] = consume_no_fold_literal();
    }

    if (!_["tmp"]) {
        buf = _["buf"];
        obuf = _["obuf"];
        _["tmp"] = _consume_obs_id_right();
    }


    if (!_["tmp"]) {
        buf = _["buf"];
        obuf = _["obuf"];
        return "";
    }

    return _["tmp"];
}

function consume_msg_id(_) {
    _["buf"] = buf;
    _["obuf"] = obuf;

    consume_cfws();

    _["op_angle"] = next_str("<");
    _["id_left"] = consume_id_left();
    _["at"] = next_str("@");
    _["id_right"] = consume_id_right();
    _["cl_angle"] = next_str(">");

    if ( !_["op_angle"] || !_["id_left"] || !_["at"] || !_["id_right"] || !_["cl_angle"]) {
        buf = _["buf"];
        obuf = _["obuf"];
        return "";
    }

    _["msg_id"] = _["id_left"] _["at"] _["id_right"];

    consume_cfws();

    stack("msg-id", _["msg_id"]);
    return _["op_angle"] _["msg_id"] _["cl_angle"];
}

function consume_references(_) {
    _["buf"] = buf;
    _["obuf"] = obuf;

    _["tmp"] = "";

    while (1) {
        _["msg_id"] = consume_msg_id();
        if (!_["msg_id"]) { break; }
        _["tmp"] = _["tmp"] _["msg_id"];
    }

    if (!_["tmp"]) {
        buf = _["buf"];
        obuf = _["obuf"];
        return "";
    }

    return _["tmp"];
}

function consume_path(_) {
    _["buf"] = buf;
    _["obuf"] = obuf;

    _["tmp"] = consume_angle_addr();
    if (_["tmp"]) {
        return _["tmp"];
    }

    buf = _["buf"];
    obuf = _["obuf"];

    consume_cfws();
    _["op_angle"] = next_str("<");
    consume_cfws();
    _["cl_angle"] = next_str(">");
    consume_cfws();

    if (!_["op_angle"] || !_["cl_angle"]) {
        buf = _["buf"];
        obuf = _["obuf"];
        return "";
    }

    return _["op_angle"] _["cl_angle"];
}

function consume_received_token(_) {
    _["buf"] = buf;
    _["obuf"] = obuf;

    _["angle_addr"] = consume_angle_addr();
    if (_["angle_addr"]) { return _["angle_addr"]; }

    buf = _["buf"];
    obuf = _["obuf"];

    _["addr_spec"] = consume_addr_spec();
    if (_["addr_spec"]) { return _["addr_spec"]; }

    buf = _["buf"];
    obuf = _["obuf"];

    _["domain"] = consume_domain();
    if (_["domain"]) { return _["domain"]; }

    buf = _["buf"];
    obuf = _["obuf"];

    # XXX: `domain` starts with `word`
    _["word"] = consume_word();
    if (_["word"]) { return _["word"]; }

    buf = _["buf"];
    obuf = _["obuf"];

    return "";
}

function consume_received(_) {
    _["buf"] = buf;
    _["obuf"] = obuf;

    _["tmp"] = "";

    while (1) {
        _["received_token"] = consume_received_token();
        if (!_["received_token"]) { break; }
        _["tmp"] = _["tmp"] _["received_token"];
    }

    _["semicolon"] = next_str(";");
    if (!_["semicolon"]) {
        buf = _["buf"];
        obuf = _["obuf"];
        return "";
    }
    _["tmp"] = _["tmp"] _["semicolon"];

    _["date_time"] = consume_date_time();
    if (!_["date_time"]) {
        buf = _["buf"];
        obuf = _["obuf"];
        return "";
    }
    _["tmp"] = _["tmp"] _["date_time"];

    return _["tmp"];
}

function consume(_) {
    _["known_header"] = 1;

    if (field == "Date") { consume_date_time(); }
    else if (field == "From") { consume_mailbox_list(); }
    else if (field == "Sender") { consume_mailbox(); }
    else if (field == "Reply-To") { consume_address_list(); }
    else if (field == "To") { consume_address_list(); }
    else if (field == "Cc") { consume_address_list(); }
    else if (field == "Bcc") { consume_bcc(); }
    else if (field == "Message-ID") { consume_msg_id(); }
    else if (field == "References") { consume_references(); }
    else if (field == "Recent-Date") { consume_date_time(); }
    else if (field == "Recent-From") { consume_mailbox_list(); }
    else if (field == "Recent-Sender") { consume_mailbox(); }
    else if (field == "Recent-To") { consume_address_list(); }
    else if (field == "Recent-Cc") { consume_address_list(); }
    else if (field == "Recent-Bcc") { consume_bcc(); }
    else if (field == "Recent-Message-ID") { consume_msg_id(); }
    else if (field == "Return-Path") { consume_path(); }
    else if (field == "Received") { consume_received(); }
    else { _["known_header"] = 0; }

    if (buf && _["known_header"]) { error = 1; }
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
            consume();
        }

        field = substr(str, 1, _["idx"] - 1);
        if (within(field, ftext)) {
            stack("field-name", field);
            flush();
            buf = substr(str, _["idx"] + 1, length(str));
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
    consume();
    print SP;  # dismiss last backslash produced by `stack()`
    exit error;
}
