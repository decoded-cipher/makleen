# makkili catalog: the caches makkili knows about, one line each.
# Add your own in ~/.config/makkili/catalog.zsh, in the same format; it is loaded after this file.
#
#   cache LABEL PATH... [run=COMMAND] [needs=TOOL] [while=PROCESS] [note=TEXT] [off]
#   editor NAME SUPPORT_DIR EXTENSIONS_DIR while=PROCESS
#
# Without run=, the folders are deleted; with it, the tool cleans them itself. needs= skips the entry
# when that command isn't installed. while= makes the item unselectable while a process whose command
# line contains PROCESS runs. off makes the item start unticked. A path in single quotes is expanded
# only when the entry is used, so '$(go env GOMODCACHE)' runs go only if go is installed.
# Folders under 10 MB are not listed.

# ---- JavaScript ----
cache "npm cache"                    ~/.npm/_cacache                    run="npm cache clean --force" needs=npm
cache "npx package cache"            ~/.npm/_npx
cache "Bun install cache"            ~/.bun/install/cache               run="bun pm cache rm" needs=bun
cache "pnpm store, unused packages"  '$(pnpm store path 2>/dev/null)'   run="pnpm store prune" needs=pnpm
cache "Yarn cache"                   '$(yarn cache dir 2>/dev/null)'    run="yarn cache clean" needs=yarn
cache "Puppeteer browser downloads"  ~/.cache/puppeteer
cache "Expo simulator/APK caches"    ~/.expo/ios-simulator-app-cache ~/.expo/android-apk-cache
cache "Wrangler logs"                ~/Library/Preferences/.wrangler/logs

# ---- Go, Python ----
cache "Go module cache"              '$(go env GOMODCACHE 2>/dev/null)' run="go clean -modcache" needs=go
cache "Go build cache"               '$(go env GOCACHE 2>/dev/null)'    run="go clean -cache" needs=go
cache "uv cache"                     '$(uv cache dir 2>/dev/null)'      run="uv cache clean" needs=uv
cache "pip cache"                    '$(pip3 cache dir 2>/dev/null)'    run="pip3 cache purge" needs=pip3

# ---- Apple and mobile ----
cache "CocoaPods cache"              ~/Library/Caches/CocoaPods         run="pod cache clean --all" needs=pod
cache "Xcode DerivedData"            ~/Library/Developer/Xcode/DerivedData
cache "Gradle caches"                ~/.gradle/caches

# ---- Hardware ----
cache "Arduino download staging"     ~/Library/Arduino15/staging

# ---- Editors ----
editor "VS Code" "~/Library/Application Support/Code" ~/.vscode/extensions while="Visual Studio Code.app/Contents/MacOS"
