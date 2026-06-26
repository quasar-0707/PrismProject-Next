# [
BACKPORT_SF_PROPS()
{
    local FILE="$WORK_DIR/vendor/build.prop"
    if [ -f "$WORK_DIR/vendor/default.prop" ]; then
        FILE="$WORK_DIR/vendor/default.prop"
    fi

    if [ ! -f "$FILE" ]; then
        ABORT "파일이 존재하지 않습니다: ${FILE//$SRC_DIR\//}"
    fi

    local PROP
    local VALUE

    if [ "$TARGET_PLATFORM_SDK_VERSION" -lt "34" ]; then
        PATCHED=true

        PROP="ro.surface_flinger.enable_frame_rate_override"
        VALUE="$(test "$TARGET_LCD_CONFIG_HFR_MODE" -gt "1" && echo "true" || echo "false")"

        if [ ! "$(GET_PROP "vendor" "$PROP")" ]; then
            LOG "- \"$PROP\" 프롭을 \"$VALUE\"로 ${FILE//$WORK_DIR/}에 추가하는 중..."
            EVAL "sed -i \"/persist.sys.usb.config/i $PROP=$VALUE\" \"$FILE\""
        fi
    fi

    if [ "$TARGET_PLATFORM_SDK_VERSION" -lt "35" ]; then
        PATCHED=true

        PROP="ro.surface_flinger.set_display_power_timer_ms"

        if [ "$(GET_PROP "vendor" "$PROP")" ]; then
            SET_PROP "vendor" "$PROP" --delete
        fi

        PROP="ro.surface_flinger.enable_frame_rate_override"
        if [ "$(GET_PROP "vendor" "ro.surface_flinger.set_idle_timer_ms")" ]; then
            PROP="ro.surface_flinger.set_idle_timer_ms"
        fi
        VALUE="$(GET_PROP "vendor" "ro.surface_flinger.use_content_detection_for_refresh_rate")"
        if [ ! "$VALUE" ]; then
            VALUE="$(test "$TARGET_LCD_CONFIG_HFR_MODE" -gt "1" && echo "true" || echo "false")"
        fi

        if [[ "$(sed -n "/$PROP/{x;p;d;}; x" "$FILE")" != *"use_content_detection_for_refresh_rate"* ]]; then
            if [ ! "$(GET_PROP "vendor" "ro.surface_flinger.use_content_detection_for_refresh_rate")" ]; then
                LOG "- \"ro.surface_flinger.use_content_detection_for_refresh_rate\" 프롭을 \"$VALUE\"로 ${FILE//$WORK_DIR/}에 추가하는 중..."
            else
                EVAL "sed -i \"/use_content_detection_for_refresh_rate/d\" \"$FILE\""
            fi
            EVAL "sed -i \"/$PROP/i ro.surface_flinger.use_content_detection_for_refresh_rate=$VALUE\" \"$FILE\""
        fi

        PROP="debug.sf.show_refresh_rate_overlay_render_rate"
        VALUE="true"
        if [ ! "$(GET_PROP "vendor" "$PROP")" ]; then
            LOG "- \"$PROP\" 프롭을 \"$VALUE\"로 ${FILE//$WORK_DIR/}에 추가하는 중..."
            EVAL "sed -i \"/ro.surface_flinger.use_content_detection_for_refresh_rate/i $PROP=$VALUE\" \"$FILE\""
        fi

        PROP="ro.surface_flinger.game_default_frame_rate_override"
        VALUE="60"
        if [ ! "$(GET_PROP "vendor" "$PROP")" ]; then
            LOG "- \"$PROP\" 프롭을 \"$VALUE\"로 ${FILE//$WORK_DIR/}에 추가하는 중..."
            EVAL "sed -i \"/debug.sf.show_refresh_rate_overlay_render_rate/a $PROP=$VALUE\" \"$FILE\""
        fi
    fi
}

