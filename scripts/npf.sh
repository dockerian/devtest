#!/usr/bin/env bash
########################################################################
# Rename/normalize camera picture file to 'yyyymmdd_HHMM_nnn.jpg'      #
#                                                                      #
# Command line arguments (all optional, non-ordered):                  #
#   <author_code> : loading npf_<author_code>.json as profile          #
#   -?|-h : display script usage (this screen)                         #
#   -c|--clean : clean up backup files (*.jpg_original)                #
#   -d|--date : apply digitized date/time on specified images ($2 ...) #
#   -exif : enforce datetime stamp from EXIF data; skip if not exist   #
#   -f|--rename : perform renaming (mv) operation to normalize images  #
#   -geo : use GPS longitude/latitude data to look up addresses        #
#   -install : install this script to a path, e.g. /usr/local/bin/npf  #
#   -k|--check : check digitized date/time on image files ($2 ...)     #
#   -r|--rating : set rating to all spcified images ($3 ...)           #
#   -restore : revert everything back, restore original files          #
#   -seq : use sequence number per date instead of per second          #
#   -ts (+|-)<yy:mm:dd HH:MM:ss> : shift date/time on ${CAMERA_FILE}*  #
#   -tz (+|-)<number> : set TimeZoneOffset for ${CAMERA_FILE}*         #
#                                                                      #
# Configurable environment variables:                                  #
#   AUTHOR_CODE : author code to load author profile                   #
#   CAMERA_FILE : camera filename prefix pattern to search             #
#   DELETE_ORIG : delete *_original files at the last clean-up step    #
#   GEOTAG_DATA : yes|no, enable geo tagging from GPS data             #
#   GEOTAG_KEEP : yes|no, do not overwrite existing geo address info   #
#   PREFER_EXIF : no|yes, same as '-exif' to enforce using EXIF only   #
#   RENAME_ONLY : no|yes, rename the files only, no other process      #
#   RENAME_TEST : yes|no, run as test without renaming, same as DEBUG  #
#   SEQNUM_LAST : 0 - 99, the last seq number assigned for the date    #
#                                                                      #
# Dependencies:                                                        #
#   awk, exiftool, expr, jq, printf, pwd                               #
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
#   - set captions for all images: exiftool -ImageDescription="N/A" *.jpg
#   - fixing timestamp: exiftool "-DateTimeOriginal+=<y:m:d H:M:S>" <DIR>
#   - fixing ModifyDate: exiftool "-FileModifyDate<DateTimeOriginal" *.jpg
#   - get from other: exiftool -TagsFromFile src.jpg "-all:all>all:all" dst.jpg
#   - get timezone offset: `date +%z`
#
set -eo pipefail
script_file="${BASH_SOURCE[0]##*/}"
script_base="$( cd "$( echo "${BASH_SOURCE[0]%/*}" )" && pwd )"
script_path="${script_base}/${script_file}"
uncode_file="npf-cc.csv"

apiurl_gmap="https://maps.googleapis.com/maps/api/geocode/json?latlng="
author_code="${AUTHOR_CODE:-jz}"   # default author code for profile
author_skip="${AUTHOR_SKIP:-no}"   # skip applying for author profile
camera_file="${CAMERA_FILE:-DSC_}" # default prefix in camera picture filename
delete_orig="${DELETE_ORIG:-yes}"  # delete *_original files at the last
geotag_data="${GEOTAG_DATA:-yes}"  # get address geo tags from GPS data
geotag_keep="${GEOTAG_KEEP:-yes}"  # keep existing geo tags without overwriting
prefer_exif="${PREFER_EXIF:-no}"   # default not to enforce EXIF datetime stamp
rename_test="${RENAME_TEST:-yes}"  # run as a test without executing `mv`
rename_keep="${RENAME_KEEP:-no}"   # add date/time but keep original name
rename_only="${RENAME_ONLY:-no}"   # default NOT to rename only
seqnum_last="${SEQNUM_LAST:--1}"   # the last sequence number per date
script_user="${SCRIPT_USER:-Jason Zhu}"  # set the caption writer


