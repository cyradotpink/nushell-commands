export module git-util {
    export def url-parse []: string -> record {
        parse -r '(?:^git@(.*?):(.*)\.git$)|(?:^https://(.*?)/(.*).git$)'
            | first
            | {
                host: ($in.capture0 + $in.capture2)
                repo: ($in.capture1 + $in.capture3)
              }
    }

    export def url-to-web []: string -> string {
        url-parse | $'https://($in.host)/($in.repo)'
    }

    export def show-config []: any -> any {
        git config -l -z | split row (char -i 0) | filter { str length | $in > 0 } | each { lines | { key: $in.0, value: $in.1? } }
    }
}

export def str-to-codepoints []: string -> list {
    mut utf8_bytes = $in | encode utf8
    mut offset = 0
    mut out = []
    while $offset < ($utf8_bytes | bytes length) {
        let first_byte = $utf8_bytes | bytes at ($offset).. | first
        let codepoint_info = if ($first_byte | bits and 0b1000_0000) == 0 {
            [1, 0b0111_1111]
        } else {
            mut length = 2
            mut marker_mask: int = 0
            loop {
                let marker_candidate = 0b0011_1111 | bits shr -n 1 ($length - 2) | bits not -n 1
                $marker_mask = (0b0001_1111 | bits shr -n 1 ($length - 2) | bits not -n 1)
                if ($first_byte | bits and $marker_mask) == $marker_candidate {
                    break
                }
                $length += 1
            }
            [$length, ($marker_mask | bits not -n 1)]
        }
        let length = $codepoint_info.0
        let mask = $codepoint_info.1
        mut codepoint = $first_byte | bits and $mask | bits shl -n 4 (6 * ($length - 1))
        let mask = 0b0011_1111
        for n in 1..<($length) {
            let utf8_byte = $utf8_bytes | bytes at ($offset + $n).. | first
            let shifted = $utf8_byte | bits and $mask | bits shl -n 4 (6 * ($length - 1 - $n))
            $codepoint = ($codepoint | bits or $shifted)
        }
        $out = ($out | append $codepoint)
        $offset += $length
    }
    $out
}
