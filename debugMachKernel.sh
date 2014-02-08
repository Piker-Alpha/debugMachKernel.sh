#!/bin/bash

#
# Script (debugMachKernel.sh) to forward calls from _kprintf to _printf
#
# Version 0.2 - Copyright (c) 2012 by † RevoGirl
# Version 0.5 - Copyright (c) 2014 by Pike R. Alpha
#
# Updates:
#			- Variable 'gID' was missing (Pike R. Alpha, January 2014)
#			- Output styling (Pike R. Alpha, January 2014)
#			- DEBUG replaced by gDebug (Pike R. Alpha, Februari 2014)
#			- Swtched off debug mode (Pike R. Alpha, Februari 2014)
#

#================================= GLOBAL VARS ==================================

#
# Script version info.
#
gScriptVersion=0.5

#
# Setting the debug mode (default off).
#
let gDebug=0

#
# Get user id
#
let gID=$(id -u)

#
# Change this to 0 if you don't want additional styling (bold/underlined).
#
let gExtraStyling=1

#
# Output styling.
#
STYLE_RESET="[0m"
STYLE_BOLD="[1m"
STYLE_UNDERLINED="[4m"

#
#
#
gTargetFile="/mach_kernel"


#
#--------------------------------------------------------------------------------
#

function _showHeader()
{
  printf "debugMachKernel.sh v0.9 Copyright (c) 2012 by † RevoGirl\n"
  printf "                   v${gScriptVersion} Copyright (c) 2013-$(date "+%Y") by Pike R. Alpha\n"
  echo -e '----------------------------------------------------------------\n'
}

#
#--------------------------------------------------------------------------------
#

function _DEBUG_PRINT()
{
  if [[ $gDebug -eq 1 ]];
    then
      printf "$1"
  fi
}


#
#--------------------------------------------------------------------------------
#

function _PRINT_ERROR()
{
  #
  # Fancy output style?
  #
  if [[ $gExtraStyling -eq 1 ]];
    then
      #
      # Yes. Use a somewhat nicer output style.
      #
      printf "${STYLE_BOLD}Error:${STYLE_RESET} $1"
    else
      #
      # No. Use the basic output style.
      #
      printf "Error: $1"
  fi
}


#
#--------------------------------------------------------------------------------
#
function _ABORT()
{
  #
  # Fancy output style?
  #
  if [[ $gExtraStyling -eq 1 ]];
    then
      #
      # Yes. Use a somewhat nicer output style.
      #
      printf "Aborting ...\n${STYLE_BOLD}Done.${STYLE_RESET}\n\n"
    else
      #
      # No. Use the basic output style.
      #
      printf "Aborting ...\nDone.\n\n"
  fi

  exit 1
}


#
#--------------------------------------------------------------------------------
#

function _readFile()
{
  #
  # Copy arguments into local variables with a more self explanatory name.
  #
  local offset=$1
  local length=$2

  echo `dd if="${gTargetFile}" bs=1 skip=$offset count=$length 2> /dev/null | xxd -l $length -ps -c $length`
}


#
#--------------------------------------------------------------------------------
#

function _getSizeOfLoadCommands()
{
  local machHeaderData=$(_readFile $1 $2)
  #
  # Example:
  #
  # cffaedfe07000001030000000200000013000000680f00000100200000000000
  #                                       ^^
  #                                     ^^
  #                                           ^^
  #                                         ^^
  echo $((`echo 0x${machHeaderData:38:2}${machHeaderData:36:2}${machHeaderData:42:2}${machHeaderData:40:2}`))
}


#
#--------------------------------------------------------------------------------
#
# This is a modified copy of _getDataSegmentOffset()
#

