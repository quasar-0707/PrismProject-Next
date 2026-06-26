#!/usr/bin/env bash
# Copyright (c) 2025 Salvo Giangreco
# SPDX-License-Identifier: GPL-3.0-or-later

# [
source "$SRC_DIR/scripts/utils/build_utils.sh" || exit 1

FORCE=false
FS_TYPE=""
SPARSE=false
AVB_SIGN=""
MAP_FILE=false
INPUT_DIR=""
PARTITION=""
IMAGE_SIZE=""
INODES=""
MOUNT_POINT=""
OUTPUT_FILE=""
FILE_CONTEXT_FILE=""
FS_CONFIG_FILE=""

# https://android.googlesource.com/platform/build/+/refs/tags/android-15.0.0_r1/tools/releasetools/build_image.py#266
BUILD_IMAGE_MKFS()
{
    local SPARSE=$SPARSE
    local MANUAL_SPARSE=false

    # sparse 이미지 빌드 시 OOM(메모리 부족) 에러 방지
    if $SPARSE && [[ "$(awk '/MemTotal/ { print int ($2 / 1024) }' "/proc/meminfo")" -lt "10240" ]]; then
        SPARSE=false
        MANUAL_SPARSE=true
    fi

    local BUILD_CMD

    case "$FS_TYPE" in
        "ext4")
            BUILD_CMD+="mkuserimg_mke2fs "
            if $SPARSE; then
                BUILD_CMD+="-s "
            fi
            BUILD_CMD+="\"$INPUT_DIR\" \"$OUTPUT_FILE\" \"ext4\" \"$MOUNT_POINT\" "
            BUILD_CMD+="\"$IMAGE_SIZE\" "
            # https://android.googlesource.com/platform/build/+/refs/tags/android-15.0.0_r1/tools/releasetools/build_image.py#808
            BUILD_CMD+="-j \"0\" "
            # https://android.googlesource.com/platform/build/+/refs/tags/android-15.0.0_r1/tools/releasetools/build_image.py#49
            BUILD_CMD+="-T \"1230735600\" "
            BUILD_CMD+="-C \"$FS_CONFIG_FILE\" "
            if $MAP_FILE; then
                BUILD_CMD+="-B \"${OUTPUT_FILE//.img/.map}\" "
            fi
            BUILD_CMD+="-L \"$MOUNT_POINT\" "
            if [ "$INODES" ]; then
                BUILD_CMD+="-i \"$INODES\" "
            fi
            # https://android.googlesource.com/platform/build/+/refs/tags/android-15.0.0_r1/tools/releasetools/build_image.py#808
            BUILD_CMD+="-M \"0\" "
            # https://android.googlesource.com/platform/build/+/refs/tags/android-15.0.0_r1/tools/releasetools/build_image.py#331
            BUILD_CMD+="--inode_size \"256\" "
            BUILD_CMD+="\"$FILE_CONTEXT_FILE\""

            # lost+found 항목이 file_context/fs_config에 없을 경우 발생할 수 있는 빌드 실패 방지
            if ! grep -q -F "lost+found" "$FILE_CONTEXT_FILE"; then
                if [[ "$PARTITION" == "system" ]]; then
                    echo "/lost\+found u:object_r:rootfs:s0" >> "$FILE_CONTEXT_FILE"
                else
                    echo "/$PARTITION/lost\+found $(head -n 1 "$FILE_CONTEXT_FILE" | cut -f 2 -d " ")" >> "$FILE_CONTEXT_FILE"
                fi
            fi

            if ! grep -q -F "lost+found" "$FS_CONFIG_FILE"; then
                if [[ "$PARTITION" == "system" ]]; then
                    echo "lost+found 0 0 700 capabilities=0x0" >> "$FS_CONFIG_FILE"
                else
                    echo "$PARTITION/lost+found 0 0 700 capabilities=0x0" >> "$FS_CONFIG_FILE"
                fi
            fi
            ;;
        "erofs")
            BUILD_CMD+="mkfs.erofs "
            # https://android.googlesource.com/platform/build/+/refs/tags/android-15.0.0_r1/core/Makefile#2084
            BUILD_CMD+="-z \"lz4hc,9\" "
            BUILD_CMD+="-b \"4096\" "
            BUILD_CMD+="--mount-point \"$MOUNT_POINT\" "
            BUILD_CMD+="--fs-config-file \"$FS_CONFIG_FILE\" "
            BUILD_CMD+="--file-contexts \"$FILE_CONTEXT_FILE\" "
            # 삼성은 erofs/f2fs에 다른 고정 기본 타임스탬프를 사용함
            BUILD_CMD+="-T \"1640995200\" "
            if $MAP_FILE; then
                BUILD_CMD+="--block-list-file \"${OUTPUT_FILE//.img/.map}\" "
            fi
            BUILD_CMD+="\"$OUTPUT_FILE\" \"$INPUT_DIR\""

            # mkfs.erofs는 자체적인 sparse 기능을 지원하지 않음
            if $SPARSE; then
                MANUAL_SPARSE=true
            fi
            ;;
        "f2fs")
            BUILD_CMD+="mkf2fsuserimg "
            BUILD_CMD+="\"$OUTPUT_FILE\" \"$IMAGE_SIZE\" "
            if $SPARSE; then
                BUILD_CMD+="-S "
            fi
            BUILD_CMD+="-C \"$FS_CONFIG_FILE\" "
            BUILD_CMD+="-f \"$INPUT_DIR\" "
            BUILD_CMD+="-s \"$FILE_CONTEXT_FILE\" "
            BUILD_CMD+="-t \"$MOUNT_POINT\" "
            # 삼성은 erofs/f2fs에 다른 고정 기본 타임스탬프를 사용함
            BUILD_CMD+="-T \"1640995200\" "
            if $MAP_FILE; then
                BUILD_CMD+="-B \"${OUTPUT_FILE//.img/.map}\" "
            fi
            BUILD_CMD+="-L \"$MOUNT_POINT\" "
            # https://android.googlesource.com/platform/build/+/refs/tags/android-15.0.0_r1/tools/releasetools/build_image.py#818
            BUILD_CMD+="--readonly "
            BUILD_CMD+="-b \"4096\""

            # 자주 발생하는 f2fs의 꼬임 현상 해결
            if [[ "$PARTITION" != "system" ]] && ! grep -q "^/$PARTITION/$PARTITION " "$FILE_CONTEXT_FILE"; then
                echo "/$PARTITION/$PARTITION $(head -n 1 "$FILE_CONTEXT_FILE" | cut -d " " -f 2)" >> "$FILE_CONTEXT_FILE"
            fi
            ;;
    esac

    EVAL "$BUILD_CMD" || exit 1

    if $MANUAL_SPARSE; then
        EVAL "img2simg \"$OUTPUT_FILE\" \"$OUTPUT_FILE.sparse\"" || exit 1
        mv -f "$OUTPUT_FILE.sparse" "$OUTPUT_FILE"
    fi
}

