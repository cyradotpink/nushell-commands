export def main [--trans (-t) --name (-n) --all (-a) term: any] {
    let pids = if not $name { [$term] } else {
        let search = $term
        let matches = ps | where name =~ $search
        if $all {
            $matches | get pid
        } else if ($matches | length) > 1 {
            error make {
                msg: "Expression matched multiple processes"
                label: {
                    text: "This expression",
                    span: (metadata $term).span
                }
                help: $"Use --all or try `('ps | where name =~ "pattern"' | nu-highlight)`"
            }
        } else if ($matches | length) == 0 {
            error make {
                msg: "Expression matched no processes"
                label: {
                    text: "This expression",
                    span: (metadata $term).span
                }
            }
        } else {
            $matches | get pid
        }
    }
    $pids | each {|pid|
        open $"/proc/($pid)/status" | lines | split column ":" | each {|v|
            return { key: ($v.column1 | str trim), value: ($v.column2 | str trim) }
        } | transpose --header-row | first
    } | if $all { $in } else { $in | first }
}
