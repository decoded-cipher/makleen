# makkili catalog: the caches and simple extras makkili knows about, one line each.
# Add your own in ~/.config/makkili/catalog.zsh, in the same format; it is loaded after this file.
#
#   cache LABEL PATH... [run=COMMAND] [needs=TOOL] [while=PROCESS] [note=TEXT] [off]
#   editor NAME SUPPORT_DIR EXTENSIONS_DIR while=PROCESS
#   extra ID LABEL PATH... [while=PROCESS] [note=TEXT]
#
# Without run=, the folders are deleted; with it, the tool cleans them itself. needs= skips the entry
# when that command isn't installed. while= makes the item unselectable while a process whose command
# line contains PROCESS runs. off makes the item start unticked. A path in single quotes is expanded
# only when the entry is used, so '$(go env GOMODCACHE)' runs go only if go is installed.
# Extras start unticked unless their ID is listed in EXTRAS. Folders under 10 MB are not listed.

# ---- JavaScript ----
cache "npm cache"                    ~/.npm/_cacache                    run="npm cache clean --force" needs=npm
cache "npx package cache"            ~/.npm/_npx
cache "Bun install cache"            ~/.bun/install/cache               run="bun pm cache rm" needs=bun
cache "pnpm store, unused packages"  '$(pnpm store path 2>/dev/null)'   run="pnpm store prune" needs=pnpm
cache "Yarn cache"                   '$(yarn cache dir 2>/dev/null)'    run="yarn cache clean" needs=yarn
cache "Yarn Berry global cache"      ~/.yarn/berry/cache
cache "Deno cache"                   '${DENO_DIR:-$HOME/Library/Caches/deno}'
cache "Puppeteer browser downloads"  ~/.cache/puppeteer
cache "Playwright browsers"          ~/Library/Caches/ms-playwright     note="reinstall with npx playwright install"
cache "Cypress binaries"             ~/Library/Caches/Cypress
cache "Electron downloads"           ~/Library/Caches/electron
cache "node-gyp headers"             ~/Library/Caches/node-gyp ~/.node-gyp
cache "Prisma engines"               ~/.cache/prisma
cache "Expo simulator/APK caches"    ~/.expo/ios-simulator-app-cache ~/.expo/android-apk-cache
cache "Wrangler logs"                ~/Library/Preferences/.wrangler/logs

# ---- Go, Rust ----
cache "Go module cache"              '$(go env GOMODCACHE 2>/dev/null)' run="go clean -modcache" needs=go
cache "Go build cache"               '$(go env GOCACHE 2>/dev/null)'    run="go clean -cache" needs=go
cache "Cargo downloaded crates"      '${CARGO_HOME:-$HOME/.cargo}/registry/cache' '${CARGO_HOME:-$HOME/.cargo}/registry/src' \
                                     '${CARGO_HOME:-$HOME/.cargo}/git/checkouts' note="downloaded again on the next cargo build"

# ---- Python ----
cache "uv cache"                     '$(uv cache dir 2>/dev/null)'      run="uv cache clean" needs=uv
cache "pip cache"                    '$(pip3 cache dir 2>/dev/null)'    run="pip3 cache purge" needs=pip3
cache "Poetry cache"                 ~/Library/Caches/pypoetry
cache "Conda package cache"          ~/miniconda3/pkgs ~/anaconda3/pkgs ~/miniforge3/pkgs ~/mambaforge/pkgs ~/.conda/pkgs \
                                     run="conda clean --all --yes" needs=conda

# ---- JVM ----
cache "Gradle caches"                ~/.gradle/caches
cache "Gradle wrapper distributions" ~/.gradle/wrapper/dists           note="downloaded again on the next build"
cache "Maven repository"             ~/.m2/repository off              note="also holds anything you installed with mvn install"

# ---- Ruby, PHP, Dart ----
cache "RubyGems download cache"      ~/.gem/ruby/*/cache ~/.local/share/gem/ruby/*/cache
cache "Bundler cache"                ~/.bundle/cache
cache "Composer cache"               ~/Library/Caches/composer ~/.composer/cache ~/.cache/composer \
                                     run="composer clear-cache" needs=composer
cache "Dart and Flutter packages"    '${PUB_CACHE:-$HOME/.pub-cache}'   run="dart pub cache clean --force" needs=dart

# ---- Apple and mobile ----
cache "CocoaPods cache"              ~/Library/Caches/CocoaPods         run="pod cache clean --all" needs=pod
cache "Xcode DerivedData"            ~/Library/Developer/Xcode/DerivedData
cache "Xcode device support files"   "~/Library/Developer/Xcode/iOS DeviceSupport" "~/Library/Developer/Xcode/watchOS DeviceSupport" \
                                     "~/Library/Developer/Xcode/tvOS DeviceSupport" note="Xcode copies them again when a device connects"
cache "Simulator caches"             ~/Library/Developer/CoreSimulator/Caches
cache "Swift Package Manager cache"  ~/Library/Caches/org.swift.swiftpm
cache "Android build caches"         ~/.android/build-cache ~/.android/cache

# ---- Hardware ----
cache "Arduino download staging"     ~/Library/Arduino15/staging

# ---- Editors ----
editor "VS Code" "~/Library/Application Support/Code" ~/.vscode/extensions while="Visual Studio Code.app/Contents/MacOS"

# ---- Extras ----
extra ml-models      "Machine learning model downloads" ~/.cache/huggingface/hub ~/.cache/torch \
                     note="downloaded again the next time a model is used"
extra xcode-archives "Xcode archives" ~/Library/Developer/Xcode/Archives \
                     note="needed to symbolicate crash reports from builds you shipped"