function main() {
  shopt -s nocasematch
  # such regex search prevents from any other argument starts with letter 'h'
  if [[ "$@" =~ (help|-h|/h|-\?|/\?) ]]; then
    usage && return
  fi

  check_depends $@

  if [[ "$1" =~ install ]] || [[ "$1" =~ setup ]]; then
    do_install "$1" "$2"; return
  fi

  change_jpeg_extension

  if [[ "$p" =~ exif ]]; then prefer_exif="yes"; fi

  if [[ "$1" == "-c" ]] || [[ "$1" =~ (-clean) ]]; then
    clean_up; return
  fi

  if [[ "$1" == "-d" ]] || [[ "$1" =~ "-date" ]]; then
    do_original_date && clean_up; return
  fi

  if [[ "$1" == "-r" ]] || [[ "$1" =~ (-rat) ]]; then
    rename_test="yes"
    shift; do_rating $@ && clean_up; return
  fi

  if [[ "$1" == "-k" ]] || [[ "$1" =~ (-check) ]]; then
    shift
    do_check_date $@ ; return
  fi

  if [[ "$1" =~ "-ts" ]] || [[ "$1" =~ "-timeshift" ]]; then
    do_offset_datetime "${2// /.}" && do_original_date && clean_up; return
  fi

  if [[ "$1" =~ "-tz" ]] || [[ "$1" =~ "-timezone" ]]; then
    do_offset_timezone $2 && do_original_date && clean_up; return
  fi

  if [[ "$@" =~ restore ]]; then
    do_restore; return
  fi

  check_args_env $@
  check_author_profile $@

  check_camera_C360
  check_camera_IMG_files
  check_camera_images_by_pattern
  check_camera_pt_images

  clean_up
}

# change_by_profile() func: update image metadata from profile
function change_by_profile() {
  # only process author/creator data with valid author profile
  if [[ "${author_code}" == "" ]]; then return; fi
  if [[ "${author_skip}" == "yes" ]]; then return; fi

  local jpgfile="${1}"
  local profile="${2:-${script_base}/npf_${author_code}.json}"

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
  local _CreatorPhone="$(jq -r .CreatorPhone ${profile})"
  local _CreatorEmail="$(jq -r .CreatorEmail ${profile})"
  local _CreatorURL="$(jq -r .CreatorURL ${profile})"
  local _Credit="$(jq -r .Credit ${profile})"
  local comment="$(exiftool -j "${jpgfile}"|jq -r '.[0].UserComment+""')"
  local copyright="$(exiftool -j "${jpgfile}"|jq -r '.[0].Copyright+""')"

  if [[ "${comment}" == "" ]] || [[ "${comment}" == "null" ]]; then
    comment="${_Comment}"
  fi
  # caution: this does NOT overwirte any existing copyright info
  if [[ "${copyright}" == "" ]] || [[ "${copyright}" == "null" ]]; then
    copyright="(C) "`date +"%Y"`" ${_Copyright}. All rights reserved."
  elif [[ ! "${copyright}" =~ (${_Copyright}) ]]; then
    log_debug "using existing copyright '${copyright}' intead of new from '${_Copyright}'"
  fi
  log_info "updating '$1' for ${_Author} ${copyright}"

  if [[ "${rename_only}" == "yes" ]]; then return; fi

  exiftool -F -q -s \
  -overwrite_original_in_place \
  -Artist="${_AuthorFullName}" \
  -AuthorsPosition="${_AuthorTitle}" \
  -BaseURL="${_BaseURL}" \
  -By-line="${_AuthorFullName}" \
  -By-lineTitle="${_AuthorTitle}" \
  -CaptionWriter="${script_user}" \
  -Copyright="${copyright}" \
  -CopyrightNotice="${copyright}" \
  -CopyrightFlag=true \
  -Contact="${_CreatorAddress}" \
  -Creator="${_Author}" \
  -CreatorAddress="${_CreatorAddress}" \
  -CreatorCity="${_CreatorCity}" \
  -CreatorCountry="${_CreatorCountry}" \
  -CreatorPostalCode="${_CreatorPostalCode}" \
  -CreatorRegion="${_CreatorRegion}" \
  -CreatorWorkEmail="${_CreatorEmail}" \
  -CreatorWorkTelephone="${_CreatorPhone}" \
  -CreatorWorkURL="${_CreatorURL}" \
  -Credit="${_Credit}" \
  -Rights="${copyright}" \
  -URL="${_BaseURL}" \
  -UserComment="${comment}" \
  -Writer-Editor="${script_user}" \
  "$1"
}

# change_jpeg_extension() func: change upper case extension to lower case
function change_jpeg_extension() {
  for image in *.JPG; do
    if [[ -e "${image}" ]]; then
      log_debug "changing image file extension to .jpg ..."
      /bin/mv "${image}" "${image/.JPG/.jpg}"  # 2>/dev/null
    fi
  done
}

