export def status [pid: int] {
    open $"/proc/($pid)/status" | lines | parse -r '^(.*):\s*(.*?)\s*$' | transpose --header-row | first
}

export def cmdline [pid: int] {
    open $"/proc/($pid)/cmdline" | split row (char -i 0) | first ($in | length | $in - 1)
}

export def exe [pid: int] {
    ls -l $"/proc/($pid)/exe" | first | get target
}