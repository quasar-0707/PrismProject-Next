# [
_LOG() { if $DEBUG; then LOGW "$1"; else ABORT "$1"; fi }
# ]

TARGET_FIRMWARE_PATH="$(cut -d "/" -f 1 -s <<< "$TARGET_FIRMWARE")_$(cut -d "/" -f 2 -s <<< "$TARGET_FIRMWARE")"

if [ -f "$FW_DIR/$TARGET_FIRMWARE_PATH/system/system/etc/libnfc-nci.conf" ]; then
    ADD_TO_WORK_DIR "$TARGET_FIRMWARE" "system" "system/etc/libnfc-nci.conf" 0 0 644 "u:object_r:system_file:s0"
else
    DELETE_FROM_WORK_DIR "system" "system/etc/libnfc-nci.conf"
fi
if [ -f "$FW_DIR/$TARGET_FIRMWARE_PATH/system/system/etc/libnfc-nci_temp.conf" ]; then
    ADD_TO_WORK_DIR "$TARGET_FIRMWARE" "system" "system/etc/libnfc-nci_temp.conf" 0 0 644 "u:object_r:system_file:s0"
else
    DELETE_FROM_WORK_DIR "system" "system/etc/libnfc-nci_temp.conf"
fi
if [ -f "$FW_DIR/$TARGET_FIRMWARE_PATH/system/system/etc/libnfc-nci-NXP_SN100U.conf" ]; then
    ADD_TO_WORK_DIR "$TARGET_FIRMWARE" "system" "system/etc/libnfc-nci-NXP_SN100U.conf" 0 0 644 "u:object_r:system_file:s0"
fi
if [ -f "$FW_DIR/$TARGET_FIRMWARE_PATH/system/system/etc/libnfc-nci-NXP_PN553.conf" ]; then
    ADD_TO_WORK_DIR "$TARGET_FIRMWARE" "system" "system/etc/libnfc-nci-NXP_PN553.conf" 0 0 644 "u:object_r:system_file:s0"
fi
if [ -f "$FW_DIR/$TARGET_FIRMWARE_PATH/system/system/etc/libnfc-nci-SLSI.conf" ]; then
    ADD_TO_WORK_DIR "$TARGET_FIRMWARE" "system" "system/etc/libnfc-nci-SLSI.conf" 0 0 644 "u:object_r:system_file:s0"
fi
if [ -f "$FW_DIR/$TARGET_FIRMWARE_PATH/system/system/etc/libnfc-nci-STM_ST21.conf" ]; then
    ADD_TO_WORK_DIR "$TARGET_FIRMWARE" "system" "system/etc/libnfc-nci-STM_ST21.conf" 0 0 644 "u:object_r:system_file:s0"
fi

if [ "$(GET_PROP "vendor" "ro.vendor.nfc.feature.chipname")" ]; then
    if [[ "$(GET_PROP "vendor" "ro.vendor.nfc.feature.chipname")" == "NXP_PN553" ]]; then
        SET_PROP "vendor" "ro.vendor.nfc.feature.chipname" "NXP_SN100U"
    fi
    if ! [[ "$(GET_PROP "vendor" "ro.vendor.nfc.feature.chipname")" =~ NXP_SN100U|SLSI|STM_ST21 ]]; then
        _LOG "Unknown NFC chip name: $(GET_PROP "vendor" "ro.vendor.nfc.feature.chipname")"
        return 0
    fi
fi

# 삼성 제품 기능 설정: NFC 칩셋 이름 := NXP_SN100U 또는 NXP_PN553
# - API 35 이하 (Android 15 이하): libnfc_nxpsn_jni.so 또는 libnfc_nxppn_jni.so 사용
# - API 36 (Android 16): libnfc_nci_jni.so 사용
#
# 구형 NXP_PN553 칩셋이 탑재된 기기에는 NXP_SN100U 블롭을 대체하여 사용합니다.
if [ -f "$WORK_DIR/system/system/lib/libnfc_nci_jni.so" ]; then
    if [ ! -f "$FW_DIR/$TARGET_FIRMWARE_PATH/system/system/lib/libnfc_nci_jni.so" ] && \
            [ ! -f "$FW_DIR/$TARGET_FIRMWARE_PATH/system/system/lib64/libnfc_nxppn_jni.so" ] && \
            [ ! -f "$FW_DIR/$TARGET_FIRMWARE_PATH/system/system/lib64/libnfc_nxpsn_jni.so" ] && \
            [ ! -f "$WORK_DIR/vendor/lib/nfc_nci_nxpsn.so" ] && \
            [ ! -f "$WORK_DIR/vendor/lib/nfc_nci_nxp.so" ] && \
            [ ! -f "$WORK_DIR/vendor/lib64/nfc_nci_nxpsn.so" ] && \
            [ ! -f "$WORK_DIR/vendor/lib64/nfc_nci_nxp.so" ]; then
        DELETE_FROM_WORK_DIR "system" "system/lib/libnfc_nci_jni.so"
        DELETE_FROM_WORK_DIR "system" "system/lib/libnfc_prop_extn.so"
        DELETE_FROM_WORK_DIR "system" "system/lib/libnfc_vendor_extn.so"
    fi