function _getTextSegmentOffset()
{
  #
  # Copy arguments into local variables with a more self explanatory name.
  #
  local machOffset=$1
  local machHeaderLength=$2

  #
  # Get size of load commands from mach header.
  #
  let sizeOfLoadCommands=$(_getSizeOfLoadCommands $machOffset $machHeaderLength)

  local index=0
  let  sectionHeaderSize=80
  local __TEXT=5f5f54455854
  local __text=5f5f74657874

  #
  # Main loop, used to search for the "__DATA" segment.
  #
  while [ $index -lt $sizeOfLoadCommands ];
  do
    #
    # Initialize the file offset.
    #
    let offset=($machHeaderLength + $index)

    #
    # Read LC (Load Command) header from file.
    #
    local commandHeader=$(_readFile $offset $machHeaderLength)

    #
    # Get command type from LC header.
    #
    local commandType=$((`echo 0x${commandHeader:6:2}${commandHeader:4:2}${commandHeader:2:2}${commandHeader:0:2}`))

    #
    # Get command size from LC header.
    #
    local commandSize=$((`echo 0x${commandHeader:14:2}${commandHeader:12:2}${commandHeader:10:2}${commandHeader:8:2}`))

    #
    # Get segment name from LC header.
    #
    local segmentName=`echo ${commandHeader:16:12}`

    #
    # Check segment name (we are looking for "__TEXT").
    #
    if [[ $segmentName == $__TEXT ]];
      then
        let commandIndex=0

        local vmAddressOffset=$offset
        local vmAddress=$(_readFile $vmAddressOffset $sectionHeaderSize)
        #
        # Example:
        #
        #  19000000880100005f5f54455854000000000000000000000000200080ffffff00605a0000000000000000000000000000605a0000000000070000000500000004000000000000005f5f746578740000
        #                                                                ^^
        #                                                              ^^
        #                                                            ^^
        #                                                          ^^
        #                                                        ^^
        #                                                      ^^
        #                                                    ^^
        #                                                  ^^
        vmAddress="${vmAddress:62:2}${vmAddress:60:2}${vmAddress:58:2}${vmAddress:56:2}${vmAddress:54:2}${vmAddress:52:2}${vmAddress:50:2}${vmAddress:48:2}"
        vmAddress=$(echo $vmAddress | tr '[:lower:]' '[:upper:]')
        echo "0x"$vmAddress
        return
      else
        #
        # Adjust offset, add size of LC_SEGMENT_64
        #
        let sectionOffset=($offset + 72)
    fi
  done
        #
        # Secondary loop, used to search for the "__text" section.
        #
#       while [ $commandIndex -lt $commandSize ];
#       do
#         local sectionHeader=$(_readFile $sectionOffset $sectionHeaderSize)

#         sectionName=`echo ${sectionHeader:0:12}`

#         if [[ $sectionName == $__text ]];
#           then
              # Example:
              #
              # 5f5f74657874000000000000000000005f5f54455854000000000000000000000020200080ffffff1ab14f0000000000002000000c000000000000000000000000040080000000000000000000000000
              #                                                                               ^^
              #                                                                             ^^
              #                                                                           ^^
              #                                                                         ^^
              #                                                                       ^^
              #                                                                     ^^
              #                                                                   ^^
              #                                                                 ^^
#             textSectionOffset="${sectionHeader:78:2}${sectionHeader:76:2}${sectionHeader:74:2}${sectionHeader:72:2}${sectionHeader:64:2}${sectionHeader:66:2}${sectionHeader:68:2}${sectionHeader:70:2}"
#             textSectionOffset=$(echo $textSectionOffset | tr '[:lower:]' '[:upper:]')
#             echo "0x"$textSectionOffset
#             return
#           else
#             let local commandIndex=($commandIndex + $sectionHeaderSize)
#             let local sectionOffset=($sectionOffset + $sectionHeaderSize)
#         fi
#       done
#     else
#       let local index=($index + $commandSize)
#   fi
# done
}

#
#--------------------------------------------------------------------------------
#

