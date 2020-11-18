#!/bin/bash

template() {
  file=examples.json-shell
  eval "`printf 'local %s\n' $@`
cat <<EOF
`cat $file`
EOF"
}

template 