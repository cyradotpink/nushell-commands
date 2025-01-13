# this is kind of slow :(
export def desktop-file-parse []: string -> table {
    parse -r '(?P<key>.+?)(?:\[(?P<locale>.*)\])? *= *(?P<value>.*)|(?:\[(?P<category>.+)\])(?:\n|$)'
    | reduce --fold {cat: "", out: {}} {|it, acc|
        if ($it.category != "") {
            {
                cat: $it.category
                out: ({$it.category: []} | merge $acc.out)
            }
        } else if ($it.key != "") {
            let update = {|v| if ($in == "") { null } else { $in }}
            let it = $it | update locale $update | update value $update
            {
                cat: $acc.cat
                out: ($acc.out | merge {$acc.cat: ($acc.out | get $acc.cat | append ($it | select key locale value))})
            }
        } else {
            $acc
        }
    }
    | get out
}

export def xdg-data-dirs []: nothing -> list {
    let user_dirs = $env | try { get "XDG_DATA_HOME" } catch { $"($env.HOME)/.local/share" } | split row ":"
    let system_dirs = $env | try { get "XDG_DATA_DIRS" } catch { "/usr/local/share:/usr/share" } | split row ":"
    $user_dirs | append $system_dirs
}

export def all-desktop-entries []: nothing -> list {
    xdg-data-dirs
    | each {|v| try { ls --threads $"($v)/applications" } catch { [] } }
    | flatten
    | filter { get name | str ends-with .desktop }
    | each { get name | open | desktop-file-parse }
}

export def find-by-name-exact [name: string]: nothing -> list {
    all-desktop-entries
    | filter { get 'Desktop entry' | any {|v| $v.key == Name and $v.value == $name } }
}

export def get-binary-path []: record -> string {
    get 'Desktop Entry'
    | where key == Exec | first
    | get value | split row " " | first
}
