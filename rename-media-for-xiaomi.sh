#!/bin/bash

# rename-media-for-xiaomi.sh
#
# 指定されたディレクトリ内のメディアファイル（画像・動画）を撮影日時に基づいて
# IMG/YYYY-MM-DD/ および VID/YYYY-MM-DD/ フォルダに整理・リネームします。
#
# 使用方法:
# ./rename-media-for-xiaomi.sh [対象ディレクトリ]
#
# 依存関係:
# - exiftool: ファイル名から日時が特定できない場合にEXIF情報を読み取るために必要です。
#   (Debian/Ubuntu: sudo apt-get install libimage-exiftool-perl)
#   (macOS: brew install exiftool)

# --- 設定項目 ---
# 対応する画像拡張子 (小文字)
IMG_EXTENSIONS=("jpg" "jpeg" "png" "heic" "rw2" "dng" "cr2" "nef" "orf" "arw" "gif" "bmp" "tiff" "webp")
# 対応する動画拡張子 (小文字)
VID_EXTENSIONS=("mp4" "mov" "mkv" "avi" "wmv" "flv" "webm" "3gp")
# ユーザー指定のDMG拡張子も画像として扱う
IMG_EXTENSIONS+=("dmg")


# --- 初期チェック ---

# 引数の数を確認
if [ "$#" -ne 1 ]; then
    echo "エラー: 対象のディレクトリを1つ指定してください。"
    echo "使用方法: $0 [対象ディレクトリ]"
    exit 1
fi

SOURCE_DIR="$1"

# 対象ディレクトリの存在確認
if [ ! -d "$SOURCE_DIR" ]; then
    echo "エラー: ディレクトリ '$SOURCE_DIR' が見つかりません。"
    exit 1
fi

# exiftoolの存在確認
if ! command -v exiftool &> /dev/null; then
    echo "エラー: 'exiftool' がインストールされていません。インストールしてください。"
    echo "(例: sudo apt-get install libimage-exiftool-perl または brew install exiftool)"
    exit 1
fi


# --- メイン処理 ---

echo "メディアファイルの整理を開始します..."
echo "対象ディレクトリ: $SOURCE_DIR"

# findコマンドでファイルを再帰的に検索し、whileループで1つずつ処理する
# パフォーマンスのため、パイプラインを使用
find "$SOURCE_DIR" -type f | while read -r filepath; do

    filename=$(basename "$filepath")
    extension="${filename##*.}"
    extension_lower=$(echo "$extension" | tr '[:upper:]' '[:lower:]')
    base_filename="${filename%.*}"

    # --- 1. メディアタイプの判定 ---
    media_type=""
    if [[ " ${IMG_EXTENSIONS[*]} " =~ " ${extension_lower} " ]]; then
        media_type="IMG"
    elif [[ " ${VID_EXTENSIONS[*]} " =~ " ${extension_lower} " ]]; then
        media_type="VID"
    else
        # 対象外の拡張子はスキップ
        continue
    fi

    # --- 2. 日時情報の取得 (ファイル名 -> EXIFの順) ---
    datetime_str=""
    special_string=""

    # 2a. ファイル名から日時を抽出 (例: IMG_20250601_123000.jpg)
    if [[ "$base_filename" =~ ^(IMG|VID|PANO|BURST)_([0-9]{8})_([0-9]{6}) ]]; then
        date_part="${BASH_REMATCH[2]}"
        time_part="${BASH_REMATCH[3]}"
        datetime_str="${date_part}${time_part}"

        # 特殊文字列の抽出
        # `IMG_20250601_123000` の部分を除いた残りを特殊文字列とする
        prefix_to_remove="${BASH_REMATCH[0]}"
        remaining_part="${base_filename#$prefix_to_remove}"
        if [[ -n "$remaining_part" ]]; then
            # 先頭の `_` を削除
            special_string="${remaining_part#_}"
        fi
    fi

    # 2b. ファイル名から取得できない場合、EXIF情報を参照
    if [ -z "$datetime_str" ]; then
        # パフォーマンス向上のため、exiftoolを1回だけ呼び出して必要なタグを全て取得
        exif_output=$(exiftool -q -p '$DateTimeOriginal#$CreateDate#$FileModifyDate' -d '%Y%m%d%H%M%S' "$filepath")

        # IFS(Internal Field Separator)を変更して、'#'を区切り文字として読み込む
        IFS='#' read -r dt_original cr_date f_modify_date <<< "$exif_output"

        if [[ -n "$dt_original" && "$dt_original" != "-" ]]; then
            datetime_str="$dt_original"
        elif [[ -n "$cr_date" && "$cr_date" != "-" ]]; then
            datetime_str="$cr_date"
        elif [[ -n "$f_modify_date" && "$f_modify_date" != "-" ]]; then
            datetime_str="$f_modify_date"
        else
            echo "警告: 日時情報を取得できませんでした。スキップします: $filepath"
            continue
        fi
    fi

    # --- 3. 新しいパスとファイル名の生成 ---
    year=${datetime_str:0:4}
    month=${datetime_str:4:2}
    day=${datetime_str:6:2}
    time=${datetime_str:8:6}

    date_formatted="${year}-${month}-${day}"
    datetime_formatted="${year}${month}${day}_${time}"

    target_dir="$SOURCE_DIR/$media_type/$date_formatted"

    # 新しいベースファイル名を作成
    new_base_name="${media_type}_${datetime_formatted}"
    if [ -n "$special_string" ]; then
        new_base_name="${new_base_name}_${special_string}"
    fi

    final_target_path="$target_dir/${new_base_name}.${extension}"

    # --- 4. ファイル名の衝突対応 ---
    counter=1
    while [ -e "$final_target_path" ]; do
        # 既に同じパスのファイルが存在する場合
        if [ "$final_target_path" == "$filepath" ]; then
            # 移動元と移動先が完全に同一。処理済みとみなしループを抜ける
            echo "情報: 既に整理されています: $filepath"
            final_target_path="" # 空に設定して移動をスキップ
            break
        fi

        # 連番を付与して新しいファイル名を試す
        final_target_path="$target_dir/${new_base_name}_${counter}.${extension}"
        ((counter++))
    done

    # --- 5. ファイルの移動 ---
    if [ -n "$final_target_path" ]; then
        # 移動先ディレクトリがなければ作成
        mkdir -p "$target_dir"

        # ファイルを移動
        mv -v "$filepath" "$final_target_path"
    fi

done

echo "すべての処理が完了しました。"
