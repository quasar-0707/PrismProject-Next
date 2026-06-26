if [ ! "$(GET_PROP "system" "ro.unica.codename")" ]; then
    # 최신 삼성 플래그십 기기의 코드네임과 일치시킴
    ROM_CODENAME="$(basename "$MODPATH")"
    SET_PROP "system" "ro.unica.codename" "${ROM_CODENAME^}"
    unset ROM_CODENAME
fi

# 2025 오디오 팩
LOG_STEP_IN "- 2025 오디오 팩 추가 중..."
DELETE_FROM_WORK_DIR "system" "system/hidden/INTERNAL_SDCARD/Music/Samsung/Over_the_Horizon.mp3"
ADD_TO_WORK_DIR "pa2qxxx" "system" \
    "system/hidden/INTERNAL_SDCARD/Music/Samsung/Over_the_Horizon.m4a" 0 0 644 "u:object_r:system_file:s0"
DELETE_FROM_WORK_DIR "system" "system/media/audio/notifications"
DELETE_FROM_WORK_DIR "system" "system/media/audio/ringtones"
if $TARGET_AUDIO_SUPPORT_ACH_RINGTONE; then
    ADD_TO_WORK_DIR "pa2qxxx" "system" "system/etc/ringtones_count_list.txt" 0 0 644 "u:object_r:system_file:s0"
    ADD_TO_WORK_DIR "pa2qxxx" "system" "system/media/audio/notifications" 0 0 755 "u:object_r:system_file:s0"
    ADD_TO_WORK_DIR "pa2qxxx" "system" "system/media/audio/ringtones" 0 0 755 "u:object_r:system_file:s0"
    SET_PROP "vendor" "ro.config.ringtone" "ACH_Galaxy_Bells.ogg"
    SET_PROP "vendor" "ro.config.notification_sound" "ACH_Brightline.ogg"
    SET_PROP "vendor" "ro.config.alarm_alert" "ACH_Morning_Xylophone.ogg"
    SET_PROP "vendor" "ro.config.media_sound" "Media_preview_Over_the_horizon.ogg"
    SET_PROP "vendor" "ro.config.ringtone_2" "ACH_Atomic_Bell.ogg"
    SET_PROP "vendor" "ro.config.notification_sound_2" "ACH_Three_Star.ogg"
else
    ADD_TO_WORK_DIR "a56xnaxx" "system" "system/etc/ringtones_count_list.txt" 0 0 644 "u:object_r:system_file:s0"
    ADD_TO_WORK_DIR "a56xnaxx" "system" "system/media/audio/notifications" 0 0 755 "u:object_r:system_file:s0"
    ADD_TO_WORK_DIR "a56xnaxx" "system" "system/media/audio/ringtones" 0 0 755 "u:object_r:system_file:s0"
    SET_PROP "vendor" "ro.config.ringtone" "Galaxy_Bells.ogg"
    SET_PROP "vendor" "ro.config.notification_sound" "Brightline.ogg"
    SET_PROP "vendor" "ro.config.alarm_alert" "Morning_Xylophone.ogg"
    SET_PROP "vendor" "ro.config.media_sound" "Media_preview_Over_the_horizon.ogg"
    SET_PROP "vendor" "ro.config.ringtone_2" "Atomic_Bell.ogg"
    SET_PROP "vendor" "ro.config.notification_sound_2" "Three_Star.ogg"
fi
ADD_TO_WORK_DIR "pa2qxxx" "system" \
    "system/media/audio/ui/Media_preview_Over_the_horizon.ogg" 0 0 644 "u:object_r:system_file:s0"
APPLY_PATCH "system" "system/priv-app/SecSoundPicker/SecSoundPicker.apk" \
    "$MODPATH/brandsound/SecSoundPicker.apk/0001-Enable-SUPPORT_SAMSUNG_BRAND_SOUND_ONEUI_7.patch"
LOG_STEP_OUT

# 색상 최적화
LOG_STEP_IN "- 색상 최적화 기능 활성화 중..."
ADD_TO_WORK_DIR "pa2qxxx" "system" \
    "system/etc/permissions/privapp-permissions-com.samsung.android.sead.xml" 0 0 644 "u:object_r:system_file:s0"
ADD_TO_WORK_DIR "pa2qxxx" "system" \
    "system/priv-app/EnvironmentAdaptiveDisplay/EnvironmentAdaptiveDisplay.apk" 0 0 644 "u:object_r:system_file:s0"
if $TARGET_LCD_SUPPORT_MDNIE_HW; then
    APPLY_PATCH "system" "system/framework/services.jar" \
        "$MODPATH/ead/services.jar/0001-Add-Adaptive-color-tone-feature.patch"
