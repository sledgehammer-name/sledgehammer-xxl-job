#!/usr/bin/env bash

## 默认参数
filename="xxl-job-admin.jar"
timezone='Asia/Shanghai'
jvm=''

## 通过参数获取执行的命令
commands="$1"
shift

## 获取额外的jvm参数
while [[ $# -gt 0 ]]; do
    case "$1" in
    --timezone)
        timezone="$2"
        shift
        ;;
    --jvm)
        jvm="$2"
        shift
        ;;
    *)
        echo "Illegal option $1"
        exit 1
        ;;
    esac
    shift $(($# > 0 ? 1 : 0))
done

## Jvm参数
JVM_ARGS="-Duser.timezone=${timezone} ${jvm}"

## "2018-03-19 14:41:12 xxxxxxxxxx"
log(){
    echo "$(date '+%Y-%m-%d %H:%M:%S') $*"
}

## get java pid by jar file name, $1 is jar file name
pid() {
    pgrep -f "java.*$1" 2>/dev/null
}

## stop project,$1 is jar file name
stop() {
    PID=$(pid "$1")
    if [[ -n "$PID" ]]; then
        log "Stopping project..."
        ## 先尝试优雅关闭（SIGTERM）
        kill "${PID}"
        for i in $(seq 1 10); do
            sleep 1
            PID=$(pid "$1")
            if [[ -z "$PID" ]]; then
                break
            fi
            log "Waiting for process to stop... ($i/10)"
        done
        ## 优雅关闭失败，强制杀死
        PID=$(pid "$1")
        if [[ -n "$PID" ]]; then
            log "Graceful shutdown timeout, force killing..."
            kill -9 "${PID}"
            sleep 1
        fi
        log "Stopped the project"
    else
        log "The project did not start!"
    fi
}

## start
start() {
    PID=$(pid "$1")
    if [[ -n "$PID" ]]; then
        log "The project already started! PID: $PID"
    else
        log "Starting Project!"
        log "${JVM_ARGS}"
        # shellcheck disable=SC2086
        nohup java ${JVM_ARGS} -jar "$1" >/dev/null 2>&1 &
        sleep 2
        PID=$(pid "$1")
        if [[ -n "$PID" ]]; then
            log "Project successful start! PID=$PID"
        else
            log "Project start fail"
        fi
    fi
}

log "Command:${commands}"

## Execute The Requested Command
cd "$(dirname "$0")" || exit

## 检查jar包是否存在
if [[ ! -f "${filename}" ]]; then
    log "File ${filename} not exists!" && exit 1
else
    log "FileName:${filename}"
fi

if [[ ${commands} == "pid" ]]; then
    PID=$(pid ${filename})
    if [[ -n "$PID" ]]; then
        log "Project pid : $PID"
    else
        log "The project did not start!"
    fi

elif [[ ${commands} == "start" ]]; then
    start ${filename}

elif [[ ${commands} == "stop" ]]; then
    stop ${filename}

elif [[ ${commands} == "restart" ]]; then
    stop ${filename} && start ${filename}

else
    SCRIPT_NAME=$(echo "$0" | awk -F '/' '{print $NF}')
    echo "Usage: $SCRIPT_NAME ( commands ) (--timezone XXX --jvm 'XXX')"
    echo "commands:"
    echo "  pid               Query project pid"
    echo "  start             Start project"
    echo "  stop              Stop project"
    echo "  restart           restart project"
    exit 1
fi