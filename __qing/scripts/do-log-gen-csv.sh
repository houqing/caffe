#!/bin/bash

FL="$1"

if ! [ -f "$FL" ]; then
	echo "File not found [$FL]"
	exit 1
fi


L_PREF="^==== "
OP_CUB="^===CUBLAS"
OP_CUD="^===CUDA"


TITLE_OP_STAT="a16,a32,s16,s32,m16,m32,d16,d32,macc16,macc32,exp16,exp32,abs16,abs32,comp16,comp32,col2im16,col2im32,im2col16,im2col32,conv16to32,conv32to16,log16,log32,_vec16,_vec32,_vec_sfu16,_vec_sfu32,__vec,__vec_sfu,__macc,__conv,__im2col,__col2im"
TITLE="id,layer_id,layer_mark_id,direction,layer_name,caffe_op_id,caffe_op_name,op_count,$TITLE_OP_STAT,caffe_op_raw_log,layer_raw_log"	#| sed "s/,/\t/g"

echo "$TITLE"

update_op_stat()
{
	a16=0; a32=0; s16=0; s32=0; m16=0; m32=0; d16=0; d32=0; macc16=0; macc32=0; exp16=0; exp32=0; abs16=0; abs32=0; comp16=0; comp32=0; col2im16=0; col2im32=0; im2col16=0 im2col32=0; conv16to32=0; conv32to16=0; log16=0; log32=0
	_flag_hot_fix="$1"
	shift
	for i in $*; do
		if echo "$i" | grep -q -e "=[0-9][0-9]*"; then
			eval $i
		else
			echo "==== ERROR == $* ==" >&2
		fi
	done
	if [ "$_flag_hot_fix" == "1" ]; then
		((a32+=macc32))
		((a16+=macc16))
		macc32=0
		macc16=0
	fi
	((_vec16=a16+s16+m16+d16+abs16+comp16+log16))
	((_vec32=a32+s32+m32+d32+abs32+comp32+log32))
	((_vec_sfu16=exp16+log16))
	((_vec_sfu32=exp32+log32))
	((__vec=_vec16+_vec32))
	((__vec_sfu=_vec_sfu16+_vec_sfu32))
	((__macc=macc16+macc32))
	((__conv=conv16to32+conv32to16))
	((__im2col=im2col16+im2col32))
	((__col2im=col2im16+col2im32))
	OP_STAT="$a16,$a32,$s16,$s32,$m16,$m32,$d16,$d32,$macc16,$macc32,$exp16,$exp32,$abs16,$abs32,$comp16,$comp32,$col2im16,$col2im32,$im2col16,$im2col32,$conv16to32,$conv32to16,$log16,$log32,$_vec16,$_vec32,$_vec_sfu16,$_vec_sfu32,$__vec,$__vec_sfu,$__macc,$__conv,$__im2col,$__col2im"
}

global_id=0
layer_mark_step=1	# 1:forward -1:backward
layer_mark_id=-1
layer_id=-1
caffe_op_id=-1
#grep -e "^===" "$FL" | grep -v -e "^===CU.*ward_[cg]pu(" | sed "s/,/;/g" | while IFS= read L
grep -e "^===" "$FL" | sed "s/,/;/g" | while IFS= read L
do
	if echo "$L" | grep -q -e "$L_PREF"; then
		if [ "$caffe_op_id" == "0" ]; then
			OP_NAME="_OP_NOP_"
			OP_HW_API=""
			OP_COUNT=0
			OP_STAT_RAW=""
			update_op_stat 0 $OP_STAT_RAW
			echo "$global_id,$LAYER_HEAD,$caffe_op_id,$OP_NAME$OP_HW_API,$OP_COUNT,$OP_STAT,$L,$LAYER_TAIL"	#| sed "s/,/\t/g"
			((global_id++))
		fi
		# get layer name, direction
		#echo "$L"
		L_NAME="`echo "$L" | sed "s/^[^:]*::\([^<]*\)<.*$/\1/g"`"
		L_DIR="`echo "$L" | sed "s/.*::\([a-zA-Z]*ward_[cg]pu\)(.*/\1/g"`"
		if echo "$L" | grep -q -e "Backward"; then
			layer_mark_step=-1
		fi
		((layer_mark_id+=layer_mark_step))
		((layer_id++))
		LAYER_HEAD="$layer_id,$layer_mark_id,$L_DIR,$L_NAME"
		LAYER_TAIL="$L"
		caffe_op_id=0
	elif echo "$L" | grep -q -e "$OP_CUD"; then
		OP_NAME="`echo "$L" | sed "s/^[^:]*::\([^(]*\)(.*$/\1/g"`"
		OP_HW_API="`echo "$L" | sed "s/^===CUDA-\([^=]*\)=.*$/\1/g"`"
		if [ "$OP_HW_API" == "x" ]; then
			OP_HW_API=""
		else
			OP_NAME="->"
		fi
		OP_STAT_RAW="`echo "$L" | sed "s/^.*[^{]{\([^}]*\)}$/\1/g"`"
		OP_COUNT="`echo "$L" | sed "s/^.*{{n=\([0-9]*\)[^0-9].*$/\1/g"`"
		update_op_stat 0 $OP_STAT_RAW
		echo "$global_id,$LAYER_HEAD,$caffe_op_id,$OP_NAME$OP_HW_API,$OP_COUNT,$OP_STAT,$L,$LAYER_TAIL"	#| sed "s/,/\t/g"
		((caffe_op_id++))
		((global_id++))
	elif echo "$L" | grep -q -e "$OP_CUB"; then
		OP_NAME="`echo "$L" | sed "s/^[^:]*::\([^(]*\)(.*$/\1/g"`"
		OP_HW_API="`echo "$L" | sed "s/^===CUBLAS-\([^=]*\)=.*$/\1/g"`"
		if [ "$OP_HW_API" == "x" ]; then
			OP_HW_API=""
		else
			OP_NAME="$OP_NAME->"
		fi
		OP_STAT_RAW="`echo "$L" | sed "s/^.*[^{]{\([^}]*\)}$/\1/g"`"
		OP_COUNT="`echo "$L" | sed "s/^.*{{\(m=[0-9]* n=[0-9]* k=[0-9]*\)[^0-9].*$/\1/g"`"
		OP_COUNT="`echo "$OP_COUNT" | sed -e "s/.=//g" -e "s/ /*/g"`"
		OP_COUNT="$(($OP_COUNT))"
		if [ "$L_NAME" == "BatchNormLayer" ] && [ "$OP_NAME" == "caffe_gpu_gemv->" ]; then
			flag_hot_fix=1
		else
			flag_hot_fix=0
		fi
		update_op_stat $flag_hot_fix $OP_STAT_RAW
		echo "$global_id,$LAYER_HEAD,$caffe_op_id,$OP_NAME$OP_HW_API,$OP_COUNT,$OP_STAT,$L,$LAYER_TAIL"	#| sed "s/,/\t/g"
		((caffe_op_id++))
		((global_id++))
	fi
done

