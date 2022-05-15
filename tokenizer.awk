#!/usr/bin/awk

BEGIN {
    Q = "\047";
    QQ = "\042";
    BS = "\134";
    CRLF = "\r\n";

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

    split("Mon Tue Wed Thu Fri Sat Sun", arr_week, " ");
    split("Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec", arr_month, " ");
    split("\t| ", arr_wsp, "|");
    split("0123456789", arr_digit, "");
    split("UT GMT EST EDT CST CDT MST MDT PST PDT", arr_obs_zone, " ");

    field = "";
    buf = "";
    error = 0;
}

function diag(str) {
    print str > "/dev/stderr";
}

function diag_expect(name) {
    error = 1;
    diag("Expect " name ": " buf);
}

function quote(str) {
    gsub(Q, Q BS Q Q, str);
    return Q str Q;
}

function output(key, value) {
    print quote(key), quote(value), BS;
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
    _["wsp1"] = next_token_arr(arr_wsp);
    _["crlf"] = next_str(CRLF);
    _["wsp2"] = next_token_arr(arr_wsp);
    if (!_["wsp1"] && !_["wsp2"]) {
        buf = _["buf"];
        return "";
    }

    _["tmp"] = _["wsp1"] _["crlf"] _["wsp2"];
    return _["tmp"];
}

function _consume_obs_fws(_) {
    _["buf"] = buf;

    _["tmp"] = next_token_arr(arr_wsp);
    if (!_["tmp"]) {
        buf = _["buf"];
        return "";
    }

    while (1) {
        _["crlf"] = next_str(CRLF);
        if (!_["crlf"]) { break; }

        _["tmp"] = _["tmp"] _["crlf"]
        _["wsp2"] = next_token_arr(arr_wsp);
        if (!_["wsp2"]) {
            buf = _["buf"];
            return "";
        }
        _["tmp"] = _["tmp"] _["wsp2"];
    }

    return _["tmp"];
}

function consume_fws(_) {
    _["buf"] = buf;
    _["fws"] = _consume_fws();
    if (!_["fws"]) {
        buf = _["buf"];
        _["fws"] = _consume_obs_fws();
    }

    return _["fws"];
}

function _consume_quoted_pair(_) {
    _["buf"] = buf;
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
    return "";
}

function _consume_obs_qp(_) {
    _["buf"] = buf;
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
    return "";
}

function consume_quoted_pair(_) {
    _["tmp"] = _consume_quoted_pair();
    if (!_["tmp"]) {
        _["tmp"] = _consume_obs_qp();
    }

    return _["tmp"];
}

function consume_ccontent(_) {
    _["tmp"] = next_token(ctext);
    if (_["tmp"]) { return _["tmp"]; }

    _["tmp"] = consume_quoted_pair();
    if (_["tmp"]) { return _["tmp"]; }

    _["tmp"] = consume_comment();
    if (_["tmp"]) { return _["tmp"]; }

    return "";
}

function consume_comment(_) {
    _["tmp"] = "";

    _["op_brace"] = next_str("(");
    if (!_["op_brace"]) { return ""; }
    _["tmp"] = _["tmp"] _["op_brace"];

    while (1) {
        _["tmp"] = _["tmp"] consume_fws();
        _["ccontent"] = consume_ccontent();
        if (!_["ccontent"]) { break; }
        _["tmp"] = _["tmp"] _["ccontent"];
    }

    _["cl_brace"] = next_str(")");
    if (!_["cl_brace"]) { return ""; }
    _["tmp"] = _["tmp"] _["cl_brace"];

    return _["tmp"];
}

function consume_cfws(_) {
    _["buf"] = buf;
    _["tmp"] = "";

    while (1) {
        _["tmp"] = _["tmp"] consume_fws();
        _["comment"] = consume_comment();
        if (!_["comment"]) {
            break;
        }
        _["tmp"] = _["tmp"] _["comment"];
    }

    _["fws"] = consume_fws();
    _["tmp"] = _["tmp"] _["fws"];

    if (_["tmp"]) {
        output("cfws", _["tmp"]);
    }

    return _["tmp"];
}

function consume_day_of_week(_) {
    _["buf"] = buf;
    _["fws"] = consume_fws();
    _["day_name"] = next_arr(arr_week);

    if (!_["day_name"]) {
        diag_expect("([FWS] day-name)");
        return "";
    }

    _["tmp"] = _["fws"] _["day_name"];
    output("day-name", _["tmp"]);
    return _["tmp"];

}

function _consume_day(_) {
    _["buf"] = buf;
    _["fws1"] = consume_fws();
    _["d1"] = next_arr(arr_digit);
    _["d2"] = next_arr(arr_digit);
    _["fws2"] = consume_fws();

    if (!_["d1"] || !_["fws2"]) {
        buf = _["buf"];
        return "";
    }

    return _["fws1"] _["d1"] _["d2"] _["fws2"];
}