# https://android.googlesource.com/platform/build/+/refs/tags/android-15.0.0_r1/tools/releasetools/verity_utils.py#224
CALCULATE_AVB_MAX_IMAGE_SIZE() { avbtool add_hashtree_footer --partition_size "$1" --calc_max_image_size; }

# https://android.googlesource.com/platform/build/+/refs/tags/android-15.0.0_r1/tools/releasetools/verity_utils.py#157
CALCULATE_AVB_MIN_PARTITION_SIZE()
{
    local IMAGE_RATIO
    local MAX_IMAGE_SIZE
    local PARTITION_SIZE
    local LOW
    local MID
    local HIGH
    local DELTA

    # 최종 파티션 크기를 근사치로 구하기 위해 이미지 크기를 파티션 크기로 가정함.
    IMAGE_RATIO="$(bc -l <<< "$(CALCULATE_AVB_MAX_IMAGE_SIZE "$IMAGE_SIZE") / $IMAGE_SIZE")"

    # 최적의 파티션 크기를 찾기 위한 이진 탐색(Binary Search) 준비.
    LOW="$(bc -l <<< "scale=0; $(bc -l <<< "$IMAGE_SIZE / $IMAGE_RATIO") / 4096")"
    LOW="$(bc -l <<< "($LOW * 4096) - 4096")"

    # lo 값이 충분히 작은지 확인: max_image_size는 <= image_size여야 함.
    DELTA="4096"
    MAX_IMAGE_SIZE="$(CALCULATE_AVB_MAX_IMAGE_SIZE "$LOW")"
    while [[ "$MAX_IMAGE_SIZE" -gt "$IMAGE_SIZE" ]]; do
        IMAGE_RATIO="$(bc -l <<< "$MAX_IMAGE_SIZE / $LOW")"
        LOW="$(bc -l <<< "scale=0; $(bc -l <<< "$IMAGE_SIZE / $IMAGE_RATIO") / 4096")"
        LOW="$(bc -l <<< "($LOW * 4096) - $DELTA")"
        DELTA="$(bc -l <<< "$DELTA * 2")"
        MAX_IMAGE_SIZE="$(CALCULATE_AVB_MAX_IMAGE_SIZE "$LOW")"
    done

    HIGH="$(bc -l <<< "$LOW + 4096")"

    # hi 값이 충분히 큰지 확인: max_image_size는 >= image_size여야 함
    DELTA="4096"
    MAX_IMAGE_SIZE="$(CALCULATE_AVB_MAX_IMAGE_SIZE "$HIGH")"
    while [[ "$MAX_IMAGE_SIZE" -lt "$IMAGE_SIZE" ]]; do
        IMAGE_RATIO="$(bc -l <<< "$MAX_IMAGE_SIZE / $HIGH")"
        HIGH="$(bc -l <<< "scale=0; $(bc -l <<< "$IMAGE_SIZE / $IMAGE_RATIO") / 4096")"
        HIGH="$(bc -l <<< "($HIGH * 4096) + $DELTA")"
        DELTA="$(bc -l <<< "$DELTA * 2")"
        MAX_IMAGE_SIZE="$(CALCULATE_AVB_MAX_IMAGE_SIZE "$HIGH")"
    done

    PARTITION_SIZE="$HIGH"

    # 이진 탐색 시작
    while [[ "$LOW" -lt "$HIGH" ]]; do
        MID="$(bc -l <<< "scale=0; ($(bc -l <<< "$LOW + $HIGH")) / (2 * 4096)")"
        MID="$(bc -l <<< "$MID * 4096")"
        MAX_IMAGE_SIZE="$(CALCULATE_AVB_MAX_IMAGE_SIZE "$MID")"
        if [[ "$MAX_IMAGE_SIZE" -ge "$IMAGE_SIZE" ]]; then # mid가 image_size를 감당할 수 있는 경우
            if [[ "$MID" -lt "$PARTITION_SIZE" ]]; then # 더 작은 파티션 크기를 찾은 경우
                PARTITION_SIZE="$MID"
            fi
            HIGH="$MID"
        else
            LOW="$(bc -l <<< "$MID + 4096")"
        fi
    done

    echo "$PARTITION_SIZE"
}