EXTRACT_KERNEL_IMAGE() {
    if [ -d "$TMP_DIR" ]; then
        EVAL "rm -rf \"$TMP_DIR\""
    fi
    EVAL "mkdir -p \"$TMP_DIR\""
    EVAL "cp -a \"$WORK_DIR/kernel/boot.img\" \"$TMP_DIR/boot.img\""

    EVAL "unpack_bootimg --boot_img \"$TMP_DIR/boot.img\" --out \"$TMP_DIR/out\" 2>&1"

    EVAL "rm \"$TMP_DIR/boot.img\""

    if [[ "$(READ_BYTES_AT "$TMP_DIR/out/kernel" "0" "2")" == "8b1f" ]]; then
        EVAL "cat \"$TMP_DIR/out/kernel\" | gzip -d > \"$TMP_DIR/out/tmp\" && mv -f \"$TMP_DIR/out/tmp\" \"$TMP_DIR/out/kernel\""
    fi
}

EXTRACT_KERNEL_MODULES() {
    if [ -d "$TMP_DIR" ]; then
        EVAL "rm -rf \"$TMP_DIR\""
    fi
    EVAL "mkdir -p \"$TMP_DIR\""
    EVAL "cp -a \"$WORK_DIR/kernel/vendor_boot.img\" \"$TMP_DIR/vendor_boot.img\""

    EVAL "unpack_bootimg --boot_img \"$TMP_DIR/vendor_boot.img\" --out \"$TMP_DIR/out\" 2>&1"

    EVAL "rm \"$TMP_DIR/vendor_boot.img\""

    while IFS= read -r f; do
        if [[ "$(READ_BYTES_AT "$f" "0" "4")" == "184c2102" ]]; then
            EVAL "cat \"$f\" | lz4 -d > \"$TMP_DIR/out/tmp\" && mv -f \"$TMP_DIR/out/tmp\" \"$f\""
        elif [[ "$(READ_BYTES_AT "$f" "0" "2")" == "8b1f" ]]; then
            EVAL "cat \"$f\" | gzip -d > \"$TMP_DIR/out/tmp\" && mv -f \"$TMP_DIR/out/tmp\" \"$f\""
        fi
    done < <(find "$TMP_DIR/out" -maxdepth 1 -type f -name "vendor_ramdisk*")
}
# ]

PATCHED=false

# API 34 미만 (Android 14 미만)
# - 프레임 레이트 오버라이드 활성화 속성이 누락된 경우 추가
#
# API 35 미만 (Android 15 미만)
# - 콘텐츠 감지 기반 주사율 제어 속성을 올바른 위치에 배치
# - 주사율 오버레이 렌더링 레이트 표시 속성이 누락된 경우 추가
# - 게임 기본 프레임 레이트 오버라이드 속성이 누락된 경우 추가
BACKPORT_SF_PROPS

# 구형 Face HAL 지원 (API 34 미만 기기용)
if [ "$TARGET_PLATFORM_SDK_VERSION" -lt "34" ]; then
    if [ ! -f "$WORK_DIR/vendor/bin/hw/vendor.samsung.hardware.biometrics.face@3.0-service" ]; then
        PATCHED=true
        APPLY_PATCH "system" "system/framework/services.jar" \
            "$MODPATH/face/services.jar/0001-Fallback-to-Face-HIDL-2.0.patch"
        SMALI_PATCH "system" "system/framework/services.jar" \
            "smali/com/android/server/biometrics/sensors/face/hidl/HidlToAidlCallbackConverter.smali" "replaceall" \
            "V3_0" \
            "V2_0" \
            > /dev/null
        SMALI_PATCH "system" "system/framework/services.jar" \
            "smali/com/android/server/biometrics/sensors/face/hidl/TestHal.smali" "replaceall" \
            "V3_0" \
            "V2_0" \
            > /dev/null
        SMALI_PATCH "system" "system/framework/services.jar" \
            "smali/com/android/server/biometrics/sensors/face/aidl/SemFaceServiceExImpl\$\$ExternalSyntheticLambda6.smali" "remove"
        LOG "- /system/system/framework/services.jar에서 \"smali_classes2/vendor/samsung/hardware/biometrics/face/V3_0/ISehBiometricsFace.smali\" 제거 중"
        EVAL "rm \"$APKTOOL_DIR/system/framework/services.jar/smali_classes2/vendor/samsung/hardware/biometrics/face/V3_0/ISehBiometricsFace.smali\""
        LOG "- /system/system/framework/services.jar에서 \"smali_classes2/vendor/samsung/hardware/biometrics/face/V3_0/ISehBiometricsFace\$Proxy.smali\" 제거 중"
        EVAL "rm \"$APKTOOL_DIR/system/framework/services.jar/smali_classes2/vendor/samsung/hardware/biometrics/face/V3_0/ISehBiometricsFace\\\$Proxy.smali\""
        SMALI_PATCH "system" "system/framework/services.jar" \
            "smali_classes2/vendor/samsung/hardware/biometrics/face/V3_0/ISehBiometricsFace\$Stub\$1.smali" "remove"
        SMALI_PATCH "system" "system/framework/services.jar" \
            "smali_classes2/vendor/samsung/hardware/biometrics/face/V3_0/ISehBiometricsFaceClientCallback\$Proxy.smali" "remove"
        SMALI_PATCH "system" "system/framework/services.jar" \
            "smali_classes2/vendor/samsung/hardware/biometrics/face/V3_0/ISehBiometricsFaceClientCallback.smali" "remove"
    fi
