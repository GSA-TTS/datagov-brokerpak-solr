#!/bin/bash

# BASH templating, courtesy of
# https://stackoverflow.com/a/14870510

template() {
  file=examples.json-template
  eval "`printf 'local %s\n' $@`
cat <<EOF
`cat $file`
EOF"
}

template
