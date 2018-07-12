#!/bin/bash

FB_SUFF="--bak"


F_LIST=""
if [ "$*" != "" ]; then
	F_LIST="$*"
fi

#CUBLAS_CHECK
#CUDA_POST_KERNEL_CHECK

for FN in $F_LIST; do
	echo "==== $FN ===="; #continue
	FB=$FN$FB_SUFF
	cp -a $FN $FB
	cat /dev/null > $FN
	is_armed_fb=0
	is_found=0
	cat "$FB" | while IFS= read L; do
		if [ "$is_armed_fb" != 0 ]; then
			if echo "$L" | grep -q -e "{"; then
				# echo '#include "stacktrace.h"' >> $FN
				echo "$L" >> $FN
				echo 'MY_DP("");' >> $FN
				is_armed_fb=0
			else
				echo "$L" >> $FN
			fi
		else
			if echo "$L" | grep -q -e "::Forward_[cg]pu.*{" -e "::Backward_[cg]pu.*{"; then
				echo "$L" >> $FN
				echo 'MY_DP("");' >> $FN
			elif echo "$L" | grep -q -e "::Forward_[cg]pu" -e "::Backward_[cg]pu"; then
				echo "$L" >> $FN
				is_armed_fb=1
			elif echo "$L" | grep -q -e "CUBLAS_CHECK"; then
				if echo "$L" | grep -q -v -e "cublasGetStream" -e "cublas[GS]etMathMode"; then
					INFO=`echo "$L" | sed "s/.*CUBLAS_CHECK(\([^(]*\)(.*/\1/g"`
					echo "MY_DP(\"CUBLAS-$INFO\");" >> $FN
				fi
				echo "$L" >> $FN
			elif echo "$L" | grep -q -e "CUDA_POST_KERNEL_CHECK"; then
				echo 'MY_DP("CUDA");' >> $FN
				echo "$L" >> $FN
			else
				echo "$L" >> $FN
			fi
		fi
	done
done
