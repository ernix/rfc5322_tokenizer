#!/usr/bin/awk

BEGIN {
    Q = "\047";
    QQ = "\042";
    BS = "\134";
    LF = "\n";
    CRLF = "\r\n";
    SP = " ";

    VCHAR = "!" QQ \
        "#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[" \
        BS "]^_`abcdefghijklmnopqrstuvwxyz{|}~";

    split(VCHAR, arr_vchar, "");

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

    split("Mon Tue Wed Thu Fri Sat Sun", arr_week, " ");
    split("Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec", arr_month, " ");
    split("\t| ", arr_wsp, "|");
    split("0123456789", arr_digit, "");
    split("UT GMT EST EDT CST CDT MST MDT PST PDT", arr_obs_zone, " ");

    field = "";
    buf = "";
    obuf = "";
    error = 0;
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

    return "";
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
    for (_i in array) {
        _["tmp"] = next_str(array[_i]);
        if (_["tmp"]) {
            return _["tmp"];
        }
    }

    return "";
}

function _consume_fws(_) {
    _["buf"] = buf;
    _["obuf"] = obuf;

    _["wsp1"] = next_token_arr(arr_wsp);
    _["crlf"] = next_str(CRLF);
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
        _["crlf"] = next_str(CRLF);
        if (!_["crlf"]) { break; }

        _["tmp"] = _["tmp"] _["crlf"]
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

        _["lf"] = next_str("\n");
        if (_["lf"]) { return _["tmp"] _["lf"]; }

        _["cr"] = next_str("\r");
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
        consume_fws();

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
        }
        else {
            break;
        }
        #_["tmp"] = _["tmp"] _["comment"];
    }

    _["tmp"] = _["tmp"] consume_fws();

    return _["tmp"];
}

function consume_day_of_week(_) {
    _["buf"] = buf;
    _["obuf"] = obuf;

    consume_fws();

    _["day_name"] = next_arr(arr_week);

    if (_["day_name"]) {
        stack("day-name", _["day_name"]);
    }
    else {
        buf = _["buf"];
        obuf = _["obuf"];
        return "";
    }

    return _["day_name"];

}

function _consume_day(_) {
    _["buf"] = buf;
    _["obuf"] = obuf;

    consume_fws();

    _["d1"] = next_arr(arr_digit);
    _["d2"] = next_arr(arr_digit);

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

    stack("obs-day", _["d1"] _["d2"]);
    return _["d1"] _["d2"];
}