# https://android.googlesource.com/platform/build/+/refs/tags/android-15.0.0_r1/tools/releasetools/build_image.py#247
CALCULATE_SIZE_AND_RESERVED()
{
    local SIZE="$1"

    # 예약된 파티션 크기가 설정되지 않았다고 가정함
    if [[ "$FS_TYPE" == "erofs" ]]; then
        # AVB 푸터를 위해 0.3%의 마진 또는 최소 크기를 부여함
        SIZE="$(bc -l <<< "scale=0; ($SIZE * 1003) / 1000")"
        [[ "$SIZE" -lt "262144" ]] && SIZE="262144"
    else
        SIZE="$(bc -l <<< "scale=0; ($SIZE * 1.1) / 1")" # 빌드 실패를 방지하기 위해 10%의 여유 공간 추가
        SIZE="$(bc -l <<< "$SIZE + 16777216")" # 16 MB의 예약 공간 추가
    fi

    echo "$SIZE"
}

# https://android.googlesource.com/platform/build/+/refs/tags/android-15.0.0_r1/tools/releasetools/verity_utils.py#264
GET_AVBTOOL_CMD()
{
    local CMD

    CMD+="avbtool add_hashtree_footer "
    CMD+="--image \"$OUTPUT_FILE\" "
    CMD+="--partition_size \"$IMAGE_SIZE\" "
    CMD+="--partition_name \"$PARTITION\" "
    CMD+="--hash_algorithm \"sha256\" "
    CMD+="--algorithm \"SHA256_RSA4096\" "
    CMD+="--key \"$SRC_DIR/security/avb/testkey_rsa4096.pem\""

    echo "$CMD"
}