else
    APPLY_PATCH "system" "system/framework/services.jar" \
        "$MODPATH/ead_mdnie/services.jar/0001-Add-Adaptive-color-tone-feature.patch"
fi
if $TARGET_COMMON_SUPPORT_DYN_RESOLUTION_CONTROL; then
    if [ "$TARGET_PLATFORM_SDK_VERSION" -ge "36" ]; then
        APPLY_PATCH "system" "system/priv-app/SecSettings/SecSettings.apk" \
            "$MODPATH/ead_resolution/SecSettings.apk/0001-Add-Adaptive-color-tone-feature.patch"
    else
        APPLY_PATCH "system" "system/priv-app/SecSettings/SecSettings.apk" \
            "$MODPATH/ead_resolution_legacy/SecSettings.apk/0001-Add-Adaptive-color-tone-feature.patch"
    fi
else
    APPLY_PATCH "system" "system/priv-app/SecSettings/SecSettings.apk" \
        "$MODPATH/ead/SecSettings.apk/0001-Add-Adaptive-color-tone-feature.patch"
fi
APPLY_PATCH "system" "system/priv-app/SettingsProvider/SettingsProvider.apk" \
    "$MODPATH/ead/SettingsProvider.apk/0001-Add-Adaptive-color-tone-feature.patch"
APPLY_PATCH "system_ext" "priv-app/SystemUI/SystemUI.apk" \
    "$MODPATH/ead/SystemUI.apk/0001-Add-Adaptive-color-tone-toggle.patch"
LOG_STEP_OUT

# AI 버전을 20253으로 설정
SET_FLOATING_FEATURE_CONFIG "SEC_FLOATING_FEATURE_COMMON_CONFIG_AI_VERSION" "20253"
ADD_TO_WORK_DIR "pa2qxxx" "system" "system/app/SketchBook/SketchBook.apk" 0 0 644 "u:object_r:system_file:s0"

# Media Context Analyzer
LOG_STEP_IN "- Media Context Analyzer 기능 활성화 중..."
ADD_TO_WORK_DIR "a56xnaxx" "system" "system/etc/mediacontextanalyzer/Detection.tflite" 0 0 644 "u:object_r:system_file:s0"
ADD_TO_WORK_DIR "a56xnaxx" "system" "system/etc/mediacontextanalyzer/human-pet-det_SR-V131.tflite" 0 0 644 "u:object_r:system_file:s0"
ADD_TO_WORK_DIR "a56xnaxx" "system" "system/etc/mediacontextanalyzer/human-pet-pose_SR-V200.tflite" 0 0 644 "u:object_r:system_file:s0"
ADD_TO_WORK_DIR "a56xnaxx" "system" "system/etc/mediacontextanalyzer/Keyword.tflite" 0 0 644 "u:object_r:system_file:s0"
ADD_TO_WORK_DIR "a56xnaxx" "system" "system/etc/mediacontextanalyzer/keyword-classification_SR-V031.tflite" 0 0 644 "u:object_r:system_file:s0"
EVAL "ln -s \"human-pet-pose_SR-V200.tflite\" \"$WORK_DIR/system/system/etc/mediacontextanalyzer/Pose.tflite\""
SET_METADATA "system" "system/etc/mediacontextanalyzer/Pose.tflite" 0 0 644 "u:object_r:system_file:s0"
ADD_TO_WORK_DIR "a56xnaxx" "system" "system/lib64/libcontextanalyzer_jni.media.samsung.so" 0 0 644 "u:object_r:system_lib_file:s0"
ADD_TO_WORK_DIR "a56xnaxx" "system" "system/lib64/libmediacontextanalyzer.so" 0 0 644 "u:object_r:system_lib_file:s0"
ADD_TO_WORK_DIR "a56xnaxx" "system" "system/lib64/libvideo-highlight-arm64-v8a.so" 0 0 644 "u:object_r:system_lib_file:s0"
SET_FLOATING_FEATURE_CONFIG "SEC_FLOATING_FEATURE_MMFW_CONFIG_MEDIA_CONTEXT_ANALIZER_CORE" "GPU"
SET_FLOATING_FEATURE_CONFIG "SEC_FLOATING_FEATURE_MMFW_SUPPORT_MEDIA_CONTEXT_ANALIZER" "TRUE"
LOG_STEP_OUT

