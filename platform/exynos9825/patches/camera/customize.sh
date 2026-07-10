# Polarr 라이브러리 추가
ADD_TO_WORK_DIR "a73xqxx" "system" "system/etc/public.libraries-polarr.txt" 0 0 644 "u:object_r:system_file:s0"
ADD_TO_WORK_DIR "a73xqxx" "system" "system/lib64/libBestComposition.polarr.so" 0 0 644 "u:object_r:system_lib_file:s0"
ADD_TO_WORK_DIR "a73xqxx" "system" "system/lib64/libFeature.polarr.so" 0 0 644 "u:object_r:system_lib_file:s0"
ADD_TO_WORK_DIR "a73xqxx" "system" "system/lib64/libPolarrSnap.polarr.so" 0 0 644 "u:object_r:system_lib_file:s0"
ADD_TO_WORK_DIR "a73xqxx" "system" "system/lib64/libTracking.polarr.so" 0 0 644 "u:object_r:system_lib_file:s0"
ADD_TO_WORK_DIR "a73xqxx" "system" "system/lib64/libYuv.polarr.so" 0 0 644 "u:object_r:system_lib_file:s0"

DELETE_FROM_WORK_DIR "system" "system/lib64/libenn_wrapper_system.so"
DELETE_FROM_WORK_DIR "system" "system/lib64/libpic_best.arcsoft.so"
DELETE_FROM_WORK_DIR "system" "system/lib64/libdualcam_portraitlighting_gallery_360.so"
DELETE_FROM_WORK_DIR "system" "system/lib64/libarcsoft_dualcam_portraitlighting.so"
DELETE_FROM_WORK_DIR "system" "system/lib64/libdualcam_refocus_gallery_54.so"
DELETE_FROM_WORK_DIR "system" "system/lib64/libhybrid_high_dynamic_range.arcsoft.so"
DELETE_FROM_WORK_DIR "system" "system/lib64/libae_bracket_hdr.arcsoft.so"
DELETE_FROM_WORK_DIR "system" "system/lib64/libface_recognition.arcsoft.so"
DELETE_FROM_WORK_DIR "system" "system/lib64/libmf_bayer_enhance.arcsoft.so"
DELETE_FROM_WORK_DIR "system" "system/lib64/libDualCamBokehCapture.camera.samsung.so"

# 순정 라이브러리 추가
ADD_TO_WORK_DIR "$TARGET_FIRMWARE" "system" "system/lib64/libPortraitDistortionCorrectionCali.arcsoft.so" 0 0 644 "u:object_r:system_lib_file:s0"
ADD_TO_WORK_DIR "$TARGET_FIRMWARE" "system" "system/lib64/libMultiFrameProcessing10.camera.samsung.so" 0 0 644 "u:object_r:system_lib_file:s0"
ADD_TO_WORK_DIR "$TARGET_FIRMWARE" "system" "system/lib64/libMultiFrameProcessing20.camera.samsung.so" 0 0 644 "u:object_r:system_lib_file:s0"
ADD_TO_WORK_DIR "$TARGET_FIRMWARE" "system" "system/lib64/libMultiFrameProcessing20Day.camera.samsung.so" 0 0 644 "u:object_r:system_lib_file:s0"
ADD_TO_WORK_DIR "$TARGET_FIRMWARE" "system" "system/lib64/libMultiFrameProcessing30.camera.samsung.so" 0 0 644 "u:object_r:system_lib_file:s0"
ADD_TO_WORK_DIR "$TARGET_FIRMWARE" "system" "system/lib64/libMultiFrameProcessing30Tuning.camera.samsung.so" 0 0 644 "u:object_r:system_lib_file:s0"
ADD_TO_WORK_DIR "$TARGET_FIRMWARE" "system" "system/lib64/vendor.samsung_slsi.hardware.iva@1.0.so" 0 0 644 "u:object_r:system_lib_file:s0"
ADD_TO_WORK_DIR "$TARGET_FIRMWARE" "system" "system/lib64/vendor.samsung_slsi.hardware.MultiFrameProcessing20@1.0.so" 0 0 644 "u:object_r:system_lib_file:s0"

# Snap 라이브러리 추가
ADD_TO_WORK_DIR "p3sxxx" "system" "system/lib64/libeden_wrapper_system.so" 0 0 644 "u:object_r:system_lib_file:s0"
ADD_TO_WORK_DIR "p3sxxx" "system" "system/lib64/libsnap_aidl.snap.samsung.so" 0 0 644 "u:object_r:system_lib_file:s0"

# SwIsp 블롭 추가
DELETE_FROM_WORK_DIR "vendor" "saiv/swisp_1.0"
ADD_TO_WORK_DIR "p3sxxx" "vendor" "saiv/swisp_1.0"
ADD_TO_WORK_DIR "p3sxxx" "system" "system/lib64/libSwIsp_core.camera.samsung.so" 0 0 644 "u:object_r:system_lib_file:s0"
ADD_TO_WORK_DIR "p3sxxx" "system" "system/lib64/libSwIsp_wrapper_v1.camera.samsung.so" 0 0 644 "u:object_r:system_lib_file:s0"

# S21 (p3sxxx) 싱글테이크 모델 추가
DELETE_FROM_WORK_DIR "vendor" "etc/singletake"
ADD_TO_WORK_DIR "p3sxxx" "vendor" "etc/singletake"
ADD_TO_WORK_DIR "p3sxxx" "system" "system/priv-app/SingleTakeService/SingleTakeService.apk" 0 0 644 "u:object_r:system_file:s0"
ADD_TO_WORK_DIR "p3sxxx" "system" "system/cameradata/singletake/service-feature.xml" 0 0 644 "u:object_r:system_file:s0"

# S21 (p3sxxx) MIDAS 추가
DELETE_FROM_WORK_DIR "vendor" "etc/midas"
DELETE_FROM_WORK_DIR "vendor" "etc/VslMesDetector"
ADD_TO_WORK_DIR "p3sxxx" "vendor" "etc/midas"
ADD_TO_WORK_DIR "p3sxxx" "vendor" "etc/VslMesDetector"
sed -i "s/r0s/dummy/g" "$WORK_DIR/vendor/etc/midas/midas_config.json"
sed -i "s/p3s/r0s/g" "$WORK_DIR/vendor/etc/midas/midas_config.json"
DELETE_FROM_WORK_DIR "system" "system/priv-app/PhotoRemasterService/oat"
ADD_TO_WORK_DIR "p3sxxx" "system" "system/priv-app/PhotoRemasterService/PhotoRemasterService.apk"
ADD_TO_WORK_DIR "p3sxxx" "system" "system/lib64/libmidas_core.camera.samsung.so"
ADD_TO_WORK_DIR "p3sxxx" "system" "system/lib64/libmidas_DNNInterface.camera.samsung.so"