# check_args_env() func: check environment variables and arguments
function check_args_env() {
  shopt -s nocasematch

  uncode_file="${script_base}/${uncode_file}"
  log_info "Using CountryCode lookup: ${uncode_file}"

  if [[ "$1" == "-f" ]] || [[ "$1" =~ (-okay) ]] || [[ "$1" =~ (-rename) ]]; then
    rename_test="no"
  fi

  if [[ "$@" =~ geo ]] || [[ "${geotag_data}" =~ (1|on|true|yes) ]]; then
    geotag_data="yes"
  fi

  if [[ "${author_skip}" != "" ]] && [[ ! "${author_skip}" =~ (0|off|false|no) ]]; then
    author_skip="yes"
  fi

  if [[ "${geotag_data}" == "yes" ]] && [[ ! -x "$(which curl)" ]]; then
    log_warn "Cannot find command 'curl'. GEOTAG_DATA is disabled."
    geotag_data="no"
  fi

  if [[ "${geotag_keep}" != "" ]] && [[ ! "${geotag_keep}" =~ (0|off|false|no) ]]; then
    geotag_keep="yes"
  else
    log_warn "Geo tags would be overwritten. GEOTAG_KEEP is disabled."
  fi

  if [[ "${rename_keep}" != "" ]] && [[ ! "${rename_keep}" =~ (0|off|false|no) ]]; then
    rename_keep="yes"
  fi

  if [[ "${rename_only}" =~ (1|on|true|yes) ]]; then
    rename_only="yes"
  fi

  if [[ "${DEBUG}" != "" ]] && [[ ! "${DEBUG}" =~ (0|off|false|no) ]]; then
    rename_test="yes"
    DEBUG=1
  fi

  if [[ "$@" =~ seq ]]; then
    if [[ ! "${seqnum_last}" =~ ^[0-9]{3}$ ]]; then
      seqnum_last="0"
    fi
  else
    seqnum_last=""  # disable sequencing per date
  fi
}

# check_author_profile() func: check if author profile is valid
function check_author_profile() {
  local preset_code="${author_code}"
  for p in $@; do
    local json_file="${script_base}/npf_$p.json"
    if [[ -f "${json_file}" ]]; then
      json_data="$(jq -r -M . "${json_file}" 2>/dev/null)"
      if [[ "${json_data}" != "" ]]; then
        author_code="$p"
        log_info "using author profile: $p [npf_$p.json]"
        echo -e "${json_data}"
      fi
    fi
  done

  if [[ "${author_code}" != "${preset_code}" ]]; then return; fi

  json_file="${script_base}/npf_${author_code}.json"
  json_data="$(jq -r -M . "${json_file}" 2>/dev/null)"
  if [[ "${json_data}" == "" ]]; then
    log_warn "Invalid author profile: ${author_code} [npf_${author_code}.json]"
    author_code=""
  fi
}

# check and rename C360_*.jpg image files
function check_camera_C360() {
  time_seqn=0
  prev_name=""
  if ! ls C360_????-??-??-??-??-??-???.jpg 1>/dev/null 2>&1; then return; fi
  for f in C360_????-??-??-??-??-??-???.jpg; do
    check_exif_date "$f"

    exif_desc="$(exiftool -j "$f"|jq -r '.[0].ImageDescription+""')"
    date_form="$(echo ${exif_date}|awk 'BEGIN {FS="[: .\"]"}{OFS="_"}{print $1$2$3,$4$5,$6 substr(int($7),0,1)}')"
    date_name="$(echo "$f"|awk 'BEGIN{FS="[-_]"}{OFS="_"}{print $2$3$4,$5$6,$7 substr($8,0,1)}')"
    name_date="$(echo "$f"|awk 'BEGIN{FS="[-_]"}{OFS="_"}{printf "%04d:%02d:%02d %02d:%02d:%02d",$2,$3,$4,$5,$6,$7}')"
    name_secf="${date_name:14:2}"

    if [[ "${exif_desc}" == "nor" ]]; then
      log_debug "Fixing image caption: ${exif_desc}"
      if [[ "${rename_test}" != "yes" ]]; then
        exiftool -q -s \
          -overwrite_original_in_place \
          -ImageDescription="" "$f" \
          -Description="" "$f"
      fi
    fi

    do_rename_file "$f"

    if [[ "${rename_test}" == "yes" ]] && [[ "${rename_only}" == "yes" ]]; then
      break
    fi
  done
}