# 오디오 지우개
# SEC_PRODUCT_FEATURE_MMFW_SUPPORT_MEDIA_CONTEXT_ANALIZER 활성화 필요
LOG_STEP_IN "- 오디오 지우개 기능 활성화 중..."
ADD_TO_WORK_DIR "pa2qxxx" "system" "system/etc/audio_ae_intervals.conf" 0 0 644 "u:object_r:system_file:s0"
ADD_TO_WORK_DIR "pa2qxxx" "system" "system/etc/fastScanner.tflite" 0 0 644 "u:object_r:system_file:s0"
ADD_TO_WORK_DIR "pa2qxxx" "system" "system/etc/mss_v0.13.0_4ch.sorione" 0 0 644 "u:object_r:system_file:s0"
ADD_TO_WORK_DIR "pa2qxxx" "system" "system/etc/public.libraries-audio.samsung.txt" 0 0 644 "u:object_r:system_file:s0"
ADD_TO_WORK_DIR "pa2qxxx" "system" "system/lib64/libmediasndk.mediacore.samsung.so" 0 0 644 "u:object_r:system_lib_file:s0"
ADD_TO_WORK_DIR "pa2qxxx" "system" "system/lib64/libmediasndk.so" 0 0 644 "u:object_r:system_lib_file:s0"
ADD_TO_WORK_DIR "pa2qxxx" "system" "system/lib64/libmultisourceseparator.audio.samsung.so" 0 0 644 "u:object_r:system_lib_file:s0"
ADD_TO_WORK_DIR "pa2qxxx" "system" "system/lib64/libmultisourceseparator.so" 0 0 644 "u:object_r:system_lib_file:s0"
ADD_TO_WORK_DIR "pa2qxxx" "system" "system/lib64/libsbs.so" 0 0 644 "u:object_r:system_lib_file:s0"
ADD_TO_WORK_DIR "pa2qxxx" "system" "system/lib64/libtensorflowlite_gpu_delegate.so" 0 0 644 "u:object_r:system_lib_file:s0"
ADD_TO_WORK_DIR "pa2qxxx" "system" "system/lib64/libveframework.videoeditor.samsung.so" 0 0 644 "u:object_r:system_lib_file:s0"
SET_FLOATING_FEATURE_CONFIG "SEC_FLOATING_FEATURE_AUDIO_CONFIG_MULTISOURCE_SEPARATOR" "{FastScanning_6, SourceSeparator_4, Version_1.3.0}"
LOG_STEP_OUT

# Now brief
# SEC_FLOATING_FEATURE_COMMON_CONFIG_AI_VERSION >= 20251
# 또는 SEC_FLOATING_FEATURE_FRAMEWORK_SUPPORT_AI_BRIEF_FOR_UT 활성화 필요
LOG_STEP_IN "- Now brief 기능 활성화 중..."
ADD_TO_WORK_DIR "pa2qxxx" "system" \
    "system/etc/default-permissions/default-permissions-com.samsung.android.app.moments.xml" 0 0 644 "u:object_r:system_file:s0"
ADD_TO_WORK_DIR "pa2qxxx" "system" \
    "system/etc/permissions/privapp-permissions-com.samsung.android.app.moments.xml" 0 0 644 "u:object_r:system_file:s0"
ADD_TO_WORK_DIR "pa2qxxx" "system" \
    "system/etc/sysconfig/moments.xml" 0 0 644 "u:object_r:system_file:s0"
ADD_TO_WORK_DIR "pa2qxxx" "system" "system/priv-app/Moments/Moments.apk" 0 0 644 "u:object_r:system_file:s0"
LOG "- Smart suggestions 앱 새로 설치 중..."
DOWNLOAD_FILE "$(GET_GALAXY_STORE_DOWNLOAD_URL "com.samsung.android.smartsuggestions")" \
    "$WORK_DIR/system/system/priv-app/SamsungSmartSuggestions/SamsungSmartSuggestions.apk"

# 삼성은 2026년 3월에 Smart suggestions 앱 업데이트를 배포했습니다.
# "basic-global-release" 버전의 버전 넘버링은 "full-global-release" 버전과 다릅니다.
# 이는 의도된 것입니다. 삼성은 지원되지 않는 기기에 이 변형 버전이 설치되는 것을 방지하기 위해 
# 패키지 관리자(PM)의 다운그레이드 체크를 발동시키려고 의도적으로 더 낮은 버전 번호를 사용합니다.
# 사용자가 "AI 미지원" 앱으로 업데이트하는 것을 막기 위해, 최신 가용 버전과 일치하도록 versionCode를 변조합니다.
DECODE_APK "system" "system/priv-app/SamsungSmartSuggestions/SamsungSmartSuggestions.apk"
LOG "- SamsungSmartSuggestions.apk의 versionCode를 수정하는 중..."
EVAL "sed -i \"s/710500000/711100100/g\" \"$APKTOOL_DIR/system/priv-app/SamsungSmartSuggestions/SamsungSmartSuggestions.apk/apktool.yml\""
# ]
SET_FLOATING_FEATURE_CONFIG "SEC_FLOATING_FEATURE_FRAMEWORK_SUPPORT_PERSONALIZED_DATA_CORE" "TRUE"
LOG_STEP_OUT

