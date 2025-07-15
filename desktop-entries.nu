# This is slow. Avoid parsing every file in the database.
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
    let user_dirs = $env.XDG_DATA_HOME? | default $"($env.HOME)/.local/share" | split row ":"
    let system_dirs = $env.XDG_DATA_DIRS? | default "/usr/local/share:/usr/share" | split row ":"
    $user_dirs | append $system_dirs
}

def all-desktop-entry-files []: nothing -> list {
    xdg-data-dirs
    | each {|v| try { ls $"($v)/applications" } catch { [] } }
    | flatten
    | where { get name | str ends-with .desktop }
}

# This is slow. Prefer pre-filtering desktop entry files by e.g. substring search
export def all-desktop-entries []: nothing -> list {
    all-desktop-entry-files | each { get name | open | desktop-file-parse }
}

# Only fully parses files after a simple substring search matches.
# Speed therefore depends on the name; For example, searching for an application called "Name"
# might still result in every desktop entry file being parsed.
export def find-by-name-exact [name: string]: nothing -> list {
    all-desktop-entry-files
    | each { get name | {path: $in, content: ($in | open)} }
    | where { get content | str contains $name }
    | each { {path: $in.path, content: ($in.content | desktop-file-parse) } }
    | where { get content.'Desktop Entry' | any {|v| $v.key == Name and $v.value == $name } }
}

export def get-binary-path []: record -> string {
    get 'Desktop Entry'
    | where key == Exec | first
    | get value | split row " " | first
}
