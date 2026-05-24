#!/bin/bash

set -e

SCRIPT=$(realpath -s "${0}")
SCRIPTS_PATH=$(dirname "${SCRIPT}")
TESTS_PATH=$(realpath -s "${SCRIPTS_PATH}/../tests")

: "${ELMNTL_PREFIX:=}" 
: "${ELMNTL_FIRMWARE:=/usr/share/edk2/x64/OVMF.4m.fd}"
: "${ELMNTL_FWDIP:=127.0.0.1}"
: "${ELMNTL_FWDPORT:=2222}"
: "${ELMNTL_MEMORY:=4096}"
: "${ELMNTL_LOGFILE:=${TESTS_PATH}/${ELMNTL_PREFIX}serial.log}"
: "${ELMNTL_PIDFILE:=${TESTS_PATH}/${ELMNTL_PREFIX}testvm.pid}"
: "${ELMNTL_TESTDISK:=${TESTS_PATH}/${ELMNTL_PREFIX}testdisk.qcow2}"
: "${ELMNTL_VMSTDOUT:=${TESTS_PATH}/${ELMNTL_PREFIX}vmstdout}"
: "${ELMNTL_DISKSIZE:=16G}"
: "${ELMNTL_ACCEL:=kvm}"
: "${ELMNTL_TARGETARCH:=$(uname -m)}"
: "${ELMNTL_MACHINETYPE:=q35}"
: "${ELMNTL_CPU:=max}"
: "${ELMNTL_DEBUG:=no}"

function _abort {
    echo "$@" && exit 1
}

function start {
  local base_disk=$1
  local usrnet_arg="-netdev user,id=net0,ipv6=off,net=10.240.10.0/24,dnssearch=localdomain,hostfwd=tcp:${ELMNTL_FWDIP}:${ELMNTL_FWDPORT}-:22 -device virtio-net,netdev=net0"
  local accel_arg
  local memory_arg="-m ${ELMNTL_MEMORY}"
  local firmware_arg="-bios ${ELMNTL_FIRMWARE}"
  local disk_arg="-drive file=${ELMNTL_TESTDISK},id=drive0,if=none -device virtio-blk,drive=drive0"
  local serial_arg="-serial file:${ELMNTL_LOGFILE}"
  local pidfile_arg="-pidfile ${ELMNTL_PIDFILE}"
  local display_arg="-nographic"
  local machine_arg="-machine type=${ELMNTL_MACHINETYPE}"
  local cdrom_arg
  local cpu_arg
  local vmpid
  local kvm_arg

  if [ -f "${ELMNTL_PIDFILE}" ]; then
    vmpid=$(cat "${ELMNTL_PIDFILE}")
    if ps -p ${vmpid} > /dev/null; then
      echo "test VM is already running with pid ${vmpid}"
      exit 0
    else
      echo "removing outdated pidfile ${ELMNTL_PIDFILE}"
      rm "${ELMNTL_PIDFILE}"
    fi
  fi

  [ -f "${base_disk}" ] || _abort "Disk not found: ${base_disk}"

  case "${base_disk}" in
      *.qcow2)
        qemu-img create -f qcow2 -b "${base_disk}" -B qcow2 "${ELMNTL_TESTDISK}" > /dev/null
        ;;
      *.iso)
        qemu-img create -f qcow2 "${ELMNTL_TESTDISK}" "${ELMNTL_DISKSIZE}" > /dev/null
        cdrom_arg="-drive file=${base_disk},readonly=on,if=none,id=cdrom,media=cdrom -device virtio-scsi,id=scsi0 -device scsi-cd,bus=scsi0.0,drive=cdrom,bootindex=2"
        ;;
      *)
        _abort "Expected a *.qcow2 or *.iso file"
        ;;
  esac

  [ "hvf" == "${ELMNTL_ACCEL}" ] && accel_arg="-accel ${ELMNTL_ACCEL}" && cpu_arg="-cpu max,-pdpe1gb"
  [ "kvm" == "${ELMNTL_ACCEL}" ] && cpu_arg="-cpu host" && accel_arg="-accel kvm"

  if [ "${ELMNTL_DEBUG}" == "yes" ]; then
      qemu-system-${ELMNTL_TARGETARCH} \
        ${disk_arg} \
        ${cdrom_arg} \
        ${firmware_arg} \
        ${usrnet_arg} \
        ${memory_arg} \
        ${graphics_arg} \
        ${pidfile_arg} \
        ${display_arg} \
        ${machine_arg} \
        ${accel_arg} \
        ${cpu_arg}
  else 
      qemu-system-${ELMNTL_TARGETARCH} \
        ${disk_arg} \
        ${cdrom_arg} \
        ${firmware_arg} \
        ${usrnet_arg} \
        ${memory_arg} \
        ${graphics_arg} \
        ${serial_arg} \
        ${pidfile_arg} \
        ${display_arg} \
        ${machine_arg} \
        ${accel_arg} \
        ${cpu_arg} \
        > ${ELMNTL_VMSTDOUT} 2>&1 &
  fi
}

function stop {
  local vmpid
  local killprog

  if [ -f "${ELMNTL_PIDFILE}" ]; then
    vmpid=$(cat "${ELMNTL_PIDFILE}")
    killprog=$(which kill)
    if ${killprog} --version | grep -q util-linux; then
        ${killprog} --verbose --timeout 1000 TERM --timeout 5000 KILL --signal QUIT ${vmpid}
    else
        ${killprog} -9 ${vmpid}
    fi
    rm -f "${ELMNTL_PIDFILE}"
  else
    echo "No pidfile ${ELMNTL_PIDFILE} found, nothing to stop"
  fi
}

function clean {
  ([ -f "${ELMNTL_LOGFILE}" ] && rm -f "${ELMNTL_LOGFILE}") || true
  ([ -f "${ELMNTL_TESTDISK}" ] && rm -f "${ELMNTL_TESTDISK}") || true
  ([ -f "${ELMNTL_VMSTDOUT}" ] && rm -f "${ELMNTL_VMSTDOUT}") || true
}

function vmpid {
    local timeout=10

    until [ -f "${ELMNTL_PIDFILE}" -o "$((timeout--))" -eq 0 ]; do
	sleep 1
    done

    [ -f "${ELMNTL_PIDFILE}" ] && cat "${ELMNTL_PIDFILE}" 
}

cmd=$1
disk=$2

[ -n "$3" ] && [ "$3" == "--debug" ] && ELMNTL_DEBUG=yes

case $cmd in
  start)
    start "${disk}"
    ;;
  stop)
    stop
    ;;
  clean)
    clean
    ;;
  vmpid)
    vmpid
    ;;
  *)
    _abort "Unknown command: ${cmd}"
    ;;
esac

exit 0
