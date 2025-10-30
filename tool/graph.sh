#!/bin/bash

# Check if lakos is installed
if ! command -v lakos &> /dev/null
then
    echo "installing lakos ..."
    dart pub global activate lakos
    export PATH="$PATH":"$HOME/.pub-cache/bin"
fi

# Check if graphviz is installed
if ! command -v dot &> /dev/null
then
    echo "installing graphviz ..."
    brew install graphviz
fi

echo "Generate Graph dependencies"

rm -f graph.dot
rm -f graph.svg

# lakos . --no-tree -o graph.dot --ignore=example/**
lakos .  -o graph.dot --ignore=example/**
dot -Tsvg graph.dot -Grankdir=TB -Gcolor=lightgray -Ecolor="#aabbaa88" -o graph.svg