use std

def get_data_length [time_size: int]: record -> int {
    let header = $in
    let data_len = 0
    let data_len = $data_len + $header.time_cnt * $time_size
    let data_len = $data_len + $header.time_cnt
    let data_len = $data_len + $header.type_cnt * 6
    let data_len = $data_len + $header.char_cnt
    let data_len = $data_len + $header.leap_cnt * ($time_size + 4)
    let data_len = $data_len + $header.is_std_cnt
    let data_len = $data_len + $header.is_ut_cnt
    $data_len
}

def parse_header []: binary -> record {
    let unparsed = $in
    let initial_length = $unparsed | bytes length
    mut header = {}
    $header.magic = ($unparsed | bytes at ..<4 | decode 'utf-8')
    std assert equal $header.magic 'TZif' 'Expected TZif magic at header begin'
    let unparsed = ($unparsed | bytes at 4..)
    $header.version = ($unparsed | bytes at ..<1 | decode 'utf-8' | if $in == (char --integer 0) { 1 } else { $in | into int })
    std assert ($header.version in [1, 2, 3]) 'Expected version 1, 2 or 3'
    let unparsed = ($unparsed | bytes at 1..)
    let unparsed = ($unparsed | bytes at 15..) # fifteen unused "reserved" bytes
    let header = (['is_ut_cnt', 'is_std_cnt', 'leap_cnt', 'time_cnt', 'type_cnt', 'char_cnt']
        | enumerate | reduce --fold $header {|v, acc|
            $acc | insert $v.item ($unparsed | bytes at ($v.index * 4)..<(($v.index + 1) * 4) | into int --endian big)
        }
    )
    std assert ($header.is_ut_cnt in [0, $header.type_cnt]) 'Expected is_ut_cnt to be equal to 0 or type_cnt'
    std assert ($header.is_std_cnt in [0, $header.type_cnt]) 'Expected is_std_cnt to be equal to 0 or type_cnt'
    let unparsed = ($unparsed | bytes at (6 * 4)..)

    {
        header: $header,
        header_len: ($initial_length - ($unparsed | bytes length))
    }
}

def parse_body [header: record, time_size: int]: binary -> record {
    let unparsed = $in
    let initial_length = $unparsed | bytes length
    mut body = {}
    $body.transition_times = (..<($header.time_cnt) | each {|i|
        $unparsed | bytes at ($i * $time_size)..<($i * $time_size + $time_size) | into int --endian big --signed
    })
    let unparsed = ($unparsed | bytes at ($header.time_cnt * $time_size)..)
    $body.tt_type_map = (..<($header.time_cnt) | each {|i|
        $unparsed | bytes at ($i)..<(($i + 1)) | into int
    })
    let unparsed = ($unparsed | bytes at ($header.time_cnt)..)
    $body.tt_info = (..<($header.type_cnt) | each {|i|
        {
            ut_off: ($unparsed | bytes at ($i * 6)..<($i * 6 + 4) | into int --endian big --signed),
            is_dst: ($unparsed | bytes at ($i * 6 + 4)..<($i * 6 + 5) | into int | $in > 0),
            desig_idx: ($unparsed | bytes at ($i * 6 + 5)..<($i * 6 + 6) | into int)
        }
    })
    let unparsed = ($unparsed | bytes at ($header.type_cnt * 6)..)
    $body.desigs_bytes = ($unparsed | bytes at ..($header.char_cnt))
    let unparsed = ($unparsed | bytes at ($header.char_cnt)..)
    $body.leap_seconds = (..<($header.leap_cnt) | each {|i|
        {
            leap_time: ($unparsed | bytes at ($i * ($time_size + 4))..<($i * ($time_size + 4) + $time_size) | into int --endian big),
            correction: (($unparsed | bytes at ($i * ($time_size + 4) + $time_size)..<($i * ($time_size + 4) + $time_size + 4)) | into int --endian big --signed)
        }
    })
    let unparsed = ($unparsed | bytes at ($header.leap_cnt * ($time_size + 4))..)
    $body.is_std_indicators = (..<($header.is_std_cnt) | each {|i|
        $unparsed | bytes at ($i)..<($i + 1) | into int | $in > 0
    })
    let unparsed = ($unparsed | bytes at ($header.is_std_cnt)..)
    $body.is_ut_indicators = (..<($header.is_ut_cnt) | each {|i|
        $unparsed | bytes at ($i)..<($i + 1) | into int | $in > 0
    })
    let body = $body
    $body.is_ut_indicators | enumerate | filter {|v| $v.item} | each {|v|
        std assert ($body.is_std_indicators | get $v.index) 'Expected std indicator to be true because UT indicator was true'
    }
    let unparsed = ($unparsed | bytes at ($header.is_ut_cnt)..)
    {
        body: $body,
        body_len: ($initial_length - ($unparsed | bytes length))
    }
}