# https://android.googlesource.com/platform/build/+/refs/tags/android-15.0.0_r1/tools/releasetools/build_image.py#77
GET_INODE_USAGE()
{
    local INODES
    local SPARE_INODES

    INODES="$(find "$1" -print | wc -l)"
    SPARE_INODES="$(bc -l <<< "scale=0; ($INODES * 6) / 100")"
    [[ "$SPARE_INODES" -lt "12" ]] && SPARE_INODES="12"

    bc -l <<< "$INODES + $SPARE_INODES"
}

PREPARE_SCRIPT()
{
    if [[ "$#" == 0 ]]; then
        PRINT_USAGE
        exit 1
    fi

    FS_TYPE="$1"
    if [[ "$FS_TYPE" != "ext4" ]] && \
            [[ "$FS_TYPE" != "f2fs" ]] && \
            [[ "$FS_TYPE" != "erofs" ]]; then
        LOGE "지원하지 않는 파일 시스템 유형입니다: $FS_TYPE"
        exit 1
    fi

    shift

    while [[ "$1" == "-"* ]]; do
        if [[ "$1" == "--avb" ]] || [[ "$1" == "--no-avb" ]]; then
            if [ ! "$AVB_SIGN" ]; then
                [[ "$1" == "--avb" ]] && AVB_SIGN=true
                [[ "$1" == "--no-avb" ]] && AVB_SIGN=false
            fi
        elif [[ "$1" == "--force" ]] || [[ "$1" == "-f" ]]; then
            FORCE=true
        elif [[ "$1" == "--generate-map" ]] || [[ "$1" == "-m" ]]; then
            MAP_FILE=true
        elif [[ "$1" == "--inodes" ]] || [[ "$1" == "-i" ]]; then
            shift; INODES="$1"
            if ! [[ "$INODES" =~ ^[+-]?[0-9]+$ ]]; then
                LOGE "유효하지 않은 아이노드 개수입니다: $INODES"
                exit 1
            elif [[ "$FS_TYPE" != "ext4" ]]; then
                LOGW "파일 시스템 유형이 $FS_TYPE 이므로 아이노드 개수 플래그를 무시합니다."
            fi
        elif [[ "$1" == "--output" ]] || [[ "$1" == "-o" ]]; then
            shift; OUTPUT_FILE="$1"
            if [[ "$OUTPUT_FILE" != *".img" ]]; then
                LOGE "출력 파일은 반드시 \".img\" 확장자여야 합니다."
                exit 1
            fi
        elif [[ "$1" == "--partition-name" ]] || [[ "$1" == "-p" ]]; then
            shift; PARTITION="$1"
            if ! IS_VALID_PARTITION_NAME "$PARTITION"; then
                LOGE "\"$PARTITION\"은(는) 올바른 파티션 이름이 아닙니다."
                exit 1
            fi
        elif [[ "$1" == "--partition-size" ]] || [[ "$1" == "-s" ]]; then
            shift; IMAGE_SIZE="$1"
            if ! [[ "$IMAGE_SIZE" =~ ^[+-]?[0-9]+$ ]]; then
                LOGE "유효하지 않은 파티션 크기입니다: $IMAGE_SIZE"
                exit 1
            fi
        elif [[ "$1" == "--sparse" ]] || [[ "$1" == "-S" ]]; then
            SPARSE=true
        else
            LOGE "알 수 없는 옵션입니다: $1"
            exit 1
        fi

        shift
    done

    if [ ! "$AVB_SIGN" ]; then
        if $TARGET_DISABLE_AVB_SIGNING; then
            AVB_SIGN=false
        else
            AVB_SIGN=true
        fi
    fi

    INPUT_DIR="$1"
    if [ ! "$INPUT_DIR" ]; then
        PRINT_USAGE
        exit 1
    elif [ ! -d "$INPUT_DIR" ]; then
        LOGE "폴더가 존재하지 않습니다: ${INPUT_DIR//$SRC_DIR\//}"
        exit 1
    fi

    shift

    if [ ! "$PARTITION" ]; then
        PARTITION="$(basename "$INPUT_DIR")"
        if ! IS_VALID_PARTITION_NAME "$PARTITION"; then
            LOGE "\"$PARTITION\"은(는) 올바른 파티션 이름이 아닙니다. --partition-name을 수동으로 설정해주세요."
            exit 1
        fi
    fi

    MOUNT_POINT="$PARTITION"
    # https://android.googlesource.com/platform/build/+/refs/tags/android-15.0.0_r1/tools/releasetools/build_image.py#191
    [[ "$PARTITION" == "system" ]] && MOUNT_POINT="/"

    if [ ! "$OUTPUT_FILE" ]; then
        OUTPUT_FILE="$(dirname "$INPUT_DIR")/$PARTITION.img"
    fi

    if [ -f "$OUTPUT_FILE" ]; then
        if $FORCE; then
            rm -rf "$OUTPUT_FILE"
        else
            LOGE "출력 파일이 이미 존재합니다. (${OUTPUT_FILE//$SRC_DIR\//}) 덮어쓰려면 --force 플래그를 사용하세요."
            exit 1
        fi
    fi

    FILE_CONTEXT_FILE="$1"
    if [ ! "$FILE_CONTEXT_FILE" ]; then
        PRINT_USAGE
        exit 1
    elif [ ! -f "$FILE_CONTEXT_FILE" ]; then
        LOGE "파일이 존재하지 않습니다: ${FILE_CONTEXT_FILE//$SRC_DIR\//}"
        exit 1
    fi

    shift

    FS_CONFIG_FILE="$1"
    if [ ! "$FS_CONFIG_FILE" ]; then
        PRINT_USAGE
        exit 1
    elif [ ! -f "$FS_CONFIG_FILE" ]; then
        LOGE "파일이 존재하지 않습니다: ${FS_CONFIG_FILE//$SRC_DIR\//}"
        exit 1
    fi
}

