#!/bin/sh
echo --- Analyze

dart analyze 
dart fix --apply

flutter analyze

dart run tool/sort_source.dart
dart format .

flutter test

tool/graph.sh
tool/layers.sh
