#!/usr/bin/env bash
########################################################################
# Rename/normalize camera picture file to 'yyyymmdd_HHMM_nnn.jpg'      #
#                                                                      #
# Command line arguments (all optional, non-ordered):                  #
#   <author_code> - loading ren_<author_code>.json as profile          #
#   -exif - enforce datetime stamp from EXIF data; skip if not exist   #
#   -?|-h - display script usage (this screen)                         #
#                                                                      #
# Dependencies:                                                        #
#   awk, exiftool, expr, jq                                            #
#                                                                      #
########################################################################
#
# EXIF References:
#   - http://www.sno.phy.queensu.ca/~phil/exiftool/TagNames/EXIF.html
#   - http://www.exiv2.org/tags.html
#
# Software/tools:
#   - exiftool:
#     - http://www.sno.phy.queensu.ca/~phil/exiftool/
#     - http://www.sno.phy.queensu.ca/~phil/exiftool/exiftool_pod.html
#     - http://www.sno.phy.queensu.ca/~phil/exiftool/faq.html
#   - exiv2 http://www.exiv2.org/tags.html
#   - Exifer [Windows](http://www.exifer.friedemann.info/)
#   - Exif [JHead](http://www.sentex.net/~mwandel/jhead/)
#
# other tips:
#   - fixing timestamp: exiftool "-DateTimeOriginal+=<y:m:d H:M:S>" <DIR>
#   - get timezone offset: `date +%z`
#
set -eo pipefail
script_file="${BASH_SOURCE[0]##*/}"
script_base="$( cd "$( echo "${BASH_SOURCE[0]%/*}" )" && pwd )"
script_path="${script_base}/${script_file}"

author_code="${AUTHOR_CODE:-jz}"  # default author code for profile
prefer_exif="${PREFER_EXIF:-no}"  # default not to enforce EXIF datetime stamp


function main() {
  shopt -s nocasematch
  # such regex search prevents from any other argument starts with letter 'h'
  if [[ "$@" =~ (help|-h|/h|-\?|/-?) ]]; then
    usage && return
  fi

  check_depends

  for p in $@; do
    if [[ "$p" =~ exif ]]; then prefer_exif="yes"; fi

    local json_file="${script_base}/ren_$p.json"
    if [[ -f "${json_file}" ]]; then
      json_data="$(jq -r -M . "${json_file}" 2>/dev/null)"
      if [[ "${json_data}" != "" ]]; then
        author_code="$p"
        log_info "using author profile: $p [ren_$p.json]"
        echo -e "${json_data}"
      fi
    fi
  done

  # check_camera_C360
  check_camera_IMG_files

}

# change_by_profile() func: update image metadata from profile
function change_by_profile() {
  local jpgfile="${1}"
  local profile="${2:-${script_base}/ren_${author_code}.json}"

  if [[ ! -e "${jpgfile}" ]] || [[ ! -e "${profile}" ]]; then return; fi

  local _Author="$(jq -r .Author ${profile})"
  local _AuthorFullName="$(jq -r .AuthorFullName ${profile})"
  local _AuthorTitle="$(jq -r .AuthorTitle ${profile})"
  local _BaseURL="$(jq -r .BaseURL ${profile})"
  local _Comment="$(jq -r .Comment ${profile})"
  local _Copyright="$(jq -r .Copyright ${profile})"
  local _CreatorAddress="$(jq -r .CreatorAddress ${profile})"
  local _CreatorCity="$(jq -r .CreatorCity ${profile})"
  local _CreatorRegion="$(jq -r .CreatorRegion ${profile})"
  local _CreatorPostalCode="$(jq -r .CreatorPostalCode ${profile})"
  local _CreatorCountry="$(jq -r .CreatorCountry ${profile})"
  local _CreatorEmail="$(jq -r .CreatorEmail ${profile})"
  local _CreatorURL="$(jq -r .CreatorURL ${profile})"
  local _Credit="$(jq -r .Credit ${profile})"
  local copyright="$(exiftool -j "${jpgfile}"|jq -r '.[0].Copyright+""')"

  # caution: this does NOT overwirte any existing copyright info
  if [[ "${copyright}" == "" ]] || [[ "${copyright}" == "null" ]]; then
    copyright="(C) "`date +"%Y"`" ${_Copyright}. All rights reserved."
  elif [[ ! "${copyright}" =~ (${_Copyright}) ]]; then
    log_debug "using existing copyright '${copyright}' intead of new from '${_Copyright}'"
  fi
  log_info "updating '$1' for ${_Author} ${copyright}"

  exiftool -F -q -s \
  -Artist="${_AuthorFullName}" \
  -AuthorsPosition="${_AuthorTitle}" \
  -BaseURL="${_BaseURL}" \
  -By-line="${_AuthorFullName}" \
  -By-lineTitle="${_AuthorTitle}" \
  -CaptionWriter="${_Author}" \
  -Copyright="${copyright}" \
  -CopyrightNotice="${copyright}" \
  -Creator="${_Author}" \
  -CreatorAddress="${_CreatorAddress}" \
  -CreatorCity="${_CreatorCity}" \
  -CreatorCountry="${_CreatorCountry}" \
  -CreatorPostalCode="${_CreatorPostalCode}" \
  -CreatorRegion="${_CreatorRegion}" \
  -CreatorWorkEmail="${_CreatorEmail}" \
  -CreatorWorkURL="${_CreatorURL}" \
  -Credit="Lin Zhou" \
  -Rights="${copyright}" \
  -URL="${_BaseURL}" \
  -UserComment="${_Comment}" \
  -Writer-Editor="${_Author}" \
  "$1"
}

