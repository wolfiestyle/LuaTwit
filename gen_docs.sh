#!/bin/sh

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
  for tag in "master" $(git tag); do
    generate_docs "$tag"
  done
  git checkout "gh-pages"
  rm -rf *
  mv "$DOC_TMP"/* .
  git add .
  git commit
  git checkout "$CUR_BRANCH"
fi

rm -rf "$DOC_TMP"