function main()
{
  _showHeader

  segmentOffset=$(_getTextSegmentOffset 0 32)
  _DEBUG_PRINT "segmentOffset  @ ${segmentOffset}\n"

  if [[ $segmentOffset =~ "0xFFFFFF80" ]];
    then
      segmentOffset=$(echo $segmentOffset | sed 's/0xFFFFFF80//')
      segmentOffset=$(echo "ibase=16; ${segmentOffset}" | bc)

      if (( $gDebug ));
        then
          printf "Converted to...: 0x%x / ${segmentOffset}\n\n" $segmentOffset
      fi
  fi

  kprintfAddress="0x"$(nm -x -Ps __TEXT __text -arch x86_64 "${gTargetFile}" | grep ' _kprintf$' | awk '{ printf toupper($1)}')
  printf "_kprintf found @ ${kprintfAddress}\n"

  if [[ $kprintfAddress =~ "0xFFFFFF80" ]];
    then
      kprintfAddress=$(echo ${kprintfAddress}  | sed 's/0xFFFFFF80//')
      kprintfAddress=$(echo "ibase=16; ${kprintfAddress}" | bc)
      printf "Converted to...: 0x%x / ${kprintfAddress}\n" $kprintfAddress
  fi

  let kprintfOffset=$kprintfAddress-$segmentOffset
  printf "File offset....: 0x%x / ${kprintfOffset}\n\n" $kprintfOffset

  if (( $gDebug ));
    then
      printf "Raw data: "
      dd if="${gTargetFile}" bs=1 skip=$kprintfOffset count=16 2> /dev/null | xxd -l 16
      echo ''
  fi

  printfAddress="0x"$(nm -x -Ps __TEXT __text -arch x86_64 "${gTargetFile}" | grep ' _printf$' | awk '{ printf toupper($1)}')
  printf "_printf  found @ ${printfAddress}\n"

  if [[ $printfAddress =~ "0xFFFFFF80" ]];
    then
      printfAddress=$(echo $printfAddress | sed 's/0xFFFFFF80//')
      printfAddress=$(echo "ibase=16; ${printfAddress}" | bc)
      printf "Converted to...: 0x%x / ${printfAddress}\n" $printfAddress
  fi

  let printfOffset=$printfAddress-$segmentOffset
  printf "File offset....: 0x%x / ${printfOffset}\n\n" $printfOffset

  if [[ $kprintfAddress > $printfAddress ]];
    then
      let diff=$kprintfAddress-$printfAddress
      let addressDiff=(0xffffffff-$diff)-4
    else
      let addressDiff=($printfAddress-$kprintfAddress)+4
  fi
  #
  # Convert decimal value to hexadecimal.
  #
  jmpqAddress=$(echo "ibase=10; obase=16; ${addressDiff}" | bc)
  _DEBUG_PRINT "jmpqAddress: ${jmpqAddress}\n"

  replacementBytes="E9${jmpqAddress:6:2}${jmpqAddress:4:2}${jmpqAddress:2:2}${jmpqAddress:0:2}90"
  _DEBUG_PRINT "replacementBytes: ${replacementBytes}\n"

  local currentBytes=$(echo $(_readFile $kprintfOffset 6) | awk '{ printf toupper($1)}')
  _DEBUG_PRINT "currentBytes: ${currentBytes}\n\n"

  if [[ $currentBytes == $replacementBytes ]];
    then
      _PRINT_ERROR '_kprintf is already patched!\n'
      _ABORT
    else
      #
      # We're ready to patch the mach_kernel.
      #
      replacementBytes="E9${jmpqAddress:6:2} ${jmpqAddress:4:2}${jmpqAddress:2:2} ${jmpqAddress:0:2}90"
      _DEBUG_PRINT "replacementBytes: ${replacementBytes}\n"

      echo "0:${replacementBytes}" | xxd -c 12 -r | dd of="${gTargetFile}" bs=1 seek=${kprintfOffset} conv=notrunc

      #
      # Fancy output style?
      #
      if [[ $gExtraStyling -eq 1 ]];
        then
          #
          # Yes. Use a somewhat nicer output style.
          #
          printf "${STYLE_BOLD}Done.${STYLE_RESET}\n\n"
        else
          #
          # No. Use the basic output style.
          #
          printf "Done.\n\n"
      fi
  fi
}

#==================================== START =====================================

clear

if [[ $gID -ne 0 ]];
  then
    echo "This script ${STYLE_UNDERLINED}must${STYLE_RESET} be run as root!" 1>&2
    #
    # Re-run script with arguments.
    #
    sudo "$0" "$@"
  else
    #
    # We are root. Call main with arguments.
    #
    main "$@"
fi