function consume_day(_) {
    _["buf"] = buf;
    _["obuf"] = obuf;

    _["day"] = _consume_day();
    if (!_["day"]) {
        buf = _["buf"];
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
    _["tmp"] = next_arr(arr_month);
    if (!_["tmp"]) {
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

    stack("year", _["d1"] _["d2"] _["d3"] _["d4"] _["tmp"]);
    return _["d1"] _["d2"] _["d3"] _["d4"] _["tmp"];
}

function _consume_obs_year(_) {
    _["buf"] = buf;
    _["obuf"] = obuf;

    _["cfws1"] = consume_cfws();
    _["d1"] = next_arr(arr_digit);
    _["d2"] = next_arr(arr_digit);
    _["tmp"] = next_token_arr(arr_digit);
    _["cfws2"] = consume_cfws();

    if (!_["d1"] || !_["d2"]) {
        buf = _["buf"];
        obuf = _["obuf"];
        return "";
    }

    stack("obs-year", _["d1"] _["d2"] _["tmp"]);
    return _["fws1"] _["d1"] _["d2"] _["tmp"] _["fws2"];
}

function consume_year(_) {
    _["buf"] = buf;
    _["obuf"] = obuf;

    _["year"] = _consume_year();
    if (!_["year"]) {
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

    _["cfws1"] = consume_cfws();
    _["d1"] = next_arr(arr_digit);
    _["d2"] = next_arr(arr_digit);
    _["cfws2"] = consume_cfws();

    if (!_["d1"] || !_["d2"]) {
        buf = _["buf"];
        obuf = _["obuf"];
        return "";
    }

    stack("obs-hour", _["d1"] _["d2"]);
    return _["cfws1"] _["d1"] _["d2"] _["cfws2"];
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

    if (_["hour"]) {
        return _["hour"];
    }

    buf = _["buf"];
    obuf = _["obuf"];
    return "";
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

    _["cfws1"] = consume_cfws();
    _["d1"] = next_arr(arr_digit);
    _["d2"] = next_arr(arr_digit);
    _["cfws2"] = consume_cfws();

    if (!_["d1"] || !_["d2"]) {
        buf = _["buf"];
        obuf = _["obuf"];
        return "";
    }

    stack("obs-minute", _["d1"] _["d2"]);
    return _["cfws1"] _["d1"] _["d2"] _["cfws2"];
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

    if (_["minute"]) {
        return _["minute"];
    }

    buf = _["buf"];
    obuf = _["obuf"];
    return "";
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

    _["cfws1"] = consume_cfws();
    _["d1"] = next_arr(arr_digit);
    _["d2"] = next_arr(arr_digit);
    _["cfws2"] = consume_cfws();

    if (!_["d1"] || !_["d2"]) {
        buf = _["buf"];
        obuf = _["obuf"];
        return "";
    }

    stack("obs-second", _["d1"] _["d2"]);
    return _["cfws1"] _["d1"] _["d2"] _["cfws2"];
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

    if (_["second"]) {
        return _["second"];
    }

    buf = _["buf"];
    obuf = _["obuf"];
    return "";
}

function _consume_zone(_) {
    _["buf"] = buf;
    _["obuf"] = obuf;

    _["tmp"] = "";

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

    _["tmp"] = _["tmp"] _["sign"];

    _["d1"] = next_arr(arr_digit);
    _["d2"] = next_arr(arr_digit);
    _["d3"] = next_arr(arr_digit);
    _["d4"] = next_arr(arr_digit);

    if (!_["d1"] || !_["d2"] || !_["d3"] || !_["d4"]) {
        buf = _["buf"];
        obuf = _["obuf"];
        return "";
    }

    stack("zone", _["sign"] _["d1"] _["d2"] _["d3"] _["d4"]);
    return _["tmp"] _["d1"] _["d2"] _["d3"] _["d4"];
}

function _consume_obs_zone(_) {
    _["zone"] = next_arr(arr_obs_zone);
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

    return _["dow"] _["comma"] _["date"] _["time"] consume_cfws();
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
        _["tmp"] = _["tmp"] consume_cfws();
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
            _["tmp"] = _["tmp"] consume_cfws();
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

    _["tmp"] = consume_cfws();

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

    _["tmp"] = _["tmp"] = consume_cfws();

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
    do {
        _["word"] = consume_word();
        if (!_["word"]) { break; }
        _["tmp"] = _["tmp"] _["word"];
    } while (1)

    if (!_["tmp"]) {
        buf = _["buf"];
        obuf = _["obuf"];
        return "";
    }

    stack("phrase", _["tmp"]);
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
            continue;
        }

        if (!_["rest"]) { break; }
    }

    stack("obs-phrase", _["tmp"]);
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

    _["tmp"] = consume_cfws();

    _["op_angle"] = next_str("<");
    _["addr_spec"] = consume_addr_spec();
    _["cl_angle"] = next_str(">");

    if (!_["op_angle"] || !_["addr_spec"] || !_["cl_angle"]) {
        buf = _["buf"];
        obuf = _["obuf"];
        return "";
    }

    _["tmp"] = _["tmp"] _["op_angle"] _["addr_spec"] _["cl_angle"];

    _["tmp"] = _["tmp"] consume_cfws();

    stack("addr-spec", _["addr_spec"]);
    return _["tmp"];
}

function consume_obs_domain_list(_) {
    # TODO:
}

function consume_obs_route(_) {
    consume_obs_domain_list();
    next_str(":");
    # TODO:
}

function _consume_obs_angle_addr(_) {
    _["buf"] = buf;
    _["obuf"] = obuf;

    _["tmp"] = consume_cfws();

    _["op_angle"] = next_str("<");
    _["obs_route"] = consume_obs_route();
    _["addr_spec"] = consume_addr_spec();
    _["cl_angle"] = next_str(">");

    if (!_["op_angle"] || !_["obs_route"] || !_["addr_spec"] || !_["cl_angle"]) {
        buf = _["buf"];
        obuf = _["obuf"];
        return "";
    }

    _["tmp"] = _["tmp"] _["op_angle"] _["obs_route"] _["addr_spec"] _["cl_angle"];

    stack("addr-spec", _["addr_spec"]);
    return _["tmp"];
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

    _["tmp"] = "";

    consume_cfws();

    _["dot_atom_text"] = consume_dot_atom_text();
    if (!_["dot_atom_text"]) {
        buf = _["buf"];
        obuf = _["obuf"];
        return "";
    }
    _["tmp"] = _["tmp"] _["dot_atom_text"];

    consume_cfws();

    return _["tmp"];
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
        consume_fws();

        _["dtext"] = consume_dtext();
        if (!_["dtext"]) { break; }
        _["tmp"] = _["tmp"] _["dtext"];
    }

    consume_fws();

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

    return _["local_part"] _["at"] _["domain"];
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

    _["tmp"] = _["tmp"] consume_cfws();

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

function consume_bcc() {
    # TODO:
}

function consume_msg_id() {
    # TODO:
}

function consume_references() {
    # TODO:
}

function consume_path() {
    # TODO:
}

function consume_received() {
    # TODO:
}

function consume() {
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
        buf = buf CRLF str
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
    return;
}

/^$/ { exit; }  # end of header
{ main(NR, $0); }
END {
    consume();
    print " ";  # dismiss last backslash produced by `stack()`
    exit error;
}
