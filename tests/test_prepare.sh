#!/bin/bash
set -euo pipefail
SOURCE_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
TEST_ROOT=$(mktemp -d)
trap 'rm -rf -- "$TEST_ROOT"' EXIT
mkdir -p "$TEST_ROOT/bin"
export TEST_ROOT
export PATH="$TEST_ROOT/bin:$PATH"

cat > "$TEST_ROOT/bin/git" <<'STUB'
#!/bin/bash
set -euo pipefail
printf '%s\n' "$*" >> "$TEST_ROOT/git.log"
if [[ $1 == clone ]]; then
    mkdir -p "${@: -1}/stage2"
else
    printf 'test-commit\n'
fi
STUB
cat > "$TEST_ROOT/bin/dpkg" <<'STUB'
#!/bin/bash
printf '%s\n' "$TEST_HOST_ARCH"
STUB
chmod +x "$TEST_ROOT/bin/git" "$TEST_ROOT/bin/dpkg"

check_target() {
    local name=$1 host=$2 expected=$3 branch=$4
    shift 4
    export TEST_HOST_ARCH=$host
    bash "$SOURCE_DIR/image/prepare.sh" "$TEST_ROOT/$name" "$@" > "$TEST_ROOT/output"
    grep -Fq -- "--branch $branch " "$TEST_ROOT/git.log"
    grep -qx "IMG_NAME='img-frame-$expected'" "$TEST_ROOT/$name/config"
    test -f "$TEST_ROOT/$name/stage2/SKIP_IMAGES"
    test -x "$TEST_ROOT/$name/stage-img-frame/00-install/00-run.sh"
    cmp "$SOURCE_DIR/install.sh" "$TEST_ROOT/$name/stage-img-frame/00-install/files/install.sh"
    printf 'OK: %s\n' "$name"
    rm "$TEST_ROOT/git.log"
}

check_target explicit-armhf amd64 armhf master armhf
check_target explicit-arm64 amd64 arm64 arm64 arm64
check_target auto-armhf armhf armhf master
check_target auto-arm64 arm64 arm64 arm64 auto

export TEST_HOST_ARCH=amd64
if bash "$SOURCE_DIR/image/prepare.sh" "$TEST_ROOT/unsupported-auto" > "$TEST_ROOT/output" 2>&1; then
    echo 'FEHLER: auto darf auf amd64 kein ARM-Ziel raten.' >&2
    exit 1
fi
test ! -e "$TEST_ROOT/unsupported-auto"
test ! -e "$TEST_ROOT/git.log"
printf 'OK: auto auf amd64 abgelehnt\n'

if bash "$SOURCE_DIR/image/prepare.sh" "$TEST_ROOT/invalid" invalid > "$TEST_ROOT/output" 2>&1; then
    echo 'FEHLER: Unbekannte Zielarchitektur akzeptiert.' >&2
    exit 1
fi
test ! -e "$TEST_ROOT/git.log"
printf 'OK: ungueltige Architektur abgelehnt\n'

if bash "$SOURCE_DIR/image/prepare.sh" "$TEST_ROOT/explicit-arm64" arm64 > "$TEST_ROOT/output" 2>&1; then
    echo 'FEHLER: Vorhandenes Build-Verzeichnis akzeptiert.' >&2
    exit 1
fi
test ! -e "$TEST_ROOT/git.log"
printf 'OK: vorhandenes Build-Verzeichnis geschuetzt\n'