# Copyright (c) 2025 Salvo Giangreco
# SPDX-License-Identifier: GPL-3.0-or-later

# [
source "$SRC_DIR/scripts/utils/common_utils.sh"
# ]

# SMALI_PATCH <partition> <apk/jar> <smali> <operation> [method] [value] [replacement]
# 제공된 인수를 사용하여 smali 파일을 동적으로 패치합니다.
#
# 사용법:
# - null <method>: 제공된 smali 파일에서 지정된 메서드의 내용을 삭제합니다.
# - remove: 제공된 smali 파일을 완전히 삭제합니다.
# - replace <method> <value> <replacement>: 제공된 메서드에서 지정된 문자열의 발생을 교체합니다.
# - replaceall <value> <replacement>: 전체 smali 파일에서 지정된 문자열의 모든 발생을 교체합니다.
# - return <method> <value>: 원하는 값을 반환하도록 제공된 메서드를 패치합니다.
# - strip <method>: 제공된 smali 파일에서 지정된 메서드를 삭제합니다.
SMALI_PATCH()
{
    _CHECK_NON_EMPTY_PARAM "PARTITION" "$1" || return 1
    _CHECK_NON_EMPTY_PARAM "FILE" "$2" || return 1
    _CHECK_NON_EMPTY_PARAM "SMALI" "$3" || return 1
    _CHECK_NON_EMPTY_PARAM "OPERATION" "$4" || return 1

    local PARTITION="$1"
    local FILE="$2"
    local SMALI="$3"
    local OPERATION="$4"

    if ! IS_VALID_PARTITION_NAME "$PARTITION"; then
        LOGE "\"$PARTITION\"은(는) 유효한 파티션 이름이 아닙니다."
        return 1
    fi

    while [[ "${FILE:0:1}" == "/" ]]; do
        FILE="${FILE:1}"
    done

    DECODE_APK "$PARTITION" "$FILE" || return 1

    if [[ "$OPERATION" != "null" ]] && [[ "$OPERATION" != "remove" ]] && \
        [[ "$OPERATION" != "replace" ]] && [[ "$OPERATION" != "replaceall" ]] && \
            [[ "$OPERATION" != "return" ]] && [[ "$OPERATION" != "strip" ]]; then
        LOGE "유효하지 않은 작업입니다: \"$OPERATION\""
        return 1
    fi

    if [[ "$OPERATION" == "replaceall" ]]; then
        _CHECK_NON_EMPTY_PARAM "VALUE" "$5" || return 1
        local VALUE="$5"
        local REPLACEMENT="$6"
    elif [[ "$OPERATION" != "remove" ]]; then
        _CHECK_NON_EMPTY_PARAM "METHOD" "$5" || return 1
        local METHOD="$5"

        if ! [[ "$METHOD" =~ ^[A-Za-z0-9\$\<\-].*\(.*\).* ]]; then
            LOGE "유효하지 않은 메서드 이름입니다: \"$METHOD\""
            return 1
        fi
    fi

    if [[ "$OPERATION" == "return" ]]; then
        _CHECK_NON_EMPTY_PARAM "VALUE" "$6" || return 1
        local VALUE="$6"
    fi

    if [[ "$OPERATION" == "replace" ]]; then
        _CHECK_NON_EMPTY_PARAM "VALUE" "$6" || return 1
        local VALUE="$6"
        local REPLACEMENT="$7"
    fi

    local FILE_PATH="$APKTOOL_DIR/$PARTITION/${FILE//system\//}"

    # 제공된 smali 파일이 존재하는지 확인합니다.
    if [ ! -f "$FILE_PATH/$SMALI" ]; then
        LOGE "Smali 파일이 존재하지 않습니다: \"/$PARTITION/$FILE/$SMALI\""

        local MATCHES
        MATCHES="$(find "$FILE_PATH" -type f -name "*${SMALI##*/}")"

        if [ "$MATCHES" ]; then
            echo -e "\n\033[0;31m일치할 가능성이 있는 파일:" >&2
            echo -e -n "$(head -n 10 <<< "${MATCHES//$FILE_PATH\//    }")" >&2
            [ "$(wc -l <<< "$MATCHES")" -gt 10 ] && \
                echo -e -n "\n    ...외 $(($(wc -l <<< "$MATCHES") - 10))개의 일치 항목"  >&2
            echo -e "\033[0m" >&2
        fi

        return 1
    elif [[ "$OPERATION" == "remove" ]]; then
        local USED
        USED="$(find "$FILE_PATH" ! -path "*$SMALI" -type f -exec grep -r -n -- "$(cut -d "." -f "1" <<< "${SMALI#*/}");" {} \+ || true)"
        USED="$(cut -d ":" -f 1-2 <<< "$USED")"

        if [ "$USED" ]; then
            LOGE "/$PARTITION/$FILE 에서 \"$SMALI\"을(를) 삭제할 수 없습니다. 다른 곳에서 사용 중입니다."
            echo -e "\n\033[0;31m일치 항목:" >&2
            echo -e -n "$(head -n 10 <<< "${USED//$FILE_PATH\//    - }")" >&2
            [ "$(wc -l <<< "$USED")" -gt 10 ] && \
                echo -e -n "\n    ...외 $(($(wc -l <<< "$USED") - 10))개의 일치 항목" >&2
            echo -e "\033[0m" >&2
            return 1
        fi

        LOG "- /$PARTITION/$FILE 에서 \"$SMALI\"을(를) 삭제합니다."
        EVAL "LC_ALL=C rm \"$FILE_PATH/${SMALI//$/\\$}\"" || return 1
        return 0
    fi

    # 제공된 메서드가 메서드인지 확인하고 smali 내부에 존재하는지 확인합니다.
    if ! grep "^\.method.*" "$FILE_PATH/$SMALI" | grep -q -F -- "$METHOD" "$FILE_PATH/$SMALI"; then
        LOGE "/$PARTITION/$FILE/$SMALI 에서 \"$METHOD\" 메서드를 찾을 수 없습니다."

        local MATCHES
        MATCHES="$(grep -r "^\.method.*$METHOD" "$FILE_PATH")"

        if [ "$MATCHES" ]; then
            echo -e "\n\033[0;31m일치할 가능성이 있는 메서드:" >&2
            echo -e "$(head -n 10 <<< "${MATCHES//$FILE_PATH\//    - }")" >&2
            [ "$(wc -l <<< "$MATCHES")" -gt 10 ] && \
                echo -n "    ...외 $(($(wc -l <<< "$MATCHES") - 10))개의 일치 항목" >&2
            echo -e "\033[0m" >&2
        fi

        return 1
    fi

    local BEFORE
    local AFTER

    BEFORE="$(sha1sum "$FILE_PATH/$SMALI")"

    # 메서드를 완전히 삭제합니다.
    if [[ "$OPERATION" == "strip" ]]; then
        local USED
        USED="$(grep -r -n -- "invoke.*$(basename "$SMALI" | cut -d "." -f "1");" "$FILE_PATH")"
        USED="$(grep -F "$METHOD" <<< "$USED" | cut -d ":" -f 1-2)"

        if [ "$USED" ]; then
            LOGE "/$PARTITION/$FILE/$SMALI 에서 \"$METHOD\" 메서드를 삭제할 수 없습니다. 다른 곳에서 사용 중입니다."
            echo -e "\n\033[0;31m일치 항목:" >&2
            echo -e -n "$(head -n 10 <<< "${USED//$FILE_PATH\//    - }")" >&2
            [ "$(wc -l <<< "$USED")" -gt 10 ] && \
                echo -e -n "\n    ...외 $(($(wc -l <<< "$USED") - 10))개의 일치 항목" >&2
            echo -e "\033[0m" >&2
            return 1
        fi

        LOG "- /$PARTITION/$FILE/$SMALI 에서 \"$METHOD\" 메서드를 삭제합니다."

        awk -v FN="$METHOD" '
            BEGIN { inside = 0; skip = 0 }
            /^\.method/ && index($0, FN) {
                inside = 1
                next
            }
            inside && /^\.end method/ {
                inside = 0
                skip = 1
                next
            }
            inside { next }
            {
                if (skip) {
                    skip = 0
                    next
                }
                print
            }
        ' "$FILE_PATH/$SMALI" > "$FILE_PATH/$SMALI.tmp" && \
            mv "$FILE_PATH/$SMALI.tmp" "$FILE_PATH/$SMALI"

        AFTER="$(sha1sum "$FILE_PATH/$SMALI")"
        if [[ "$BEFORE" == "$AFTER" ]]; then
            LOGE "/$PARTITION/$FILE/$SMALI 에서 \"$METHOD\" 메서드 삭제에 실패했습니다."
            return 1
        fi
    # 메서드의 내용은 삭제하고, 선언은 남깁니다.
    elif [[ "$OPERATION" == "null" ]]; then
        local RET
        local LOC=".locals 0"

        RET="${METHOD#*)}"
        if [[ "$RET" != "V" ]]; then
            LOGE "/$PARTITION/$FILE/$SMALI 의 non-void 메서드 \"$METHOD\"을(를) 무효화할 수 없습니다."
            return 1
        else
            RET="return-void"
        fi

        LOG "- /$PARTITION/$FILE/$SMALI 에서 \"$METHOD\" 메서드를 무효화합니다."

        awk -v FN="$METHOD" -v LOC="$LOC" -v RET="$RET" '
            BEGIN { inside = 0 }
            /^\.method/ && index($0, FN) {
                print
                print "    " LOC
                print "    "
                print "    " RET
                inside = 1
                next
            }
            inside && /^\.end method/ {
                print
                inside = 0
                next
            }
            inside { next }
            { print }
        ' "$FILE_PATH/$SMALI" > "$FILE_PATH/$SMALI.tmp" && \
            mv "$FILE_PATH/$SMALI.tmp" "$FILE_PATH/$SMALI"

        AFTER="$(sha1sum "$FILE_PATH/$SMALI")"
        if [[ "$BEFORE" == "$AFTER" ]]; then
            LOGE "/$PARTITION/$FILE/$SMALI 에서 \"$METHOD\" 메서드를 무효화하는 데 실패했습니다."
            return 1
        fi
    # 메서드 내용을 단일 return으로 교체합니다.
    elif [[ "$OPERATION" == "return" ]]; then
        local RET
        local REG
        local LOC

        # 레지스터 결정
        REG="p0"
        LOC=".locals 0"
        if [[ "$(grep "^\.method.*" "$FILE_PATH/$SMALI" | \
                    grep -F -- "$METHOD" "$FILE_PATH/$SMALI")" == *" static "* ]] && \
                [[ "$METHOD" == *"()"* ]]; then
            REG="v0"
            LOC=".locals 1"
        fi

        # 반환(return) 타입 결정
        RET="${METHOD#*)}"
        if [[ "$RET" == "V" ]]; then
            LOGE "/$PARTITION/$FILE/$SMALI 의 void 메서드 \"$METHOD\" 반환 값을 변경할 수 없습니다."
            return 1
        elif [[ "$RET" == "Ljava/lang/String;" ]]; then
            VALUE="\"$VALUE\""
            RET="return-object $REG"
        elif [[ "$RET" =~ ^\[*[ZBCSIJFD]$ ]]; then
            # 부울(Boolean) 타입
            if [[ "$RET" == "Z" ]]; then
                if [[ "$VALUE" == "true" ]]; then
                    VALUE="0x1"
                elif [[ "$VALUE" == "false" ]]; then
                    VALUE="0x0"
                fi

                if [[ "$VALUE" != "0x0" ]] && [[ "$VALUE" != "0x1" ]]; then
                    LOGE "/$PARTITION/$FILE/$SMALI 의 \"$METHOD\" 메서드에 상수 값을 사용할 수 없습니다."
                    return 1
                fi
            fi

            # 10진수 값을 16진수로 변환
            if [[ "$VALUE" =~ ^-?[0-9]+$ ]]; then
                VALUE="0x$(printf "%x" "$VALUE")"
            fi

            if [[ "$VALUE" =~ ^\".*\"$ ]]; then
                LOGE "/$PARTITION/$FILE/$SMALI 의 \"$METHOD\" 메서드에 문자열 값을 사용할 수 없습니다."
                return 1
            fi

            # Long 타입
            if [[ "$RET" == "J" ]]; then
                RET="return-wide $REG"
            else
                RET="return $REG"
            fi
        else
            if [[ "$VALUE" == "null" ]]; then
                VALUE="0x0"
            fi

            if [[ "$VALUE" != "0x0" ]]; then
                LOGE "/$PARTITION/$FILE/$SMALI 의 \"$METHOD\" 메서드에 상수 값을 사용할 수 없습니다."
                return 1
            fi

            RET="return-object $REG"
        fi

        # 반환할 내용 결정
        local hex
        local num
        if [[ "$VALUE" =~ ^-?0x[0-9a-fA-F]+$ ]]; then
            # 16진수 값
            if [[ "$VALUE" == "-"* ]]; then
                hex="${VALUE#-0x}"
                num="$((-16#$hex))"
            else
                hex="${VALUE#0x}"
                num="$((16#$hex))"
            fi
            if [[ "$RET" == "return-wide"* ]]; then
                VALUE="const-wide/16 $REG, $VALUE"
            elif [ "$num" -gt "-8" ] && [ "$num" -lt "8" ]; then
                VALUE="const/4 $REG, $VALUE"
            else
                VALUE="const/16 $REG, $VALUE"
            fi
        elif [[ "$VALUE" =~ ^\".*\"$ ]]; then
            # 문자열 값
            VALUE="const-string $REG, $VALUE"
        else
            LOGE "/$PARTITION/$FILE/$SMALI 의 \"$METHOD\" 메서드에 대한 반환 값이 유효하지 않습니다: \"$VALUE\""
            return 1
        fi

        LOG "- /$PARTITION/$FILE/$SMALI 에서 \"$METHOD\" 메서드의 반환 값을 \"$VALUE\"(으)로 교체합니다."

        awk -v FN="$METHOD" -v LOC="$LOC" -v VAL="$VALUE" -v RET="$RET" '
            BEGIN { inside = 0 }
            /^\.method/ && index($0, FN) {
                print
                print "    " LOC
                print ""
                print "    " VAL
                print ""
                print "    " RET
                inside = 1
                next
            }
            inside && /^\.end method/ {
                print
                inside = 0
                next
            }
            inside { next }
            { print }
        ' "$FILE_PATH/$SMALI" > "$FILE_PATH/$SMALI.tmp" && \
            mv "$FILE_PATH/$SMALI.tmp" "$FILE_PATH/$SMALI"

        AFTER="$(sha1sum "$FILE_PATH/$SMALI")"
        if [[ "$BEFORE" == "$AFTER" ]]; then
            LOGE "/$PARTITION/$FILE/$SMALI 에서 \"$METHOD\" 메서드의 반환 값을 \"$VALUE\"(으)로 교체하는 데 실패했습니다."
            return 1
        fi
    # 메서드 내의 문자열을 다른 문자열로 교체
    # 또는 메서드 내의 한 줄을 다른 줄로 교체
    elif [[ "$OPERATION" == "replace" ]]; then
        LOG "- /$PARTITION/$FILE/$SMALI 에서 \"$METHOD\" 메서드의 \"$VALUE\" 값을 \"$REPLACEMENT\"(으)로 교체합니다."

        awk -v FN="$METHOD" -v STR="$VALUE" -v REP="$REPLACEMENT" '
            BEGIN { inside = 0; isline = (index(REP, "\n") > 0) }
            /^\.method/ && index($0, FN) { inside = 1 }
            inside {
                if (isline) {
                    if (index($0, STR)) {
                        gsub(/\\n/, "\n", REP)
                        print REP
                        next
                    }
                } else if ($0 ~ /^[[:space:]]*const-string(\/jumbo)?/) {
                    sub("\"" STR "\"", "\"" REP "\"")
                } else {
                    line = $0
                    gsub(/^[ \t]+|[ \t]+$/, "", line)

                    if (line == STR) {
                        match($0, /^[ \t]+/)
                        indent = substr($0, RSTART, RLENGTH)
                        $0 = indent REP
                    }
                }
            }
            inside && /^\.end method/ { inside = 0 }
            { print }
        ' "$FILE_PATH/$SMALI" > "$FILE_PATH/$SMALI.tmp" && \
            mv "$FILE_PATH/$SMALI.tmp" "$FILE_PATH/$SMALI"

        AFTER="$(sha1sum "$FILE_PATH/$SMALI")"
        if [[ "$BEFORE" == "$AFTER" ]]; then
            LOGE "/$PARTITION/$FILE/$SMALI 에서 \"$METHOD\" 메서드의 \"$VALUE\" 값을 \"$REPLACEMENT\"(으)로 교체하는 데 실패했습니다."
            return 1
        fi
    # 발생한 모든 값을 다른 값으로 교체
    #TODO: 개선 및 오류 검사 추가 요망, 현재는 불안정함
    elif [[ "$OPERATION" == "replaceall" ]]; then
        LOG "- /$PARTITION/$FILE/$SMALI 에서 \"$VALUE\"의 모든 발생을 \"$REPLACEMENT\"(으)로 교체합니다."

        EVAL "sed -i \"s|$VALUE|$REPLACEMENT|g\" \"$FILE_PATH/${SMALI//$/\\$}\"" || return 1

        AFTER="$(sha1sum "$FILE_PATH/$SMALI")"
        if [[ "$BEFORE" == "$AFTER" ]]; then
            LOGE "/$PARTITION/$FILE/$SMALI 에서 \"$VALUE\"의 모든 발생을 \"$REPLACEMENT\"(으)로 교체하는 데 실패했습니다."
            return 1
        fi
    fi

    return 0
}
