#!/bin/bash

die() {
  echo "$@" >&2
  exit 1
}

usage() {
  die "Usage: update_keybase.sh [--force] [--git [--push]] [/path/to/app-crypt/keybase-bin]"
}

TEMP=$(getopt -o 'fgph' --long 'force,git,push,help' -n "update_keybase.sh" -- "$@") || usage

eval set -- "$TEMP"
unset TEMP

FORCE=false
GIT=false
PUSH=false

set -e
while true; do
  case "$1" in
    -f|--force)
      FORCE=true
      shift
      ;;
    -g|--git)
      GIT=true
      shift
      ;;
    -p|--push)
      PUSH=true
      shift
      ;;
    -h|--help)
      usage
      ;;
    --)
      shift
      break
      ;;
    *)
      die 'Error!'
      ;;
  esac
done

[ "$#" -gt 1 ] && usage
if [ "$#" -gt 0 ]; then
  [ -f "$1/Manifest" ] || usage
  EBUILD_DIR="$1"
else
  EBUILD_DIR="`dirname "$0"`"
fi

cd "$EBUILD_DIR"

CUR_EBUILD="`echo -n *.ebuild`"
[ -f "$CUR_EBUILD" ] || die "Error getting filename of current ebuild"

# Extract info from current ebuild

CUR_PV=${CUR_EBUILD##*keybase-bin-}
CUR_PV=${CUR_PV%.ebuild}
CUR_PV=${CUR_PV%-*}
CUR_HASH=`grep '^COMMIT_HASH="' "$CUR_EBUILD" | grep -o '[a-f0-9]\+'`
CUR_VERSION=${CUR_PV/_p/-}+$CUR_HASH

echo "Current ebuild version: $CUR_VERSION"

# Get latest Linux version from server

echo -n "Fetching latest Keybase version..."

LATEST_VERSION=`curl -fsS https://s3.amazonaws.com/prerelease.keybase.io/update-linux-prod.json | jq -r .version`

[[ -z "$LATEST_VERSION" ]] && die "Error fetching current version of Keybase"

echo "$LATEST_VERSION"

if [ "$CUR_VERSION" = "$LATEST_VERSION" ]; then
  if $FORCE; then
    echo "Updating despite version match."
  else
    echo "Versions match, not updating."
    exit 0
  fi
fi

TMPDIR=`mktemp -dt keybase-update.XXXXXXXXXX`
if ! [[ -n "$TMPDIR" && -d "$TMPDIR" && "$TMPDIR" = */keybase-update.* ]]; then
  echo "Could not create temporary directory for update" >&2
  exit 1
fi
trap "rm -rf '$TMPDIR'" 0

SRC_URI_BASE=`grep '^SRC_URI_BASE="' "$CUR_EBUILD" | grep -o 'http[^"]*'`
SRC_URI_VERSION=${SRC_URI_BASE}${LATEST_VERSION/+/.}_
BASENAME_VERSION=`basename "$SRC_URI_VERSION"`

echo "Fetching amd64 and i386 .deb packages for version $LATEST_VERSION..."

(
  cd "$TMPDIR"
  wget -c "${SRC_URI_VERSION}"{amd64,i386}.deb
)

AMD64_DEB="$TMPDIR/${BASENAME_VERSION}amd64.deb"
I386_DEB="$TMPDIR/${BASENAME_VERSION}i386.deb"

verify_signature() {
  local sigfile=$1 file=$2 signer=$3
  {
    gpg --verify --batch --status-fd 3 "$sigfile" "$file" 3>&1 1>&4 | (
      local got_sig=false trust_sig=false satisfied=false
      local prefix status args
      while read prefix status args; do
        case "$status,$args" in
          NEWSIG,*)
            got_sig=false
            trust_sig=false
            ;;
          GOODSIG,*"<$signer>")
            got_sig=true
            ;;
          TRUST_FULLY,*|TRUST_ULTIMATE,*)
            trust_sig=true
            ;;
        esac
        $got_sig && $trust_sig && satisfied=true
      done
      if ! $satisfied; then
        echo "Error: did not find expected valid, trusted signature from $signer." >&2
        exit 1
      fi
    )
  } 4>&1
}

echo "Verifying GPG signatures for packages..."
verify_signature <(curl -fsS https://prerelease.keybase.io/keybase_amd64.deb.sig) "$AMD64_DEB" code@keybase.io
verify_signature <(curl -fsS https://prerelease.keybase.io/keybase_i386.deb.sig) "$I386_DEB" code@keybase.io

echo "Updating ebuild..."
LATEST_PV=${LATEST_VERSION%+*}
LATEST_PV=${LATEST_PV/-/_p}
LATEST_HASH=${LATEST_VERSION#*+}

NEW_EBUILD="keybase-bin-${LATEST_PV}.ebuild"

if [ "$CUR_EBUILD" != "$NEW_EBUILD" ]; then
  if $GIT; then
    git mv "$CUR_EBUILD" "$NEW_EBUILD"
  else
    mv "$CUR_EBUILD" "$NEW_EBUILD"
  fi
fi

sed -i '/^COMMIT_HASH=/ s/[a-f0-9]\+/'$LATEST_HASH'/' "$NEW_EBUILD"

if $GIT; then
  git add "$NEW_EBUILD"
fi

manifest_entry() {
  local type=$1 f=$2
  local fields="$type" spec tag prog
  for spec in :basename ":stat -c%s" BLAKE2B:b2sum SHA512:sha512sum; do
    tag=${spec%%:*}
    prog=${spec#*:}
    fields="$fields $tag `$prog "$f" | awk '{print $1}'`"
  done
  echo $fields
}

echo "Generating Manifest..."

(
  manifest_entry DIST "$AMD64_DEB"
  manifest_entry DIST "$I386_DEB"
  manifest_entry EBUILD "$NEW_EBUILD"
  egrep -v '^(DIST|EBUILD)' Manifest
) > Manifest.new
LANG=C sort Manifest.new > Manifest
rm -f Manifest.new

$GIT && git add Manifest

if $GIT; then
  echo "Creating new git commit..."
  git commit -m "Automated version bump app-crypt/keybase-bin to $LATEST_VERSION"
  if $PUSH; then
    echo "Pushing to upstream..."
    git push
  fi
fi