elif [ -f "$FW_DIR/$TARGET_FIRMWARE_PATH/system/system/lib/libnfc_nci_jni.so" ]; then
    ADD_TO_WORK_DIR "$TARGET_FIRMWARE" "system" "system/lib/libnfc_nci_jni.so" 0 0 644 "u:object_r:system_lib_file:s0"
    ADD_TO_WORK_DIR "$TARGET_FIRMWARE" "system" "system/lib/libnfc_prop_extn.so" 0 0 644 "u:object_r:system_lib_file:s0"
    ADD_TO_WORK_DIR "$TARGET_FIRMWARE" "system" "system/lib/libnfc_vendor_extn.so" 0 0 644 "u:object_r:system_lib_file:s0"
elif [ -f "$FW_DIR/$TARGET_FIRMWARE_PATH/system/system/lib64/libnfc_nxpsn_jni.so" ]; then
    # TODO
    _LOG "NXP_SN100U NFC 칩셋용 prebuilt 블롭 파일이 누락되었습니다."
    return 0
fi
if [ -f "$WORK_DIR/system/system/lib64/libnfc_nci_jni.so" ]; then
    if [ ! -f "$FW_DIR/$TARGET_FIRMWARE_PATH/system/system/lib64/libnfc_nci_jni.so" ] && \
            [ ! -f "$FW_DIR/$TARGET_FIRMWARE_PATH/system/system/lib64/libnfc_nxppn_jni.so" ] && \
            [ ! -f "$FW_DIR/$TARGET_FIRMWARE_PATH/system/system/lib64/libnfc_nxpsn_jni.so" ] && \
            [ ! -f "$WORK_DIR/vendor/lib64/nfc_nci_nxpsn.so" ] && \
            [ ! -f "$WORK_DIR/vendor/lib64/nfc_nci_nxp.so" ]; then
        DELETE_FROM_WORK_DIR "system" "system/lib64/libnfc_nci_jni.so"
        DELETE_FROM_WORK_DIR "system" "system/lib64/libnfc_prop_extn.so"
        DELETE_FROM_WORK_DIR "system" "system/lib64/libnfc_vendor_extn.so"
    fi
elif [ -f "$FW_DIR/$TARGET_FIRMWARE_PATH/system/system/lib64/libnfc_nci_jni.so" ]; then
    ADD_TO_WORK_DIR "$TARGET_FIRMWARE" "system" "system/lib64/libnfc_nci_jni.so" 0 0 644 "u:object_r:system_lib_file:s0"
    ADD_TO_WORK_DIR "$TARGET_FIRMWARE" "system" "system/lib64/libnfc_prop_extn.so" 0 0 644 "u:object_r:system_lib_file:s0"
    ADD_TO_WORK_DIR "$TARGET_FIRMWARE" "system" "system/lib64/libnfc_vendor_extn.so" 0 0 644 "u:object_r:system_lib_file:s0"
elif [ -f "$FW_DIR/$TARGET_FIRMWARE_PATH/system/system/lib64/libnfc_nxpsn_jni.so" ]; then
    # 추후 구현 예정 (TODO)
    _LOG "NXP_SN100U NFC 칩셋용 prebuilt 블롭 파일이 누락되었습니다."
    return 0
fi

# 삼성 제품 기능 설정: NFC 칩셋 이름 := STM_ST21
# - API 35 이하 (Android 15 이하): libnfc_st_jni.so 사용
# - API 36 (Android 16): libstnfc_nci_jni.so 사용
if [ -f "$WORK_DIR/system/system/lib/libstnfc_nci_jni.so" ]; then
    if [ ! -f "$FW_DIR/$TARGET_FIRMWARE_PATH/system/system/lib/libstnfc_nci_jni.so" ] && \
            [ ! -f "$FW_DIR/$TARGET_FIRMWARE_PATH/system/system/lib64/libnfc_st_jni.so" ]; then
        DELETE_FROM_WORK_DIR "system" "system/lib/libnfc_vendor_extn_st.so"
        DELETE_FROM_WORK_DIR "system" "system/lib/libstnfc_nci_jni.so"
    fi
elif [ -f "$FW_DIR/$TARGET_FIRMWARE_PATH/system/system/lib/libstnfc_nci_jni.so" ]; then
    ADD_TO_WORK_DIR "$TARGET_FIRMWARE" "system" "system/lib/libnfc_vendor_extn_st.so" 0 0 644 "u:object_r:system_lib_file:s0"
    ADD_TO_WORK_DIR "$TARGET_FIRMWARE" "system" "system/lib/libstnfc_nci_jni.so" 0 0 644 "u:object_r:system_lib_file:s0"
