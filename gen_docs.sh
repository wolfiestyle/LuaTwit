#!/bin/sh
set -eu
STATUS=$(git status --porcelain)
DOC_TMP=$(mktemp -d)

function generate_docs {
  git checkout "$1"
  ldoc -d "$DOC_TMP/$1" .
}

mkdir -p "$DOC_TMP"

if [ -n "$STATUS" ]; then
  echo "Git directory not clean"
  echo "Aborting..."
  exit 1
else
  CUR_BRANCH=$(git rev-parse --abbrev-ref HEAD)
  TAGS="master $(git tag)"
  for tag in $TAGS; do
    generate_docs "$tag"
  done
  git checkout "gh-pages"
  rm -rf examples modules topics index.html ldoc.css $TAGS
  mv "$DOC_TMP"/* .
  git add $TAGS
  git commit
  git checkout "$CUR_BRANCH"
fi

rm -rf "$DOC_TMP"