# check and rename IMG_*.jpg image files
function check_camera_IMG_files() {
  time_seqn=0
  prev_name=""
  if ! ls IMG_????????_??????.jpg 1>/dev/null 2>&1; then return; fi
  for f in IMG_????????_??????.jpg; do
    check_exif_date "$f"
    exif_desc="$(exiftool -j "$f"|jq -r .[0].ImageDescription)"
    date_form="$(echo ${exif_date}|awk 'BEGIN {FS="[: .\"]"}{OFS="_"}{print $1$2$3,$4$5,$6 substr(int($7),0,1)}')"
    date_name="$(echo "$f"|awk 'BEGIN{FS="[-_.]"}{OFS="_"}{print $2,substr($3,0,4),substr($3,5,2)}')""0"
    name_date="$(echo "$f"|awk 'BEGIN{FS="[-_.]"}{OFS="_"}{printf "%04d:%02d:%02d %02d:%02d:%02d",substr($2,0,4),substr($2,5,2),substr($2,7,2),substr($3,0,2),substr($3,3,2),substr($3,5,2)}')"
    name_secf="${date_name:14:2}"

    if [[ "${exif_desc}" == "cof" ]] || [[ "${exif_desc}" == "ozedf" ]]; then
      log_info "fixing image caption: ${exif_desc}"
      if [[ "${rename_only}" != "yes" ]]; then
        exiftool -q -s \
        -overwrite_original_in_place \
        -ImageDescription="" "$f" \
        -Description="" "$f"
      fi
    fi

    do_rename_file "$f"

    if [[ "${rename_test}" == "yes" ]] && [[ "${rename_only}" == "yes" ]]; then
      break
    fi
  done
}

# check and rename DSLR image files per ${camera_file} prefix
function check_camera_images_by_pattern() {
  time_seqn=0
  prev_name=""
  log_info "checking ${camera_file}*.JPG|jpg files [in $PWD] ..."

  if ! ls ${camera_file}*.jpg 1>/dev/null 2>&1 ; then return; fi
  for f in ${camera_file}*.jpg; do
    check_camera_dslr_file "$f"

    if [[ "${rename_test}" == "yes" ]] && [[ "${rename_only}" == "yes" ]]; then
      break
    fi
  done
}

# check and rename DSLR image file (normally without GPS data)
function check_camera_dslr_file() {
  if [[ ! -e "$1" ]]; then return; fi

  check_exif_date "$1"
  exif_desc="$(exiftool -j "$1"|jq -r .[0].ImageDescription)"
  date_form="$(echo ${exif_date}|awk 'BEGIN {FS="[: .\"]"}{OFS="_"}{print $1$2$3,$4$5,$6 substr(int($7),0,1)}')"
  file_date="$(exiftool -j "$1"|jq -r .[0].FileModifyDate)"
  date_name="${date_form}"
  name_date="${exif_date}"
  name_secf="${date_name:14:2}"

  do_rename_file "$1"
}

# check and rename pt*.jpg image files
function check_camera_pt_images() {
  time_seqn=0
  prev_name=""
  if ! ls pt????_??_??_??_??_??.jpg 1>/dev/null 2>&1; then return; fi
  for f in pt????_??_??_??_??_??.jpg; do
    exif_desc="$(exiftool -j "$f"|jq -r '.[0].ImageDescription+""')"
    date_name="$(echo "$f"|awk 'BEGIN{FS="[t_]"}{OFS="_"}{print $2$3$4,$5$6,$7}')0"
    name_date="$(echo "$f"|awk 'BEGIN{FS="[t_]"}{OFS="_"}{printf "%04d:%02d:%02d %02d:%02d:%02d",$2,$3,$4,$5,$6,$7}')"
    name_secf="${date_name:14:2}"
    exif_date="${name_date}"
    date_form="${date_name}"

    do_rename_file "$f"
  done
}

# check_depends() func: verifies if prerequisites exists
function check_depends() {
  local tool_set="awk dirname exiftool expr jq mv printf ln unlink which"
  for tool in ${tool_set}; do
    if ! [[ -x "$(which ${tool})" ]]; then
      echo "......................................................................."
      echo "Checking dependencies: ${tool_set}"
      log_error "Cannot find command '${tool}'"
    fi
  done
  if [[ ! -x "/bin/mv" ]]; then
    log_error "Cannot find command '/bin/mv' - needed for case-sensitive rename"
  fi
  script_path="$(getpath ${script_path})"
  script_base="$(dirname ${script_path})"
}

# check_exif_data() func： get EXIF data to variable ${exif_data}
function check_exif_data() {
  if [[ ! -e "$1" ]]; then return; fi

  exif_data="$(exiftool -sort -n -j "$1")"
  exif_glat="$(echo ${exif_data}|jq -r '.[0].GPSLatitude')"
  exif_glon="$(echo ${exif_data}|jq -r '.[0].GPSLongitude')"
  #geo_tags="$(echo ${exif_data}|jq -r '(.[0].GPSLatitude|tostring)+","+(.[0].GPSLongitude|tostring)')"
  exif_gtag="${exif_glat},${exif_glon}"
}