# check and rename C360_*.jpg image files
function check_camera_C360() {
  time_seqn=0
  prev_name=""
  for f in C360_????-??-??-??-??-??-???.jpg; do
    check_exif_date "$f"

    exif_desc="$(exiftool -j $f|jq -r '.[0].ImageDescription+""')"
    date_form="$(echo ${exif_date}|awk 'BEGIN {FS="[: .\"]"}{OFS="_"}{print $1$2$3,$4$5,$6 substr(int($7),0,1)}')"
    date_name="$(echo "$f"|awk 'BEGIN{FS="[-_]"}{OFS="_"}{print $2$3$4,$5$6,$7 substr($8,0,1)}')"
    name_date="$(echo "$f"|awk 'BEGIN{FS="[-_]"}{OFS="_"}{printf "%04d:%02d:%02d %02d:%02d:%02d",$2,$3,$4,$5,$6,$7}')"
    name_secf="${date_name:14:2}"

    if [[ "${exif_desc}" == "nor" ]]; then
      log_debug "fixing image caption: ${exif_desc}"
      # exiftool -q -s -ImageDescription="" "$f"
      # exiftool -q -s -Description="" "$f"
    fi

    do_rename_file "$f"

    break
  done
}

# check and rename IMG_*.jpg image files
function check_camera_IMG_files() {
  time_seqn=0
  prev_name=""
  for f in IMG_????????_??????.jpg; do
    check_exif_date "$f"
    exif_desc="$(exiftool -j $f|jq -r .[0].ImageDescription)"
    date_form="$(echo ${exif_date}|awk 'BEGIN {FS="[: .\"]"}{OFS="_"}{print $1$2$3,$4$5,$6 substr(int($7),0,1)}')"
    date_name="$(echo "$f"|awk 'BEGIN{FS="[-_.]"}{OFS="_"}{print $2,substr($3,0,4),substr($3,5,2)}')""0"
    name_date="$(echo "$f"|awk 'BEGIN{FS="[-_.]"}{OFS="_"}{printf "%04d:%02d:%02d %02d:%02d:%02d",substr($2,0,4),substr($2,5,2),substr($2,7,2),substr($3,0,2),substr($3,3,2),substr($3,5,2)}')"
    name_secf="${date_name:14:2}"

    if [[ "${exif_desc}" == "cof" ]] || [[ "${exif_desc}" == "ozedf" ]]; then
      log_info "fixing image caption: ${exif_desc}"
      # exiftool -q -s -ImageDescription="" "$f"
      # exiftool -q -s -Description="" "$f"
    fi

    do_rename_file "$f"

    break
  done
}

# check_depends() func: verifies if prerequisites exists
function check_depends() {
  local tool_set="awk exiftool expr jq"
  for tool in ${tool_set}; do
    if ! [[ -x "$(which ${tool})" ]]; then
      echo "......................................................................."
      echo "Checking dependencies: ${tool_set}"
      log_error "Cannot find command '${tool}'"
    fi
  done
}

# check_exif_date() func:
function check_exif_date() {
  if [[ ! -e "$1" ]]; then return; fi

  for tag in SubSecDateTimeOriginal SubSecCreateDate DateTimeOriginal CreateDate; do
    exif_date="$(exiftool -j $1|jq -r .[0].${tag})"
    if [[ "${exif_date}" != "" ]] && [[ "${exif_date}" != "null" ]]; then
      break  # since successfully extracted the date from EXIF data
    fi
  done
}

