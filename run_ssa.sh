#!/usr/bin/env bash

filepath=$1

moon run src/bin --debug -- --emit-ssa "$filepath"