PRINT_USAGE()
{
    echo "사용 예제: build_fs_image <fs> [옵션] <디렉토리> <file_context> <fs_config>" >&2
    echo " --avb/--no-avb       : AVB 서명을 활성화/비활성화합니다." >&2
    echo " -f, --force          : 출력 파일을 강제로 삭제하고 덮어씁니다." >&2
    echo " -i, --inodes         : (ext4 전용) extfs 아이노드 개수를 지정합니다." >&2
    echo " -m, --generate-map   : 블록 맵 파일을 생성합니다." >&2
    echo " -o, --output         : 출력 이미지 경로를 지정합니다. 기본값은 상위 입력 디렉토리입니다." >&2
    echo " -p, --partition-name : 파티션 이름을 지정합니다. 기본값은 입력 디렉토리 이름입니다." >&2
    echo " -s, --partition-size : 파티션 크기를 지정합니다. 기본값은 가능한 가장 작은 크기입니다." >&2
    echo " -S, --sparse         : 안드로이드 sparse 이미지 형식으로 출력합니다." >&2
}

# https://android.googlesource.com/platform/build/+/refs/tags/android-15.0.0_r1/tools/releasetools/common.py#334
ROUND_UP_TO_4K()
{
    local ROUNDED
    ROUNDED="$(bc -l <<< "$1 + 4095")"
    ROUNDED="$(bc -l <<< "scale=0; $ROUNDED - ($ROUNDED % 4096)")"
    echo "$ROUNDED"
}
# ]

PREPARE_SCRIPT "$@"

if $SPARSE; then
    LOG_STEP_IN "- $(basename "$OUTPUT_FILE") 작업에 대한 build_fs_image 시작 중... ($FS_TYPE+sparse)"
else
    LOG_STEP_IN "- $(basename "$OUTPUT_FILE") 작업에 대한 build_fs_image 시작 중... ($FS_TYPE)"
fi