function _consume_obs_day(_) {
    _["buf"] = buf;
    _["cfws1"] = consume_cfws();
    _["d1"] = next_arr(arr_digit);
    _["d2"] = next_arr(arr_digit);
    _["cfws2"] = consume_cfws();

    if (!_["d1"]) {
        buf = _["buf"];
        return "";
    }

    return _["cfws1"] _["d1"] _["d2"] _["cfws2"];
}

function consume_day(_) {
    _["buf"] = buf;
    _["day"] = _consume_day();
    if (!_["day"]) {
        buf = _["buf"];
        _["day"] = _consume_obs_day();
    }

    if (!_["day"]) {
        diag_expect("([FWS] 1*2DIGIT FWS) / obs-day");
        return "";
    }

    output("day", _["day"]);
    return _["day"];
}

function consume_month(_) {
    _["tmp"] = next_arr(arr_month);
    if (!_["tmp"]) {
        diag_expect("month");
        return "";
    }

    output("month", _["tmp"]);
    return _["tmp"];
}

function _consume_year(_) {
    _["buf"] = buf;
    _["fws1"] = consume_fws();
    _["d1"] = next_arr(arr_digit);
    _["d2"] = next_arr(arr_digit);
    _["d3"] = next_arr(arr_digit);
    _["d4"] = next_arr(arr_digit);
    _["tmp"] = next_token_arr(arr_digit);
    _["fws2"] = consume_fws();

    if (!_["fws1"] || !_["d1"] || !_["d2"] || !_["d3"] || !_["d4"] || !_["fws2"]) {
        buf = _["buf"];
        return "";
    }

    return _["fws1"] _["d1"] _["d2"] _["d3"] _["d4"] _["tmp"] _["fws2"];
}

function _consume_obs_year(_) {
    _["buf"] = buf;
    _["cfws1"] = consume_cfws();
    _["d1"] = next_arr(arr_digit);
    _["d2"] = next_arr(arr_digit);
    _["tmp"] = next_token_arr(arr_digit);
    _["cfws2"] = consume_cfws();

    if (!_["d1"] || !_["d2"]) {
        buf = _["buf"];
        return "";
    }

    return _["fws1"] _["d1"] _["d2"] _["tmp"] _["fws2"];
}

function consume_year(_) {
    _["buf"] = buf;

    _["year"] = _consume_year();
    if (!_["year"]) {
        _["year"] = _consume_obs_year();
    }

    if (!_["year"]) {
        buf = _["buf"];
        diag_expect("(FWS 4*DIGIT FWS)");
        return "";
    }

    output("year", _["year"]);
    return _["year"];
}

function consume_date(_) {
    _["day"] = consume_day();
    if (!_["day"]) { return ""; }

    _["month"] = consume_month();
    if (!_["month"]) { return ""; }

    _["year"] = consume_year();
    if (!_["year"]) { return ""; }

    return _["day"] _["month"] _["year"];
}

function _consume_hour(_) {
    _["d1"] = next_arr(arr_digit);
    _["d2"] = next_arr(arr_digit);

    if (!_["d1"] || !_["d2"]) {
        return "";
    }

    return _["d1"] _["d2"];
}

function _consume_obs_hour(_) {
    _["cfws1"] = consume_cfws();
    _["d1"] = next_arr(arr_digit);
    _["d2"] = next_arr(arr_digit);
    _["cfws2"] = consume_cfws();

    if (!_["d1"] || !_["d2"]) {
        return "";
    }

    return _["cfws1"] _["d1"] _["d2"] _["cfws2"];
}

function consume_hour(_) {
    _["buf"] = buf;
    _["hour"] = _consume_hour();
    if (!_["hour"]) {
        buf = _["buf"];
        _["hour"] = _consume_obs_hour();
    }

    if (_["hour"]) {
        return _["hour"];
    }

    buf = _["buf"];
    diag_expect("2DIGIT / obs-hour");
    return "";
}

function _consume_minute(_) {
    _["d1"] = next_arr(arr_digit);
    _["d2"] = next_arr(arr_digit);

    if (!_["d1"] || !_["d2"]) {
        return "";
    }

    return _["d1"] _["d2"];
}

function _consume_obs_minute(_) {
    _["cfws1"] = consume_cfws();
    _["d1"] = next_arr(arr_digit);
    _["d2"] = next_arr(arr_digit);
    _["cfws2"] = consume_cfws();

    if (!_["d1"] || !_["d2"]) {
        return "";
    }

    return _["cfws1"] _["d1"] _["d2"] _["cfws2"];
}