elif [ -f "$FW_DIR/$TARGET_FIRMWARE_PATH/system/system/lib64/libnfc_st_jni.so" ]; then
    ADD_TO_WORK_DIR "a17xxx" "system" "system/lib/libnfc_vendor_extn_st.so" 0 0 644 "u:object_r:system_lib_file:s0"
    ADD_TO_WORK_DIR "a17xxx" "system" "system/lib/libstnfc_nci_jni.so" 0 0 644 "u:object_r:system_lib_file:s0"
fi
if [ -f "$WORK_DIR/system/system/lib64/libstnfc_nci_jni.so" ]; then
    if [ ! -f "$FW_DIR/$TARGET_FIRMWARE_PATH/system/system/lib64/libstnfc_nci_jni.so" ] && \
            [ ! -f "$FW_DIR/$TARGET_FIRMWARE_PATH/system/system/lib64/libnfc_st_jni.so" ]; then
        DELETE_FROM_WORK_DIR "system" "system/lib64/libnfc_vendor_extn_st.so"
        DELETE_FROM_WORK_DIR "system" "system/lib64/libstnfc_nci_jni.so"
    fi
elif [ -f "$FW_DIR/$TARGET_FIRMWARE_PATH/system/system/lib64/libstnfc_nci_jni.so" ]; then
    ADD_TO_WORK_DIR "$TARGET_FIRMWARE" "system" "system/lib64/libnfc_vendor_extn_st.so" 0 0 644 "u:object_r:system_lib_file:s0"
    ADD_TO_WORK_DIR "$TARGET_FIRMWARE" "system" "system/lib64/libstnfc_nci_jni.so" 0 0 644 "u:object_r:system_lib_file:s0"
elif [ -f "$FW_DIR/$TARGET_FIRMWARE_PATH/system/system/lib64/libnfc_st_jni.so" ]; then
    ADD_TO_WORK_DIR "a17xxx" "system" "system/lib64/libnfc_vendor_extn_st.so" 0 0 644 "u:object_r:system_lib_file:s0"
    ADD_TO_WORK_DIR "a17xxx" "system" "system/lib64/libstnfc_nci_jni.so" 0 0 644 "u:object_r:system_lib_file:s0"
fi

# 삼성 제품 기능 설정: NFC 칩셋 이름 := SLSI
# - 이전과 라이브러리 파일명은 동일하므로, TARGET_PLATFORM_SDK_VERSION 값을 대신 확인하여 분기합니다.
if [ -f "$WORK_DIR/system/system/lib/libnfc_sec_jni.so" ]; then
    if [ ! -f "$FW_DIR/$TARGET_FIRMWARE_PATH/system/system/lib/libnfc_sec_jni.so" ] && \
            [ ! -f "$FW_DIR/$TARGET_FIRMWARE_PATH/system/system/lib64/libnfc_sec_jni.so" ] && \
            [ ! -f "$WORK_DIR/vendor/lib/nfc_nci_sec.so" ] && \
            [ ! -f "$WORK_DIR/vendor/lib64/nfc_nci_sec.so" ]; then
        DELETE_FROM_WORK_DIR "system" "system/lib/libnfc_sec_jni.so"
    fi
elif [ -f "$FW_DIR/$TARGET_FIRMWARE_PATH/system/system/lib/libnfc_sec_jni.so" ] || \
        [ -f "$FW_DIR/$TARGET_FIRMWARE_PATH/system/system/lib64/libnfc_sec_jni.so" ]; then
    if [ "$TARGET_PLATFORM_SDK_VERSION" -ge "36" ]; then
        ADD_TO_WORK_DIR "$TARGET_FIRMWARE" "system" "system/lib/libnfc_sec_jni.so" 0 0 644 "u:object_r:system_lib_file:s0"
    else
        ADD_TO_WORK_DIR "r11sxxx" "system" "system/lib/libnfc_sec_jni.so" 0 0 644 "u:object_r:system_lib_file:s0"
    fi
fi
if [ -f "$WORK_DIR/system/system/lib64/libnfc_sec_jni.so" ]; then
    if [ ! -f "$FW_DIR/$TARGET_FIRMWARE_PATH/system/system/lib64/libnfc_sec_jni.so" ] && \
            [ ! -f "$WORK_DIR/vendor/lib64/nfc_nci_sec.so" ]; then
        DELETE_FROM_WORK_DIR "system" "system/lib64/libnfc_sec_jni.so"
    fi
elif [ -f "$FW_DIR/$TARGET_FIRMWARE_PATH/system/system/lib64/libnfc_sec_jni.so" ]; then
    if [ "$TARGET_PLATFORM_SDK_VERSION" -ge "36" ]; then
        ADD_TO_WORK_DIR "$TARGET_FIRMWARE" "system" "system/lib64/libnfc_sec_jni.so" 0 0 644 "u:object_r:system_lib_file:s0"
    else
        ADD_TO_WORK_DIR "r11sxxx" "system" "system/lib64/libnfc_sec_jni.so" 0 0 644 "u:object_r:system_lib_file:s0"
    fi
fi

unset TARGET_FIRMWARE_PATH
unset -f _LOG
