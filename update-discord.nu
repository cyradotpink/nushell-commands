export def main [location: string] {
    print $"Selected location: ($location)"

    cd $location

    let installed_version: string = try {
        let installed_version = (open resources/build_info.json | $in.version)
        print $"Installed version is ($installed_version). Checking available..."
        $installed_version
    } catch {
        let input = input -u "\n" $"No installed version found. Continue anyway? \(y/[n]) "
        if $input != y { exit 0 }
        print "Checking available..."
        null
    }
    let url = http head -R m https://discord.com/api/download/stable?platform=linux&format=tar.gz | where name == location | get 0.value
    let available = $url | split row '/' | last 2 | { version: $in.0 filename: $in.1 }
    if $installed_version == $available.version {
        let input = input -u "\n" $"No new version available. Reinstall version ($available.version)? \(y/[n]) "
        if $input != y { exit 0 }
    } else {
        let input = input -u "\n" $"Available version is ($available.version). Install? \([y]/n) "
        if $input != y and $input != "" { exit 0 }
    }
    print $"Downloading version ($available.version)..."
    http get $url | save -f $available.filename
    print "Removing old files..."
    ls | where name != $available.filename | each { rm -r $in.name }
    print "Unpacking..."
    tar x --strip-components 1 -f $available.filename Discord
    rm $available.filename
    print "Done."
}