function consume_minute(_) {
    _["buf"] = buf;
    _["minute"] = _consume_minute();
    if (!_["minute"]) {
        buf = _["buf"];
        _["minute"] = _consume_obs_minute();
    }

    if (_["minute"]) {
        return _["minute"];
    }

    buf = _["buf"];
    diag_expect("2DIGIT / obs-minute");
    return "";
}

function _consume_second(_) {
    _["d1"] = next_arr(arr_digit);
    _["d2"] = next_arr(arr_digit);

    if (!_["d1"] || !_["d2"]) {
        return "";
    }

    return _["d1"] _["d2"];
}

function _consume_obs_second(_) {
    _["cfws1"] = consume_cfws();
    _["d1"] = next_arr(arr_digit);
    _["d2"] = next_arr(arr_digit);
    _["cfws2"] = consume_cfws();

    if (!_["d1"] || !_["d2"]) {
        return "";
    }

    return _["cfws1"] _["d1"] _["d2"] _["cfws2"];
}

function consume_second(_) {
    _["buf"] = buf;
    _["second"] = _consume_second();
    if (!_["second"]) {
        buf = _["buf"];
        _["second"] = _consume_obs_second();
    }

    if (_["second"]) {
        return _["second"];
    }

    buf = _["buf"];
    diag_expect("2DIGIT / obs-second");
    return "";
}

function _consume_zone(_) {
    _["tmp"] = consume_fws();

    _["tmp2"] = next_str("+");
    if (!_["tmp2"]) {
        _["tmp2"] = next_str("-");
    }

    if (!_["tmp2"]) { return ""; }
    _["tmp"] = _["tmp"] _["tmp2"];

    _["d1"] = next_arr(arr_digit);
    _["d2"] = next_arr(arr_digit);
    _["d3"] = next_arr(arr_digit);
    _["d4"] = next_arr(arr_digit);

    if (!_["d1"] || !_["d2"] || !_["d3"] || !_["d4"]) {
        return "";
    }

    return _["tmp"] _["d1"] _["d2"] _["d3"] _["d4"];
}

function _consume_obs_zone() {
    return next_arr(arr_obs_zone);
}

function consume_zone(_) {
    _["buf"] = buf;
    _["tmp"] = _consume_zone();
    if (!_["tmp"]) {
        _["tmp"] = _consume_obs_zone();
    }

    if (!_["tmp"]) {
        buf = _["buf"];
        diag_expect("(FWS ( " QQ "+" QQ " / " QQ "-" QQ " ) 4DIGIT) / obs-zone");
        return "";
    }

    output("zone", _["tmp"]);
    return _["tmp"];
}

function consume_time_of_day(_) {
    _["tmp"] = "";

    _["hour"] = consume_hour();
    if (!_["hour"]) { return ""; }
    _["tmp"] = _["tmp"] _["hour"];

    _["colon1"] = next_str(":");
    if (!_["colon1"]) {
        diag_expect("colon");
        return "";
    }
    _["tmp"] = _["tmp"] _["colon1"];

    _["minute"] = consume_minute();
    if (!_["minute"]) { return ""; }
    _["tmp"] = _["tmp"] _["minute"];

    _["colon2"] = next_str(":");
    if (_["colon2"]) {
        _["tmp"] = _["tmp"] _["colon2"];
        _["second"] = consume_second();
        if (!_["second"]) {
            return "";
        }
    }

    return _["tmp"];
}

function consume_time(_) {
    _["tmp"] = "";

    _["tod"] = consume_time_of_day();
    if (!_["tod"]) { return ""; }
    _["tmp"] = _["tmp"] _["tod"];

    _["zone"] = consume_zone();
    if (!_["zone"]) { return ""; }
    _["tmp"] = _["tmp"] _["zone"];

    return _["tmp"];
}

function consume_date_time(_) {
    _["dow"] = consume_day_of_week();
    _["comma"] = "";
    if (_["dow"]) {
        _["comma"] = next_str(",");
        if (_["comma"]) {
            output("comma", _["comma"]);
        }
        else {
            diag_expect("comma");
            return "";
        }
    }

    _["date"] = consume_date();
    if (!_["date"]) { return ""; }

    _["time"] = consume_time();
    if (!_["time"]) { return ""; }

    return _["dow"] _["comma"] _["date"] _["time"] consume_cfws();
}

function consume() {
    if (field == "Date") { consume_date_time(); }
    else if (field == "Recent-Date") { consume_date_time(); }

    if (buf) {
        output("unstructured", buf);
        buf = "";
    }

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
            buf = substr(str, _["idx"] + 1, length(str));
            output("field-name", field);
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
    print " ";  # dismiss last backslash produced by `output()`
    exit error;
}