fi

# 구형 SehLights HAL 지원 (API 35 미만 기기용)
# - [lsr wD, wS, #0x18] 명령어를 체크하여 최신 HAL이 이미 적용되어 있는지 확인
if [ "$TARGET_PLATFORM_SDK_VERSION" -lt "35" ]; then
    if [ -f "$WORK_DIR/vendor/bin/hw/vendor.samsung.hardware.light-service" ] && \
            ! xxd -p -c 4 "$WORK_DIR/vendor/bin/hw/vendor.samsung.hardware.light-service" | grep -q "1853$"; then
        PATCHED=true
        APPLY_PATCH "system" "system/framework/services.jar" \
            "$MODPATH/lights/services.jar/0001-Backport-legacy-SehLights-HAL-code.patch"
    fi
fi

# config_num_physical_slots 설정 확보 (API 36 미만 기기용)
# 릴레이션 소스 참조: https://android.googlesource.com/platform/frameworks/opt/telephony/+/42e37234cee15c9f3fcfac0532110abfc8843b99%5E%21/#F0
if [ "$TARGET_PLATFORM_SDK_VERSION" -lt "36" ]; then
    if [ ! "$(GET_PROP "ro.telephony.sim_slots.count")" ] && \
            ! grep -q "ro.telephony.sim_slots.count" "$WORK_DIR/vendor/bin/secril_config_svc" && \
            ! grep -q -r "config_num_physical_slots" "$WORK_DIR/vendor/overlay"; then
        PATCHED=true
        APPLY_PATCH "system" "system/framework/telephony-common.jar" \
            "$MODPATH/ril/telephony-common.jar/0001-Backport-legacy-UiccController-code.patch"
    fi
fi

# 구형 sdFAT 커널 드라이버 지원 (API 35 미만 기기용)
# 소스 참조: https://android.googlesource.com/platform/system/vold/+/refs/tags/android-16.0.0_r2/fs/Vfat.cpp#150
# - 커널 이미지에서 'bogus directory:' 문자열이 있는지 검사하여 최신 sdFAT 드라이버인지 판별
if [ "$TARGET_PLATFORM_SDK_VERSION" -lt "35" ]; then
    EXTRACT_KERNEL_IMAGE
    if grep -q "SDFAT" "$TMP_DIR/out/kernel" && \
            ! grep -q "bogus directory:" "$TMP_DIR/out/kernel"; then
        PATCHED=true
        # ",time_offset=%d" 옵션을 널(NUL) 문자로 대체하여 바이너리 헥사 패치
        HEX_PATCH "$WORK_DIR/system/system/bin/vold" "2c74696d655f6f66667365743d2564" "000000000000000000000000000000"
    fi
fi