def parse_tzif []: binary -> record {
    let unparsed = $in
    let header1 = $unparsed | parse_header
    let unparsed = $unparsed | bytes at ($header1.header_len)..
    let header1 = $header1.header
    std assert greater $header1.version 1 'Expected version greater than 1'
    let body1_len = $header1 | get_data_length 4
    let unparsed = $unparsed | bytes at ($body1_len)..

    let header2 = $unparsed | parse_header
    let unparsed = $unparsed | bytes at ($header2.header_len)..
    let header2 = $header2.header
    std assert greater $header2.version 1 'Expected version greater than 1'
    let body2 = $unparsed | parse_body $header2 8
    let unparsed = $unparsed | bytes at ($body2.body_len)..
    let body2 = $body2.body

    std assert equal ($unparsed | bytes at 0..<1) (char newline | into binary) 'Newline expected after version 2+ body'
    let unparsed = $unparsed | bytes at 1..
    let footer = $unparsed | bytes at ..<($unparsed | bytes index-of (char newline | into binary)) | decode 'utf-8'

    {
        header: $header2
        body: $body2
        footer: $footer
    }
}

def interpret_body []: record -> table {
    let body = $in
    ($body.transition_times | enumerate | each {|v|
        let info_index = $body.tt_type_map | get $v.index
        let tt_info = $body.tt_info | get $info_index
        let desig = $body.desigs_bytes | bytes at ($tt_info.desig_idx).. | bytes at ..<($in | bytes index-of 0x[00]) | decode 'utf-8'
        let is_ut = if ($body.is_ut_indicators | length) > 0 { $body.is_ut_indicators | get $info_index } else { false }
        let tt_spec_type = if $is_ut { 'ut' } else { 
            if ($body.is_std_indicators | length) > 0 {
                if ($body.is_std_indicators | get $info_index) { 'std' } else { 'wall' }
            } else { 'wall' }
        }
        {
            transition_at: $v.item
            tt_spec_type: $tt_spec_type
            ut_offset: $tt_info.ut_off
            is_dst: $tt_info.is_dst
            name: $desig
        }
    })
}

export def main [--tzfile (-f): string = '/etc/localtime']: any -> record {
    let time = $in
    let time = if $time == null {
        date now | into int | $in / 10 ** 9 | math floor
    } else if ($time | describe) == 'int' {
        $time
    } else if ($time | describe) == 'date' {
        $time | into int | $in / 10 ** 9 | math floor
    } else {
        error make -u { msg: 'time must be date, int or nothing' }
    }
    open $tzfile | parse_tzif | get body | interpret_body | reject tt_spec_type | where transition_at <= $time | last
                 | update transition_at ($in.transition_at * 10 ** 9 | into datetime) | update ut_offset ($in.ut_offset * 10 ** 9 | into duration)
}

export def show [tzfile: string = '/etc/localtime']: any -> table {
    open $tzfile | parse_tzif | [($in.body | interpret_body) $in.footer] | { data: $in.0, posix_rule: $in.1 }
}