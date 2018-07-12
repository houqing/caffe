#!/bin/bash

# example
FL=resnet18_fp16.log
LN=BatchNormLayer
DIR=Forward


if ! [ "$3" != "" ]; then
	echo "Usage: $0 <LAYER_NAME> <DIRECTION> <LOG_FILE>"
	exit 1
fi
LN="$1"
DIR="$2"
FL="$3"
if ! [ -f "$FL" ]; then
	echo "File not found [$FL]"
	exit 1
fi


LAYER_PREFIX="^==== "
LAYER_PATTERN="$LAYER_PREFIX.*::$LN.*::$DIR"


is_armed=0
grep -e "^===" "$FL" | while IFS= read L
do
	if [ "$is_armed" != 0 ]; then
		if echo "$L" | grep -q -e "$LAYER_PATTERN"; then
			echo "$L"
		elif echo "$L" | grep -q -e "$LAYER_PREFIX"; then
			is_armed=0
			echo
		else
			echo "$L"
		fi
	else
		if echo "$L" | grep -q -e "$LAYER_PATTERN"; then
			echo "$L"
			is_armed=1
		fi
	fi
done | tee $FL--$LN-$DIR