# IMAGE_CODEC_SAMSUNG 지원 보장 (API 35 미만 기기용)
if [ "$TARGET_PLATFORM_SDK_VERSION" -lt "35" ]; then
    if [ "$(GET_FLOATING_FEATURE_CONFIG "SEC_FLOATING_FEATURE_CAMERA_CONFIG_VENDOR_LIB_INFO")" ] && \
            [[ "$(GET_FLOATING_FEATURE_CONFIG "SEC_FLOATING_FEATURE_CAMERA_CONFIG_VENDOR_LIB_INFO")" != *"image_codec.samsung"* ]]; then
        PATCHED=true
        SET_FLOATING_FEATURE_CONFIG "SEC_FLOATING_FEATURE_CAMERA_CONFIG_VENDOR_LIB_INFO" \
            "$(GET_FLOATING_FEATURE_CONFIG "SEC_FLOATING_FEATURE_CAMERA_CONFIG_VENDOR_LIB_INFO"),image_codec.samsung.v1"
    fi
fi

# Knox Matrix 지원 보장
# - 타겟 펌웨어가 One UI 5.1.1 이상 버전에서 실행 중인지 체크
TARGET_FIRMWARE_PATH="$(cut -d "/" -f 1 -s <<< "$TARGET_FIRMWARE")_$(cut -d "/" -f 2 -s <<< "$TARGET_FIRMWARE")"
if [ "$(GET_PROP "$FW_DIR/$TARGET_FIRMWARE_PATH/system/system/build.prop" "ro.build.version.oneui")" -lt "50101" ]; then
    PATCHED=true
    DELETE_FROM_WORK_DIR "system" "system/bin/fabric_crypto"
    DELETE_FROM_WORK_DIR "system" "system/etc/init/fabric_crypto.rc"
    DELETE_FROM_WORK_DIR "system" "system/etc/permissions/FabricCryptoLib.xml"
    DELETE_FROM_WORK_DIR "system" "system/etc/permissions/privapp-permissions-com.samsung.android.kmxservice.xml"
    DELETE_FROM_WORK_DIR "system" "system/etc/vintf/manifest/fabric_crypto_manifest.xml"
    DELETE_FROM_WORK_DIR "system" "system/framework/FabricCryptoLib.jar"
    DELETE_FROM_WORK_DIR "system" "system/lib64/com.samsung.security.fabric.cryptod-V1-cpp.so"
    DELETE_FROM_WORK_DIR "system" "system/lib64/vendor.samsung.hardware.security.fkeymaster-V1-cpp.so"
    DELETE_FROM_WORK_DIR "system" "system/lib64/vendor.samsung.hardware.security.fkeymaster-V1-ndk.so"
    DELETE_FROM_WORK_DIR "system" "system/priv-app/KmxService"
fi

# 커널 내부의 KSMBD(인커널 SAMBA 서버) 지원 확인 및 미지원 기기 처리
# - 커널 4.19.x 이하: 지원 안 됨
# - 커널 5.4.x-5.10.x: 백포트 필요 (https://github.com/namjaejeon/ksmbd.git)
# - 커널 5.15.x 이상: 자체 내장 지원
if [ -f "$WORK_DIR/system/system/priv-app/StorageShare/StorageShare.apk" ]; then
    EXTRACT_KERNEL_IMAGE
    if ! grep -q "ksmbd" "$TMP_DIR/out/kernel"; then
        PATCHED=true
        DELETE_FROM_WORK_DIR "system" "system/bin/ksmbd.addshare"
        DELETE_FROM_WORK_DIR "system" "system/bin/ksmbd.adduser"
        DELETE_FROM_WORK_DIR "system" "system/bin/ksmbd.control"
        DELETE_FROM_WORK_DIR "system" "system/bin/ksmbd.mountd"
        DELETE_FROM_WORK_DIR "system" "system/bin/ksmbd.tools"
        DELETE_FROM_WORK_DIR "system" "system/etc/default-permissions/default-permissions-com.samsung.android.hwresourceshare.storage.xml"
        DELETE_FROM_WORK_DIR "system" "system/etc/init/ksmbd.rc"
        DELETE_FROM_WORK_DIR "system" "system/etc/permissions/privapp-permissions-com.samsung.android.hwresourceshare.storage.xml"
        DELETE_FROM_WORK_DIR "system" "system/etc/sysconfig/preinstalled-packages-com.samsung.android.hwresourceshare.storage.xml"
        DELETE_FROM_WORK_DIR "system" "system/etc/ksmbd.conf"
        DELETE_FROM_WORK_DIR "system" "system/priv-app/StorageShare"
    fi
