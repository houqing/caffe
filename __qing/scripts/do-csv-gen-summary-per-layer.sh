#!/bin/bash

FL="$1"

if ! [ -f "$FL" ]; then
	echo "File not found [$FL]"
	exit 1
fi


L_PREF="^==== "
OP_CUB="^===CUBLAS"
OP_CUD="^===CUDA"


TITLE_OP_STAT="a16,a32,s16,s32,m16,m32,d16,d32,macc16,macc32,exp16,exp32,abs16,abs32,comp16,comp32,col2im16,col2im32,im2col16,im2col32,conv16to32,conv32to16"
TITLE="id,layer_id,layer_mark_id,direction,layer_name,caffe_op_id,caffe_op_name,op_count,$TITLE_OP_STAT,caffe_op_raw_log,layer_raw_log"	#| sed "s/,/\t/g"

MY_TITLE="layer_id,layer_mark_id,direction,layer_name,caffe_op_name,op_count,$TITLE_OP_STAT"

echo "$MY_TITLE"

#set -x
for layer_id in `seq 0 158`; do
	ONE_LAYER="`grep "^[^,]*,$layer_id,.*$" "$FL"`"
	layer_mark_id=`echo "$ONE_LAYER" | cut -d , -f 3 | uniq`
	direction=`echo "$ONE_LAYER" | cut -d , -f 4 | uniq`
	layer_name=`echo "$ONE_LAYER" | cut -d , -f 5 | uniq`

	caffe_op_name_list=`echo "$ONE_LAYER" | cut -d , -f 7 | sort | uniq | xargs`
	for caffe_op_name in $caffe_op_name_list; do
		ONE_OP="`echo "$ONE_LAYER" | grep "^[^,]*,[^,]*,[^,]*,[^,]*,[^,]*,[^,]*,$caffe_op_name,.*$"`"
		#op_count=`echo "$ONE_OP" | cut -d , -f 8 | xargs | sed "s/ /+/g"`
		op_count=`echo "$ONE_OP" | cut -d , -f 8 | xargs | sed "s/ /+/g" | bc`
		st_id=9
		st_list=""
		for st_name in `echo $TITLE_OP_STAT | sed "s/,/ /g"`; do
			st=`echo "$ONE_OP" | cut -d , -f $st_id | xargs | sed "s/ /+/g" | bc`
			st_list="$st_list,$st"
			((st_id++))
		done
		if false; then
			echo $layer_id,$layer_mark_id,$direction,$layer_name,$caffe_op_name,$op_count,$st_list
		else
			echo "sum,$layer_id,$layer_mark_id,$direction,$layer_name,$caffe_op_name,$op_count,$st_list,x,x"
		fi
	done
	echo "$ONE_LAYER"

	[ "$layer_id" == 5 ] && exit
done