# check_exif_date() func:
function check_exif_date() {
  if [[ ! -e "$1" ]]; then return; fi

  local tag_name=""
  local tzoffset="$(exiftool -j "$1"|jq -r '.[0].TimeZoneOffset|tostring')"
  for tag in SubSecCreateDate SubSecDateTimeOriginal SubSecModifyDate CreateDate DateTimeOriginal ModifyDate; do
    exif_date="$(exiftool -j "$1"|jq -r .[0].${tag})"
    if [[ "${exif_date}" != "" ]] && [[ "${exif_date}" != "null" ]]; then
      tag_name="${tag}"
      break  # since successfully extracted the date from EXIF data
    fi
  done

  if [[ "${exif_date}" == "null" ]]; then exif_date=""; fi
  if [[ "${exif_date}" != "" ]]; then
    for tag in SubSecCreateDate SubSecDateTimeOriginal SubSecModifyDate CreateDate DateTimeOriginal ModifyDate; do
      local dt="$(exiftool -j "$1"|jq -r .[0].${tag})"
      # comparing only 'yyyy:mm:dd HH:MM:' (ignoring seconds)
      if [[ "${dt:0:17}" != "${exif_date:0:17}" ]]; then
        log_warn "${tag_name} [${exif_date}] != ${tag} [${dt}] - $1"
      fi
    done
  fi

  if [[ "${tzoffset}" == "" ]]; then
    log_warn "TimeZoneOffset is not set in $1"
  fi
}