fi

# 삼성 eBPF 스마트 핫스팟 기능 확보 (API 35 미만 기기용)
# - Android 15(V)부터 커널 4.14 지원이 중단되었으므로 API 35 미만에서 작동 확인
# - 커널 4.14 버전은 eBPF 커널 백포트가 따로 필요하므로 "ro.kernel.version" == "4.14" 체크로 남은 잔재 로직 우회 처리
if [ "$TARGET_PLATFORM_SDK_VERSION" -lt "35" ]; then
    EXTRACT_KERNEL_IMAGE
    if grep -q "Linux version 4.14" "$TMP_DIR/out/kernel"; then
        PATCHED=true
        # [b.eq #0xXXXXXX] 분기 명령문을 -> [nop] 실행 안 함으로 헥사 패치
        # - 대상 함수: android::net::MobileBBController::hotspotOn(const std::string)
        HEX_PATCH "$WORK_DIR/system/system/bin/netd" "1f01096be0010054" "1f01096b1f2003d5"
        # - 대상 함수: android::net::MobileBBController::isMBBPathsPresent()
        HEX_PATCH "$WORK_DIR/system/system/bin/netd" "1f01096b20010054" "1f01096b1f2003d5"
    fi
fi

# 타겟 펌웨어의 sbauth(보안 부팅 인증 관련 바이너리) 지원 여부 확인
TARGET_FIRMWARE_PATH="$(cut -d "/" -f 1 -s <<< "$TARGET_FIRMWARE")_$(cut -d "/" -f 2 -s <<< "$TARGET_FIRMWARE")"
if [ -f "$WORK_DIR/system/system/bin/sbauth" ] && \
        [ ! -f "$FW_DIR/$TARGET_FIRMWARE_PATH/system/system/bin/sbauth" ]; then
    PATCHED=true
    DELETE_FROM_WORK_DIR "system" "system/bin/sbauth"
    DELETE_FROM_WORK_DIR "system" "system/etc/init/sbauth.rc"
fi

# 삼성 PASS 지원 확보 (API 35 미만 기기용)
if [ "$TARGET_PLATFORM_SDK_VERSION" -lt "35" ]; then
    if ! grep -q "sec_pass_data_file" "$WORK_DIR/vendor/etc/selinux/vendor_file_contexts"; then
        PATCHED=true
        # StorageManagerService 내의 isPassSupport() 메소드가 무조건 false를 반환하도록 스말리 패치
        SMALI_PATCH "system" "system/framework/services.jar" \
            "smali/com/android/server/StorageManagerService.smali" "return" \
            'isPassSupport()Z' 'false'
    fi
fi

