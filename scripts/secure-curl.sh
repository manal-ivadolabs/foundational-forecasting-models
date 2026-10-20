#!/bin/sh
# Downloads a file over HTTPS and checks its SHA-256 before anything uses it.
#
#   sh scripts/secure-curl.sh URL SHA256 -o PATH               save it to PATH
#   sh scripts/secure-curl.sh URL SHA256 -- COMMAND [ARG]...   run COMMAND with it on stdin (instead of curl | sh)

set -eu

usage() {
	echo "usage: $0 URL SHA256 -o PATH | $0 URL SHA256 -- COMMAND [ARG]..." >&2
	exit 2
}

[ $# -ge 4 ] || usage
url=$1
expected=$(printf %s "$2" | tr 'A-F' 'a-f')
mode=$3
shift 3
case $url in
https://*) ;;
*) echo "secure-curl.sh: not an https:// URL: $url" >&2; exit 2 ;;
esac
case $expected in
*[!0-9a-f]*) usage ;;
esac
[ ${#expected} -eq 64 ] || usage
case $mode in
-o) [ $# -eq 1 ] || usage ;;
--) ;;
*) usage ;;
esac

if [ "$mode" = -o ]; then
	output=$1
	mkdir -p "$(dirname "$output")"
	downloaded=$(mktemp "$(dirname "$output")/.secure-curl.XXXXXX")
else
	downloaded=$(mktemp "${TMPDIR:-/tmp}/secure-curl.XXXXXX")
fi
trap 'rm -f "$downloaded"' EXIT
trap 'exit 1' HUP INT TERM

curl --proto '=https' --proto-redir '=https' --tlsv1.2 -fsSL -o "$downloaded" "$url"
if command -v sha256sum >/dev/null 2>&1; then
	actual=$(sha256sum "$downloaded" | cut -d ' ' -f 1)
else
	actual=$(shasum -a 256 "$downloaded" | cut -d ' ' -f 1)
fi
if [ "$actual" != "$expected" ]; then
	echo "Checksum verification failed for $url" >&2
	echo "  expected: $expected" >&2
	echo "  actual:   $actual" >&2
	exit 1
fi

if [ "$mode" = -o ]; then
	# mktemp creates the file 0600; give it the permissions curl -o would have.
	chmod "$(printf '%o' $((0666 & ~$(umask))))" "$downloaded"
	mv -f "$downloaded" "$output"
else
	"$@" <"$downloaded"
fi
