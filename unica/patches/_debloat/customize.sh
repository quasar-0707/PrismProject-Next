# Dexpreopt
DELETE_OAT() {
    local PARTITION="$1"

    [ ! -d "$WORK_DIR/$PARTITION" ] && return

    find "$WORK_DIR/$PARTITION" -type d -name "oat" -print0 |
        xargs -0 -r -P "$(nproc)" -I "{}" \
        bash -c '
            source "$SRC_DIR/scripts/utils/module_utils.sh"
            DELETE_FROM_WORK_DIR "'"$PARTITION"'" "${1#'"$WORK_DIR"'/'"$PARTITION"'/}"
        ' bash "{}"
}

DELETE_VDEX() {
    find "$WORK_DIR/system/system/framework" -type f -name "*.vdex" -print0 |
        xargs -0 -r -P "$(nproc)" -I "{}" \
        bash -c '
            source "$SRC_DIR/scripts/utils/module_utils.sh"
            DELETE_FROM_WORK_DIR "system" "${1#'"$WORK_DIR"'/system/}"
        ' bash "{}"
}

DELETE_OAT "product"
DELETE_OAT "system"

$TARGET_OS_BUILD_SYSTEM_EXT_PARTITION && DELETE_OAT "system_ext"

DELETE_FROM_WORK_DIR "system" "system/etc/boot-image.bprof"
DELETE_FROM_WORK_DIR "system" "system/etc/boot-image.prof"
DELETE_FROM_WORK_DIR "system" "system/framework/arm"
DELETE_FROM_WORK_DIR "system" "system/framework/arm64"

DELETE_VDEX

# ROM & 디바이스 전용 블로트웨어
for SCRIPT in \
    "$SRC_DIR/unica/debloat.sh" \
    "$SRC_DIR/platform/$TARGET_PLATFORM/debloat.sh" \
    "$SRC_DIR/target/$TARGET_CODENAME/debloat.sh"
do
    [ -f "$SCRIPT" ] && source "$SCRIPT"
done

RUN_DEBLOAT() {
    local PARTITION="$1"
    local LIST="$2"

    LIST="$(sed '/^$/d' <<< "$LIST" | sort)"

    [ -z "$LIST" ] && return

    xargs -r -I "{}" -P "$(nproc)" \
        bash -c '
            source "$SRC_DIR/scripts/utils/module_utils.sh"
            DELETE_FROM_WORK_DIR "'"$PARTITION"'" "$1"
        ' bash "{}" <<< "$LIST" 2>&1 |
        sed "/파일이 존재하지 않습니다/d"
}

RUN_DEBLOAT "odm"        "$ODM_DEBLOAT"
RUN_DEBLOAT "product"    "$PRODUCT_DEBLOAT"
RUN_DEBLOAT "system"     "$SYSTEM_DEBLOAT"
RUN_DEBLOAT "system_ext" "$SYSTEM_EXT_DEBLOAT"
RUN_DEBLOAT "vendor"     "$VENDOR_DEBLOAT"

unset ODM_DEBLOAT PRODUCT_DEBLOAT SYSTEM_DEBLOAT SYSTEM_EXT_DEBLOAT VENDOR_DEBLOAT