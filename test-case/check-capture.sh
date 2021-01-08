#!/bin/bash

##
## Case Name: check-capture
## Preconditions:
##    N/A
## Description:
##    run arecord on each pepeline
##    default duration is 10s
##    default loop count is 3
## Case step:
##    1. Parse TPLG file to get pipeline with type of "record"
##    2. Specify the audio parameters
##    3. Run arecord on each pipeline with parameters
## Expect result:
##    The return value of arecord is 0
##

set -e

# shellcheck source=case-lib/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")"/../case-lib/lib.sh

OPT_NAME['t']='tplg'     OPT_DESC['t']='tplg file, default value is env TPLG: $''TPLG'
OPT_PARM_lst['t']=1         OPT_VALUE_lst['t']="$TPLG"

OPT_NAME['r']='round'     OPT_DESC['r']='round count'
OPT_PARM_lst['r']=1         OPT_VALUE_lst['r']=1

OPT_NAME['d']='duration' OPT_DESC['d']='arecord duration in second'
OPT_PARM_lst['d']=1         OPT_VALUE_lst['d']=10

OPT_NAME['l']='loop'     OPT_DESC['l']='loop count'
OPT_PARM_lst['l']=1         OPT_VALUE_lst['l']=3

OPT_NAME['o']='output'   OPT_DESC['o']='output dir'
OPT_PARM_lst['o']=1         OPT_VALUE_lst['o']="$LOG_ROOT/wavs"

OPT_NAME['f']='file'   OPT_DESC['f']='file name prefix'
OPT_PARM_lst['f']=1         OPT_VALUE_lst['f']=''

OPT_NAME['s']='sof-logger'   OPT_DESC['s']="Open sof-logger trace the data will store at $LOG_ROOT"
OPT_PARM_lst['s']=0             OPT_VALUE_lst['s']=1

OPT_NAME['F']='fmts'   OPT_DESC['F']='Iterate all supported formats'
OPT_PARM_lst['F']=0         OPT_VALUE_lst['F']=0

OPT_NAME['S']='filter_string'   OPT_DESC['S']="run this case on specified pipelines"
OPT_PARM_lst['S']=1             OPT_VALUE_lst['S']="id:any"

func_opt_parse_option "$@"

tplg=${OPT_VALUE_lst['t']}
round_cnt=${OPT_VALUE_lst['r']}
duration=${OPT_VALUE_lst['d']}
loop_cnt=${OPT_VALUE_lst['l']}
out_dir=${OPT_VALUE_lst['o']}
file_prefix=${OPT_VALUE_lst['f']}

[[ ${OPT_VALUE_lst['s']} -eq 1 ]] && func_lib_start_log_collect

func_lib_setup_kernel_checkpoint
func_lib_check_sudo
func_pipeline_export "$tplg" "type:capture & ${OPT_VALUE_lst['S']}"

for round in $(seq 1 $round_cnt)
do
    for idx in $(seq 0 $(expr $PIPELINE_COUNT - 1))
    do
        channel=$(func_pipeline_parse_value $idx channel)
        rate=$(func_pipeline_parse_value $idx rate)
        fmt=$(func_pipeline_parse_value $idx fmt)
        dev=$(func_pipeline_parse_value $idx dev)
        pcm=$(func_pipeline_parse_value $idx pcm)
        type=$(func_pipeline_parse_value $idx type)
        snd=$(func_pipeline_parse_value $idx snd)

        if [ ${OPT_VALUE_lst['F']} = '1' ]; then
            fmt=$(func_pipeline_parse_value $idx fmts)
        fi
        # clean up dmesg
        sudo dmesg -C
        for fmt_elem in $(echo $fmt)
        do
            for i in $(seq 1 $loop_cnt)
            do
                dlogi "===== Testing: (Round: $round/$round_cnt) (PCM: $pcm [$dev]<$type>) (Loop: $i/$loop_cnt) ====="
                # get the output file
                if [[ -z $file_prefix ]]; then
                    dlogi "no file prefix, use /dev/null as dummy capture output"
                    file=/dev/null
                else
                    mkdir -p $out_dir
                    file=$out_dir/${file_prefix}_${dev}_${i}.wav
                    dlogi "using $file as capture output"
                fi

                arecord_opts -D$dev -r $rate -c $channel -f $fmt_elem -d $duration $file -v -q
                if [[ $? -ne 0 ]]; then
                    func_lib_lsof_error_dump $snd
                    die "arecord on PCM $dev failed at $i/$loop_cnt."
                fi
            done
        done
    done
done

sof-kernel-log-check.sh "$KERNEL_CHECKPOINT"
exit $?