if [ ! "$IMAGE_SIZE" ]; then
    LOG_STEP_IN "! 파티션 크기가 설정되지 않아 최소 크기를 감지합니다"

    if [[ "$FS_TYPE" == "erofs" ]]; then
        BUILD_IMAGE_MKFS
        IMAGE_SIZE="$(GET_IMAGE_SIZE "$OUTPUT_FILE")"
    else
        IMAGE_SIZE="$(GET_DISK_USAGE "$INPUT_DIR")"
    fi

    LOG "- $(basename "$OUTPUT_FILE")의 트리 크기는 $IMAGE_SIZE 바이트입니다. ($(bc -l <<< "scale=0; $IMAGE_SIZE / 1048576") MB)"

    IMAGE_SIZE="$(CALCULATE_SIZE_AND_RESERVED "$IMAGE_SIZE")"
    IMAGE_SIZE="$(ROUND_UP_TO_4K "$IMAGE_SIZE")"

    if [[ "$FS_TYPE" == "ext4" ]]; then
        if [ ! "$INODES" ]; then
            INODES="$(GET_INODE_USAGE "$INPUT_DIR")"
        fi

        LOG "- 예상치인 $IMAGE_SIZE 바이트 ($(bc -l <<< "scale=0; $IMAGE_SIZE / 1048576") MB) 및 $INODES 아이노드를 기반으로 1차 패스를 수행합니다."
        SPARSE=false BUILD_IMAGE_MKFS

        IMAGE_INFO="$(tune2fs -l "$OUTPUT_FILE")"

        rm -f "$OUTPUT_FILE"

        FREE_SIZE="$(grep -w "Free blocks" <<< "$IMAGE_INFO" | tr -d " " | cut -d ":" -f 2)"
        FREE_SIZE="$(bc -l <<< "$FREE_SIZE * 4096")"
        IMAGE_SIZE="$(bc -l <<< "$IMAGE_SIZE - $FREE_SIZE")"
        IMAGE_SIZE="$(bc -l <<< "scale=0; ($IMAGE_SIZE * 1003) / 1000")"
        [[ "$IMAGE_SIZE" -lt "262144" ]] && IMAGE_SIZE="262144"
        IMAGE_SIZE="$(ROUND_UP_TO_4K "$IMAGE_SIZE")"

        INODES="$(grep -w "Inode count" <<< "$IMAGE_INFO" | tr -d " " | cut -d ":" -f 2)"
        FREE_INODES="$(grep -w "Free inodes" <<< "$IMAGE_INFO"| tr -d " " | cut -d ":" -f 2)"
        INODES="$(bc -l <<< "$INODES - $FREE_INODES")"
        SPARE_INODES=$(bc -l <<< "scale=0; ($INODES * 2) / 100")
        [[ "$SPARE_INODES" -lt 1 ]] && SPARE_INODES=1
        INODES="$(bc -l <<< "$INODES + $SPARE_INODES")"

        LOG "- $(basename "$OUTPUT_FILE")에 대해 $INODES 아이노드를 할당합니다"
    elif [[ "$FS_TYPE" == "f2fs" ]]; then
        # f2fs는 22MB보다 작은 이미지 크기를 선호하지 않는 듯함
        [[ "$IMAGE_SIZE" -lt "23068672" ]] && IMAGE_SIZE="23068672"

        LOG "- 예상치인 $IMAGE_SIZE 바이트 ($(bc -l <<< "scale=0; $IMAGE_SIZE / 1048576") MB)를 기반으로 1차 패스를 수행합니다."
        SPARSE=false BUILD_IMAGE_MKFS

        IMAGE_INFO="$(fsck.f2fs -l "$OUTPUT_FILE")"

        rm -f "$OUTPUT_FILE"

        BLOCK_COUNT="$(grep -w "block_count" <<< "$IMAGE_INFO" | tr -d " " | cut -d ":" -f 2)"
        LOG_BLOCKSIZE="$(grep -w "log_blocksize" <<< "$IMAGE_INFO" | tr -d " " | cut -d ":" -f 2)"

        IMAGE_SIZE="$((BLOCK_COUNT << LOG_BLOCKSIZE))"
    fi

    if $AVB_SIGN; then
        IMAGE_SIZE="$(CALCULATE_AVB_MIN_PARTITION_SIZE)"
    fi

    LOG "- $(basename "$OUTPUT_FILE")에 대해 $IMAGE_SIZE 바이트 ($(bc -l <<< "scale=0; $IMAGE_SIZE / 1048576") MB)를 할당합니다."

    LOG_STEP_OUT
fi

LOG "- 이미지 빌드 중..."
if [ ! -f "$OUTPUT_FILE" ]; then
    if $AVB_SIGN; then
        IMAGE_SIZE="$(CALCULATE_AVB_MAX_IMAGE_SIZE "$IMAGE_SIZE")" BUILD_IMAGE_MKFS
    else
        BUILD_IMAGE_MKFS
    fi
fi

if $AVB_SIGN; then
    LOG "- AVB를 사용하여 이미지 서명 중..."
    EVAL "$(GET_AVBTOOL_CMD)" || exit 1
fi

LOG_STEP_OUT

exit 0
