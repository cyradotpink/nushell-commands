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
        git config -l -z | split row (char -i 0) | each { lines | into record | rename key value }
        #parse -r '^(?P<section>.*?)\.(?P<subsection>.*?)\.?(?P<key>[^.]*)$'
    }
}