# Semantic search
# SEC_FLOATING_FEATURE_COMMON_CONFIG_AI_VERSION >= 20251 활성화 필요
LOG_STEP_IN "- Semantic search 기능 활성화 중..."
ADD_TO_WORK_DIR "pa2qxxx" "system" \
    "system/etc/default-permissions/default-permissions-com.samsung.mediasearch.xml" 0 0 644 "u:object_r:system_file:s0"
ADD_TO_WORK_DIR "pa2qxxx" "system" \
    "system/etc/mediasearch/data/dec_adaptor.tflite" 0 0 644 "u:object_r:system_file:s0"
ADD_TO_WORK_DIR "pa2qxxx" "system" \
    "system/etc/mediasearch/data/dec_event.tflite" 0 0 644 "u:object_r:system_file:s0"
ADD_TO_WORK_DIR "pa2qxxx" "system" \
    "system/etc/mediasearch/data/enc_image.tflite" 0 0 644 "u:object_r:system_file:s0"
ADD_TO_WORK_DIR "pa2qxxx" "system" \
    "system/etc/mediasearch/data/enc_text.tflite" 0 0 644 "u:object_r:system_file:s0"
ADD_TO_WORK_DIR "pa2qxxx" "system" \
    "system/etc/mediasearch/data/versioninfo.json" 0 0 644 "u:object_r:system_file:s0"
ADD_TO_WORK_DIR "pa2qxxx" "system" \
    "system/etc/permissions/privapp-permissions-com.samsung.mediasearch.xml" 0 0 644 "u:object_r:system_file:s0"
ADD_TO_WORK_DIR "pa2qxxx" "system" \
    "system/priv-app/MediaSearch/MediaSearch.apk" 0 0 644 "u:object_r:system_file:s0"
ADD_TO_WORK_DIR "pa2qxxx" "system" \
    "system/priv-app/SemanticSearchCore/SemanticSearchCore.apk" 0 0 644 "u:object_r:system_file:s0"
DECODE_APK "system" "system/priv-app/SecSettingsIntelligence/SecSettingsIntelligence.apk"
LOG "- /system/system/priv-app/SecSettingsIntelligence/SecSettingsIntelligence.apk에서 Semantic search 기능 활성화 중"
EVAL "cp -a \"$MODPATH/semanticsearch/SecSettingsIntelligence.apk/res/raw/\"* \"$APKTOOL_DIR/system/priv-app/SecSettingsIntelligence/SecSettingsIntelligence.apk/res/raw\""
SMALI_PATCH "system" "system/priv-app/SecSettingsIntelligence/SecSettingsIntelligence.apk" \
    "smali_classes2/com/samsung/android/settings/intelligence/Rune.smali" "replaceall" \
    "const-string v1, \\\"\\\"" \
    "const-string v1, \\\"400\\\"" \
    > /dev/null
SET_FLOATING_FEATURE_CONFIG "SEC_FLOATING_FEATURE_MSCH_SUPPORT_NLSEARCH" "TRUE"
LOG_STEP_OUT

# 게임 부스터 (Game Booster)
LOG "- 최신 게임 부스터 앱 다운로드 중..."
DOWNLOAD_FILE "$(GET_GALAXY_STORE_DOWNLOAD_URL "com.samsung.android.game.gametools")" \
    "$WORK_DIR/system/system/priv-app/GameTools_Dream/GameTools_Dream.apk"

# 갤럭시 AI 펫 감지 (Pet Detector)
LOG_STEP_IN "- Galaxy AI 펫 감지 기능 활성화 중..."
if [ -d "$WORK_DIR/vendor/etc/petdetector/studio_pd" ]; then
    DELETE_FROM_WORK_DIR "vendor" "etc/petdetector/studio_pd"
fi
ADD_TO_WORK_DIR "gts11xx" "vendor" "etc/petdetector/studio_pd/config_thresholds.json" 0 0 644 "u:object_r:vendor_configs_file:s0"
ADD_TO_WORK_DIR "gts11xx" "vendor" "etc/petdetector/studio_pd/studio_pd_cnn.info" 0 0 644 "u:object_r:vendor_configs_file:s0"
ADD_TO_WORK_DIR "gts11xx" "vendor" "etc/petdetector/studio_pd/studio_pd_cnn.tflite" 0 0 644 "u:object_r:vendor_configs_file:s0"
LOG_STEP_OUT