# 구형 usb_notify 커널 드라이버 지원 (API 36 미만 기기용)
# 소스 참고: https://github.com/salvogiangri/UN1CA/discussions/519
# - 'SKY_DEFAULT' 문자열을 체크하여 최신 usb_notify 드라이버가 적용되어 있는지 판별
if [ "$TARGET_PLATFORM_SDK_VERSION" -lt "36" ]; then
    VBOOT_MISSING=true
    KERNEL_MISSING=true

    if [ -f "$WORK_DIR/kernel/vendor_boot.img" ]; then
        # GKI(구글 공통 커널 이미지) 적용 기기 확인
        EXTRACT_KERNEL_MODULES
        if grep -q "SKY_DEFAULT" "$TMP_DIR/out/vendor_ramdisk"*; then
            VBOOT_MISSING=false
        fi
    fi

    # 레거시(구형 비-GKI) 기기 확인
    EXTRACT_KERNEL_IMAGE
    if grep -q "SKY_DEFAULT" "$TMP_DIR/out/kernel"; then
        KERNEL_MISSING=false
    fi

    # 둘 다 누락된 구형 드라이버 환경이라면 호환성 패치 진행
    if $VBOOT_MISSING && $KERNEL_MISSING; then
        PATCHED=true
        SMALI_PATCH "system" "system/framework/services.jar" \
            "smali_classes2/com/android/server/usb/UsbHostRestrictor.smali" "replace" \
            "isFinishLockTimer()Z" \
            "RAINY_RESTRICT_MODE" \
            "2"
        SMALI_PATCH "system" "system/framework/services.jar" \
            "smali_classes2/com/android/server/usb/UsbHostRestrictor.smali" "replace" \
            "onKeyguardStateChanged(Z)V" \
            "CLOUDY_WORK_MODE" \
            "1"
        SMALI_PATCH "system" "system/framework/services.jar" \
            "smali_classes2/com/android/server/usb/UsbHostRestrictor\$1.smali" "replace" \
            "onChange(Z)V" \
            "CLOUDY_WORK_MODE" \
            "1"
        SMALI_PATCH "system" "system/framework/services.jar" \
            "smali_classes2/com/android/server/usb/UsbHostRestrictor\$8.smali" "replace" \
            "handleMessage(Landroid/os/Message;)V" \
            "SUNNY_WORK_MODE" \
            "0"
        SMALI_PATCH "system" "system/framework/services.jar" \
            "smali_classes2/com/android/server/usb/UsbHostRestrictor\$8.smali" "replace" \
            "handleMessage(Landroid/os/Message;)V" \
            "RAINY_RESTRICT_MODE" \
            "2"
        SMALI_PATCH "system" "system/framework/services.jar" \
            "smali_classes2/com/android/server/usb/UsbService\$Lifecycle.smali" "replace" \
            "onBootPhase(I)V" \
            "RAINY_RESTRICT_MODE" \
            "2"
        SMALI_PATCH "system" "system/framework/services.jar" \
            "smali_classes2/com/android/server/usb/UsbService\$Lifecycle.smali" "replace" \
            "onBootPhase(I)V" \
            "CLOUDY_WORK_MODE" \
            "1"
    fi

    unset VBOOT_MISSING KERNEL_MISSING
fi

# 구형 LED 커버 레벨 지원
# - 더 이상 사용되지 않는 'android.nfc.NfcAdapter' API를 삼성 전용 인터페이스인 'com.samsung.android.nfc.adapter.ISamsungNfcAdapter'로 교체
if [ -f "$WORK_DIR/system/system/priv-app/LedCoverService/LedCoverService.apk" ]; then
    if [ "$(GET_FLOATING_FEATURE_CONFIG "SEC_FLOATING_FEATURE_FRAMEWORK_CONFIG_NFC_LED_COVER_LEVEL")" -ge "30" ] && \
            [ "$(GET_FLOATING_FEATURE_CONFIG "SEC_FLOATING_FEATURE_FRAMEWORK_CONFIG_NFC_LED_COVER_LEVEL")" -lt "100" ]; then
        PATCHED=true
        APPLY_PATCH "system" "system/priv-app/LedCoverService/LedCoverService.apk" \
            "$MODPATH/ledcover/LedCoverService.apk/0001-Switch-to-ISamsungNfcAdapter-interface.patch"
    fi
fi

# 싱글테이크 모델 업그레이드 (API 35 미만 기기용)
if [ "$TARGET_PLATFORM_SDK_VERSION" -lt "35" ]; then
    if [ ! -d "$WORK_DIR/vendor/etc/singletake/ClarityScorer" ]; then
        PATCHED=true
        if [ -d "$WORK_DIR/vendor/etc/singletake/aifilter" ]; then
            DELETE_FROM_WORK_DIR "vendor" "etc/singletake/aifilter"
        fi
        if [ -d "$WORK_DIR/vendor/etc/singletake/bestmoment" ]; then
            DELETE_FROM_WORK_DIR "vendor" "etc/singletake/bestmoment"
        fi
        ADD_TO_WORK_DIR "$SOURCE_FIRMWARE" "vendor" \
            "etc/singletake/ClarityScorer" 0 2000 755 "u:object_r:vendor_configs_file:s0"
    fi
fi

if ! $PATCHED; then
    LOG "\033[0;33m! 아무 작업도 하지 않습니다\033[0m"
fi

if [ -d "$TMP_DIR" ]; then
    EVAL "rm -rf \"$TMP_DIR\""
fi

unset PATCHED TARGET_FIRMWARE_PATH
unset -f BACKPORT_SF_PROPS EXTRACT_KERNEL_IMAGE EXTRACT_KERNEL_MODULES
