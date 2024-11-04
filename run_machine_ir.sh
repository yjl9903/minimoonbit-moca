#!/usr/bin/env bash

filepath=$1

moon run src/bin --debug -- --emit-machine "$filepath" 2>/dev/null
