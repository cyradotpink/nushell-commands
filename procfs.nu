export def status [pid: int] {
    open $"/proc/($pid)/status"
        | lines
        | parse -r '^(.*?):\s*(.*?)\s*$'
        | each { update capture0 { str snake-case } }
        | transpose --header-row
        | update uid {
            split row -r '\s+'
            | into int
            | zip [real_uid effective_uid saved_uid fs_uid]
            | each { reverse }
            | into record
            # | transpose --header-row
            # | first
        }
        | update gid {
            split row -r '\s+'
            | into int
            | zip [real_gid effective_gid saved_gid fs_gid]
            | each { reverse }
            | into record
            # | transpose --header-row
            # | first
        }
        | flatten
        | update groups { split row ' ' | filter { str length | $in > 0 } | each { into int } }
        | update cells --columns [tgid ngid pid p_pid tracer_pid fd_size voluntary_ctxt_switches
                                  nonvoluntary_ctxt_switches] { into int }
        | update cells --columns [vm_peak vm_size vm_lck vm_pin vm_hwm vm_rss rss_anon rss_file
                                  rss_shmem vm_data vm_stk vm_exe vm_lib vm_pte vm_swap hugetlb_pages] { into filesize }
        | first
}

export def cmdline [pid: int] {
    open $"/proc/($pid)/cmdline" | split row (char -i 0) | first ($in | length | $in - 1)
}

export def exe [pid: int] {
    ls -l $"/proc/($pid)/exe" | first | get target
}

export def parent [pid: int] {
    status (status $pid | get p_pid)
}

export def ancestors [pid: int] {
    mut list = [(status $pid)]
    loop {
        $list = ($list | prepend [(status $list.0.p_pid)])
        if $list.0.p_pid == 0 { break }
    }
    $list
}

export def list_pids [] {
    ls /proc | where type == dir | get name | each { path split | get 2 | try { into int } }
}

export def status_table [] {
    list_pids | each { status $in }
}