# check_return_code() func: checks exit code from last command
function check_return_code() {
  local return_code="${1:-0}"
  local action_name="${2:-AWS CLI}"

  if [[ "${return_code}" != "0" ]]; then
    log_error "${action_name} [code: ${return_code}]" "FAILED" ${return_code}
  else
    echo "Success: ${action_name}"
    echo ""
  fi
}

# do_rename_file() func: normalize image file name after check
#   - depends on these variables:
#     ${exif_date}: the original image-taken date/time from exif data
#     ${date_form}: the 'yyyymmdd_HHMM_nn' part from exif data
#     ${date_name}: the 'yyyymmdd_HHMM_nn' part from file name/date
#     ${prev_name}: the 'yyyymmdd_HHMM' part in previous used name
#     ${time_seqn}: the current sequence in the same second
#     ${name_secf}: the calculated 'nnn' part
function do_rename_file() {
  if [[ ! -e "$1" ]]; then return; fi

  # check if datetime stamp matches in EXIF
  if [[ "${date_form:0:16}" != "${date_name:0:16}" ]]; then
    log_warn "$1:\n   diff datetime: '${date_name}' [${name_date}] vs exif ${date_form} [${exif_date}]"
    if [[ "${prefer_exif}" == "yes" ]]; then return; fi
  fi

  if [[ "${#date_name}" == "17" ]]; then
    change_by_profile "$1"
    log_info "updating '$1' with -FileModifyDate=${name_date}"
    exiftool -q -FileModifyDate="${name_date}" "$1"
    exiftool -q -ModifyDate="${name_date}" "$1"
  fi

  # calculating 3-digit seconds field
  if [[ "${date_form:0:16}" == "${prev_name}" ]]; then
    time_seqn=$((${time_seqn}+1))
  else
    prev_name="${date_form:0:16}"
    time_seqn=1
  fi
  for n in {0..100}; do
    # taking 2-digit seconds, multiply by 10, then add sequence number
    name_secf="$(printf "%03d" $((10#${name_secf} * 10 + ${time_seqn})))"
    if [[ ! -e "${date_form:0:14}${name_secf}.jpg" ]]; then break; fi
    time_seqn=$((${time_seqn}+1))
  done

  log_info "mv $1 => ${date_form:0:14}${name_secf}.jpg"
}

# log_debug() func: print message as debug warning
function log_debug() {
  if [[ "$1" != "" ]]; then
    log_error "$1" "${2:-DEBUG}"
  fi
}

# log_info() func: print message as informational message
function log_info() {
  if [[ "$1" != "" ]]; then
    log_error "$1" "${2:-INFO}"
  fi
}

# log_warn() func: print message as warning message
function log_warn() {
  if [[ "$1" != "" ]]; then
    log_error "$1" "${2:-WARNING}"
  fi
}

# log_error() func: exits with non-zero code on error unless $2 specified
function log_error() {
  if [[ "$1" == "" ]]; then return; fi

  local err_name="${2:-ERROR}"
  local err_code="${3:-1}"

  if [[ "${err_name}" == "INFO" ]]; then
    echo -e "\n-- ${err_name}: $1"
  elif [[ "${err_name}" == "DEBUG" ]]; then
    echo -e "\n++ ${err_name}: $1"
  elif [[ "${err_name}" == "WARNING" ]]; then
    echo -e "\n** ${err_name}: $1"
  else
    HAS_ERROR="true"
    echo -e "\n!! ${err_name}: $1"
    exit ${err_code}
  fi
}

# usage() func: show help
function usage() {
  echo ""
  echo "USAGE: ${script_file} --help"
  echo ""
  local headers="0"
  # echo "$(cat ${script_path} | grep -e '^##')"
  while IFS='' read -r line || [[ -n "${line}" ]]; do
    if [[ "${headers}" == "0" ]] && [[ "${line}" =~ ^#{60} ]]; then
      headers="1"
      echo "${line}"
    elif [[ "${headers}" == "1" ]] && [[ "${line}" =~ ^#{60} ]]; then
      headers="0"
      echo "${line}"
    elif [[ "${headers}" == "1" ]]; then
      echo "${line}"
    fi
  done < "${script_path}"
  echo ""
}


[[ $0 != "${BASH_SOURCE}" ]] || main "$@"
