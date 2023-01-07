#!/bin/bash

uart="-"`cat build/build-commandline.log | awk '{sub(/.*uart=/,""); sub(/ .*/,""); print}'`
usb="-"`cat build/build-commandline.log | awk '{sub(/.*usb=/,""); sub(/ .*/,""); print}'`
cpu="-"`cat build/build-commandline.log | awk '{sub(/.*cpu=/,""); sub(/ .*/,""); print}'`
if [ x${uart} = x"-bitstream.py" ] ; then
    uart=""
fi
if [ x${usb} = x"-bitstream.py" ] ; then
    usb=""
fi
isa=`grep CPU_ISA build/software/include/generated/soc.h |awk '{print $3}'|sed 's/"//g'`
if [ x${isa} = x"" ] ; then
    isa="rv32ima"
fi
name=RVCop64${uart}${usb}-${isa}
echo "Name=${name}"

if [ x${cpu} != x"-bitstream.py" ] ; then
    deps/litex/litex/tools/litex_json2dts_linux.py --root-device mmcblk0p2 build/csr.json > build/${name}.dts
    dtc build/${name}.dts > build/${name}.dtb
fi
cp build/gateware/orangecart.bit build/${name}.bit

files="build/csr.*
build/overlay.*
build/soc.svd
build/software/include
build/build-commandline.log
build/${name}.*"

tar -cvzf ${name}.tar.gz $files