# check_geo_data（）func: check geo data to look up for addresses
# - note: depending on function check_exif_data() to retrieve GPS information
function check_geo_data() {
  if [[ ! -e "$1" ]]; then return; fi
  if [[ ! "${geotag_data}" == "yes" ]]; then return; fi

  check_exif_data "$1"
  if [[ "${exif_glat}" == "" ]] || [[ "${exif_glat}" == "null" ]]; then return; fi
  if [[ "${exif_glon}" == "" ]] || [[ "${exif_glon}" == "null" ]]; then return; fi

  log_info "using GPS data: ${exif_gtag}"

  local http_gmap="https://maps.google.com/maps?q="
  local curl_data="$(curl ${apiurl_gmap}${exif_gtag})"
  local curl_stat="$(echo ${curl_data}|jq -r .status)"

  if [[ "${curl_stat}" == "OK" ]]; then
    local gmap_rac0="$(echo ${curl_data}|jq -r .results[0].address_components)"
    local gmap_addr="$(echo ${curl_data}|jq -r .results[0].formatted_address)"

    for idx in {0..9}; do
      for ndx in {0..2}; do
        local _type="$(echo ${gmap_rac0}|jq -r .[${idx}].types[${ndx}])"
        if [[ "${_type}" != "political" ]]; then break; fi
      done
      if [[ "${_type}" == "route" ]]; then
        local _route="$(echo ${gmap_rac0}|jq -r .[${idx}].short_name)"
      elif [[ "${_type}" == "locality" ]]; then
        local _city="$(echo ${gmap_rac0}|jq -r .[${idx}].short_name)"
      elif [[ "${_type}" == "administrative_area_level_2" ]]; then
        local _region="$(echo ${gmap_rac0}|jq -r .[${idx}].short_name)"
      elif [[ "${_type}" == "administrative_area_level_1" ]]; then
        local _state="$(echo ${gmap_rac0}|jq -r .[${idx}].long_name)"
        local _state_code="$(echo ${gmap_rac0}|jq -r .[${idx}].short_name)"
      elif [[ "${_type}" == "country" ]]; then
        local _country="$(echo ${gmap_rac0}|jq -r .[${idx}].long_name)"
        local _country_code="$(echo ${gmap_rac0}|jq -r .[${idx}].short_name)"
      elif [[ "${_type}" == "postal_code" ]]; then
        local _zip="$(echo ${gmap_rac0}|jq -r .[${idx}].short_name)"
      fi
    done

    local _keywords="geo:lat=${exif_glat}; geo:lon=${exif_glon}; geotagged; ${_city}; ${_state_code}; ${_country}; ${_country_code}"

    if [[ "${rename_test}" == "yes" ]]; then
      echo ${gmap_rac0}
    fi
    if [[ "${rename_only}" == "yes" ]]; then return; fi

    if [[ -e "${uncode_file}" ]]; then
      _country_code3=$(cat "${uncode_file}"|grep "^${_country_code},"|awk 'BEGIN {FS=","}{print $2}')
      log_info "grep country code: gmap [${_country_code}], iso alpha-3 [${_country_code3}]"
    else
      log_info "grep country code: gmap [${_country_code}]"
      _country_code3="${_country_code}"
    fi

    local _ref="${exif_gtag}"
    local _spi="$(echo -e "${gmap_addr}\n${http_gmap}${exif_gtag}")"
    log_info "resolved geo addr: ${gmap_addr}\n\
                  keywords: ${_keywords}"
    log_info "resolved geo tags: ${_city} ${_region} ${_state} ${_country} ${_country_code}"

    if [[ "${geotag_keep}" == "yes" ]]; then
      local city="$(exiftool -j "$1"|jq -r '.[0].City+""')"
      local country="$(exiftool -j "$1"|jq -r '.[0].Country+""')"
      local country_code="$(exiftool -j "$1"|jq -r '.[0].CountryCode+""')"
      local country_code3="$(exiftool -j "$1"|jq -r '.[0]."Country-PrimaryLocationCode"+""')"
      local region="$(exiftool -j "$1"|jq -r '.[0]."Sub-location"+""')"
      local state="$(exiftool -j "$1"|jq -r '.[0]."Province-State"+""')"
      local keywords="$(exiftool -j "$1"|jq -r '.[0].Keywords|join("; ")' 2>/dev/null)"
      local ref="$(exiftool -j "$1"|jq -r '.[0].OriginalTransmissionReference+""')"
      local spi="$(exiftool -j "$1"|jq -r '.[0].SpecialInstructions+""')"

      if [[ "${city}" == "${_city}" ]] && \
         [[ "${country}" == "${_country}" ]] && \
         [[ "${country_code}" == "${_country_code}" ]] && \
         [[ "${country_code3}" == "${_country_code3}" ]] && \
         [[ "${region}" == "${_region}" ]] && \
         [[ "${state}" == "${_state}" ]] && \
         [[ "${keywords}" == "${_keywords}" ]] && \
         [[ "${spi}" != "" ]]; then
          log_warn "All geo tags were set. Skip as GEOTAG_KEEP == yes."
          return
      fi
      _city="${city:-${_city}}"
      _country="${country:-${_country}}"
      _country_code="${country_code:-${_country_code}}"
      _country_code3="${country_code3:-${_country_code3}}"
      _state="${state:-${_state}}"
      _region="${region:-${_region}}"
      _ref="${ref:-${_ref}}"
      _spi="${spi:-${_spi}}"  # only overwrite empty
      _keywords="${keywords:-${_keywords}}"

      log_info "updating map addr: ${_spi}\n\
                  keywords: ${_keywords}"
      log_info "applying geo tags: ${_city} ${_region} ${_state} ${_country} ${_country_code} [${_country_code3}]"
    fi

    # echo $(cat <<-EOF
    exiftool -F -q -s \
      -City="${_city}" \
      -Country="${_country}" \
      -CountryCode="${_country_code}" \
      -Country-PrimaryLocationCode="${_country_code3}" \
      -Country-PrimaryLocationName="${_country}" \
      -Province-State="${_state}" \
      -Sub-location="${_region}" \
      -OriginalTransmissionReference="${_ref}" \
      -sep "; " -Keywords="${_keywords}" \
      "$1"
    exiftool -F -q -s \
      -SpecialInstructions="${_spi}" \
      "$1"
# EOF
# )
  fi
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

# clean_up original files
function clean_up() {
  log_info "cleaning up original files ..."
  echo y | exiftool -delete_original *.JPG
  echo y | exiftool -delete_original *.jpg
  rm *.jpg_original 2>/dev/null
}

# check digitized date and timezone offset
function do_check_date() {
  if [[ ! -e "$1" ]]; then return; fi

  for f in $@; do
    if [[ -e "$f" ]]; then
      check_exif_date "$f"
    fi
  done
}

# install the script to a path (which dirname must be in $PATH)
function do_install() {
  local cmd_link="${2:-/usr/local/bin/npf}"
  local cmd_path="$(getpath "${cmd_link}")"

  if [[ -e "${cmd_link}" ]]; then
    if [[ "${cmd_link}" == "${cmd_path}" ]]; then
      log_warn "The path '${cmd_link}' already exists."
    elif [[ "$1" =~ "uninstall" ]]; then
      log_info "uninstalling/removing '${cmd_link}' ..."
      unlink "${cmd_link}" 2>/dev/null
      log_info "uninstalled/unlinked: '${cmd_link}'."
      return
    else
      log_warn "The link '${cmd_link}' => '${cmd_path}' already exists."
    fi
    echo "...................................................................."
    ls -al "${cmd_link}"
    echo "...................................................................."
  elif [[ ! "$1" =~ "uninstall" ]]; then
    log_info "installing '${script_path}' to '${cmd_link}' ..."
    unlink "${cmd_link}" 2>/dev/null || true
    log_info "set '${cmd_link}' to '${script_path}'"
    ln -s "${script_path}" "${cmd_link}"
  else
    log_warn "Not found '${cmd_link}'."
  fi
}

# shift DateTimeOriginal
function do_offset_datetime() {
  if [[ "$1" == "" ]]; then return; fi
  if [[ "$1" =~ (^([+-])?([0-9]{1,2}):([0-9]{1,2}):([0-9]{1,2})[.]{1,9}([0-9]{1,2}):([0-9]{1,2}):([0-9]{1,2})$) ]]; then
    local op="${BASH_REMATCH[2]}"
    local yy="${BASH_REMATCH[3]}"
    local mm="${BASH_REMATCH[4]}"
    local dd="${BASH_REMATCH[5]}"
    local HH="${BASH_REMATCH[6]}"
    local MM="${BASH_REMATCH[7]}"
    local SS="${BASH_REMATCH[8]}"
    if [[ "${op}" == "" ]]; then op="+"; fi
    if [[ "${yy}" != "" ]] && [[ "${yy}" -ge 0 ]] && [[ "${yy}" -lt 10 ]] && \
       [[ "${mm}" != "" ]] && [[ "${mm}" -ge 0 ]] && [[ "${mm}" -lt 12 ]] && \
       [[ "${dd}" != "" ]] && [[ "${dd}" -ge 0 ]] && [[ "${mm}" -lt 31 ]] && \
       [[ "${HH}" != "" ]] && [[ "${HH}" -ge 0 ]] && [[ "${HH}" -le 12 ]] && \
       [[ "${MM}" != "" ]] && [[ "${MM}" -ge 0 ]] && [[ "${MM}" -lt 60 ]] && \
       [[ "${SS}" != "" ]] && [[ "${SS}" -ge 0 ]] && [[ "${SS}" -lt 60 ]] ; then
      log_info "apply DateTimeOriginal shift ${op}=${yy}:${mm}:${dd} ${HH}:${MM}:${SS}"
      exiftool "-DateTimeOriginal${op}=${yy}:${mm}:${dd} ${HH}:${MM}:${SS}" ${CAMERA_FILE}*.jpg
      exiftool '-SubSecCreateDate<SubSecDateTimeOriginal' ${CAMERA_FILE}*.jpg
      exiftool '-SubSecModifyDate<SubSecDateTimeOriginal' ${CAMERA_FILE}*.jpg
      exiftool '-ModifyDate<DateTimeOriginal' ${CAMERA_FILE}*.jpg
      return
    fi
  fi
  log_error "Invalid format to shift DateTimeOriginal: $1"
}

# set TimeZoneOffset
function do_offset_timezone() {
  if [[ "$1" != "" ]] && [[ "$1" =~ (^[\+-]?([0-9]+)$) ]]; then
    local hour="${BASH_REMATCH[2]}"
    if [[ "${hour}" -ge 0 ]] && [[ "${hour}" -le 12 ]]; then
      log_info "apply TimeZoneOffset to $1 ..."
      exiftool -overwrite_original_in_place "-TimeZoneOffset=$1" ${CAMERA_FILE}*.jpg
      return
    fi
  fi
  log_error "Invalid TimeZoneOffset: $1"
}

# set FileModifyDate by DateTimeOriginal
function do_original_date() {
  log_info "apply DateTimeOriginal to FileModifyDate ..."
  exiftool -overwrite_original_in_place \
    '-FileModifyDate<DateTimeOriginal' *.jpg
}

# set XMP Rating
function do_rating() {
  local rate="${1:-0}"
  shift
  if [[ "${rate}" != "" ]] && [[ "${rate}" =~ (^[0-5]$) ]]; then
    local rateVal="${BASH_REMATCH[1]}"
    if [[ "${rateVal}" -ge 0 ]] && [[ "${rateVal}" -le 5 ]]; then
      local percent="$((${rateVal} * 100 / 6))"
      log_info "apply XMP:Rating to ${rateVal} [${percent} %] ..."
      for f in $@; do
        if [[ -e "$f" ]]; then
          exiftool -overwrite_original_in_place \
          "-Rating=${rateVal}" "-RatingPercent=${percent}" \
          '-FileModifyDate<DateTimeOriginal' "$f"
        fi
      done
      return
    fi
  fi
  log_error "Invalid Rating: ${rate} [for $@]"
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

  log_info "processing $1 ..."
  # before renaming, update with profile and modified date
  if [[ "${#date_name}" == "17" ]] && [[ "${rename_only}" != "yes" ]]; then
    check_geo_data "$1"
    change_by_profile "$1"

    log_info "updating '$1' with -FileModifyDate='${name_date}'"
    exiftool -q -FileModifyDate="${name_date}" -ModifyDate="${name_date}" "$1"
  fi

  if [[ "${rename_keep}" == "yes" ]]; then
    newimg_name="${date_form:0:13}_${1%%.*}"
  # check if renaming sequence is per date
  elif [[ "${seqnum_last}" != "" ]]; then
    log_debug "Last sequence number: ${seqnum_last}"
    seqnum_last=$((${seqnum_last}+1))
    newimg_name="${date_form:0:14}$(printf "%03d" $seqnum_last)"
    if [[ -e "${newimg_name}" ]]; then
      log_error "Cannot mv '$1' => '${newimg_name}.jpg' [already existed]"
      exit 1
    fi
  else
    # calculating 3-digit seconds field
    log_debug "Caculating sequence number: ${date_form:0:16} ?= ${prev_name}"
    if [[ "${date_form:0:16}" == "${prev_name}" ]]; then
      time_seqn=$((${time_seqn}+1))
    else
      prev_name="${date_form:0:16}"
      time_seqn=1
    fi
    log_debug "Current sequance number: ${time_seqn} on [${name_secf}]"
    for n in {0..100}; do
      # taking 2-digit seconds, multiply by 10, then add sequence number
      name_secf="$(printf "%03d" $((10#${name_secf} * 10 + ${time_seqn})) )"
      if [[ ! -e "${date_form:0:14}${name_secf}.jpg" ]]; then break; fi
      log_debug "Increasing ${time_seqn}, due to exist ${date_form:0:14}/${name_secf}.jpg"
      name_secf="${name_secf:0:2}"
      time_seqn="$((${time_seqn}+1))"
      log_debug "Increased: ${time_seqn} on [${name_secf}]"
    done
    newimg_name="${date_form:0:14}${name_secf:0:3}"
  fi

  if [[ "${rename_test}" == "yes" ]]; then
    log_info "renaming $1 => ${newimg_name}.jpg"
  else
    log_info "mv $1 => ${newimg_name}.jpg"
    mv "$1" "${newimg_name}.jpg"
  fi
}

# restore original files
function do_restore() {
  log_info "restoring original files ..."
  exiftool -restore_original *
}

# getlink() func: gets the real path of a link, following all links
function getlink() {
  if [[ ! -h "$1" ]]; then
    echo "$1"
  else
    local link="$(expr "$(command ls -ld -- "$1")" : '.*-> \(.*\)$')"
    cd $(dirname $1)
    getlink "$link" | sed "s|^\([^/].*\)\$|$(dirname $1)/\1|"
  fi
}

# getfullpath() func:
# returns the absolute path to a command, $PATH (which) or not;
# returns the same if not found.
function getfullpath() {
  echo $1 | sed "s|^\([^/].*/.*\)|$(pwd)/\1|;s|^\([^/]*\)$|$(which -- $1 2>/dev/null)|;s|^$|$1|";
}

# getpath() func: returns the realpath of a called command.
# - dependencies: func getfullpath and getlink
function getpath() {
  local SCRIPT_PATH=$(getfullpath $1)
  getlink ${SCRIPT_PATH} | sed "s|^\([^/].*\)\$|$(dirname ${SCRIPT_PATH})/\1|";
}

# log_debug() func: print message as debug warning
function log_debug() {
  if [[ "${DEBUG}" != "1" ]]; then return; fi
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
    echo -e "\n!! ${err_name}: $1" >&2
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
    if [[ "${headers}" == "0" ]] && [[ "${line}" =~ (^#[#=-\\*]{59}) ]]; then
      headers="1"
      echo "${line}"
    elif [[ "${headers}" == "1" ]] && [[ "${line}" =~ (^#[#=-\\*]{59}) ]]; then
      headers="0"
      echo "${line}"
    elif [[ "${headers}" == "1" ]]; then
      echo "${line}"
    fi
  done < "${script_path}"
  echo ""
}


# only allowing to run the script directly, prevent from source command
[[ $0 != "${BASH_SOURCE}" ]] || main "$@"
