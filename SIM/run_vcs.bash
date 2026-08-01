#!/bin/bash -i
# Run in interactive mode so ~/.bashrc is sourced and the `vcs` alias
# (-full64 -sverilog -debug_all ...) is defined and expanded here.

PATTERN=$1
CURREN_DIR=$(pwd)
PATTERN_DIR="../testbench/src/$PATTERN"

# Check pattern (begin)
cd $PATTERN_DIR

if [ -f $PATTERN.hex ]; then
    echo "$PATTERN exists."
else
    echo "The pattern is not found."
    exit 0
fi

cd $CURREN_DIR
# Check pattern (end)

cp $PATTERN_DIR/$PATTERN.hex test.hex
rm -rf ./simv.daidir
vcs -sverilog -full64 -R -debug_access+all -f ./flist.f
