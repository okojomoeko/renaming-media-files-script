#!/bin/bash

# スクリプト名 (エラーメッセージ表示用)
SCRIPT_NAME=$(basename "$0")

# 使用法を表示する関数
usage() {
    echo "使用法: $SCRIPT_NAME <親ディレクトリパス> <開始日 yyyy-mm-dd> <終了日 yyyy-mm-dd>" >&2
    echo "例1 (相対パス): $SCRIPT_NAME ./MyDateFolders 2025-05-04 2025-06-05" >&2
    echo "例2 (絶対パス): $SCRIPT_NAME /tmp/MyDateFolders 2025-05-04 2025-06-05" >&2
    exit 1
}

# --- 引数のチェック ---
if [ "$#" -ne 3 ]; then
    echo "エラー: 引数の数が正しくありません。3つの引数が必要です。" >&2
    usage
fi

TARGET_PARENT_DIR_INPUT="$1"
START_DATE_STR="$2"
END_DATE_STR="$3"

# --- 親ディレクトリのパス解決 ---
# スクリプトが置かれているディレクトリの絶対パスを取得
# (シンボリックリンクの場合も正しく解決する)
SOURCE_FILE=${BASH_SOURCE[0]}
while [ -L "$SOURCE_FILE" ]; do
  SCRIPT_DIR_PATH=$( cd -P "$( dirname "$SOURCE_FILE" )" >/dev/null 2>&1 && pwd )
  SOURCE_FILE=$(readlink "$SOURCE_FILE")
  [[ $SOURCE_FILE != /* ]] && SOURCE_FILE="$SCRIPT_DIR_PATH/$SOURCE_FILE"
done
SCRIPT_DIR_PATH=$( cd -P "$( dirname "$SOURCE_FILE" )" >/dev/null 2>&1 && pwd )

# 指定された親ディレクトリパスを解決
if [[ "$TARGET_PARENT_DIR_INPUT" == /* ]]; then
    # 絶対パスの場合
    TARGET_PARENT_DIR="$TARGET_PARENT_DIR_INPUT"
else
    # 相対パスの場合、スクリプトのディレクトリを基準に結合
    TARGET_PARENT_DIR="$SCRIPT_DIR_PATH/$TARGET_PARENT_DIR_INPUT"
fi

# (オプション) 結合後のパスをよりクリーンにする (例: /path/./sub -> /path/sub)
# realpath があれば使うのが簡単。なければ、cdとpwdの組み合わせか、このまま進める。
# 通常、mkdir や test -d はこのようなパスを正しく解釈します。
# if command -v realpath >/dev/null 2>&1; then
#   TARGET_PARENT_DIR=$(realpath -m "$TARGET_PARENT_DIR")
# fi


# 親ディレクトリの存在チェック
if [ ! -d "$TARGET_PARENT_DIR" ]; then
    echo "エラー: 指定された親ディレクトリ '$TARGET_PARENT_DIR' が存在しません。" >&2
    if [[ "$TARGET_PARENT_DIR_INPUT" != /* ]]; then # 元の入力が相対パスだった場合
        echo "(入力値: '$TARGET_PARENT_DIR_INPUT' をスクリプトの場所 '$SCRIPT_DIR_PATH' からの相対パスとして解釈しようとしました)" >&2
    fi
    echo "先に親ディレクトリを作成してください。" >&2
    exit 1
fi

# --- 日付形式のバリデーション (簡易) ---
# yyyy-mm-dd 形式であること、および月と日が妥当な範囲か（大まかに）
if ! [[ "$START_DATE_STR" =~ ^[0-9]{4}-(0[1-9]|1[0-2])-(0[1-9]|[12][0-9]|3[01])$ ]] || \
   ! [[ "$END_DATE_STR" =~ ^[0-9]{4}-(0[1-9]|1[0-2])-(0[1-9]|[12][0-9]|3[01])$ ]]; then
    echo "エラー: 日付の形式が 'yyyy-mm-dd' ではないか、日付の範囲が不正です。" >&2
    usage
fi

# --- dateコマンドの選定 (GNU date vs BSD date) ---
# macOS の date は GNU date と互換性がないため、gdate (coreutils) を試みる
DATE_CMD="date"
if [[ "$(uname)" == "Darwin" ]]; then # macOSの場合
    if command -v gdate >/dev/null 2>&1; then
        DATE_CMD="gdate"
        echo "情報: macOS環境のため、'gdate' コマンドを使用します。"
    else
        echo "エラー: macOS環境では 'gdate' が必要です。" >&2
        echo "Homebrewを使用している場合: 'brew install coreutils' でインストールしてください。" >&2
        exit 1
    fi
fi

# --- 日付の妥当性チェックとUnixタイムスタンプへの変換 ---
# $DATE_CMD -d で日付文字列を解釈させ、失敗したらエラー
if ! START_SECONDS=$($DATE_CMD -d "$START_DATE_STR" +%s 2>/dev/null); then
    echo "エラー: 開始日 '$START_DATE_STR' を日付として解釈できません。有効な日付を入力してください。" >&2
    usage
fi
if ! END_SECONDS=$($DATE_CMD -d "$END_DATE_STR" +%s 2>/dev/null); then
    echo "エラー: 終了日 '$END_DATE_STR' を日付として解釈できません。有効な日付を入力してください。" >&2
    usage
fi

# 開始日と終了日の順序チェック
if [ "$START_SECONDS" -gt "$END_SECONDS" ]; then
    echo "エラー: 開始日が終了日よりも後の日付になっています。" >&2
    exit 1
fi

echo "ディレクトリの作成を開始します (対象の親ディレクトリ: '$TARGET_PARENT_DIR')"

# --- ディレクトリ作成ループ ---
CURRENT_SECONDS="$START_SECONDS"
ONE_DAY_SECONDS=86400 # 1日の秒数 (24 * 60 * 60)

while [ "$CURRENT_SECONDS" -le "$END_SECONDS" ]; do
    # Unixタイムスタンプから yyyy-mm-dd 形式の日付文字列を生成
    DIR_NAME=$($DATE_CMD -d "@$CURRENT_SECONDS" +"%Y-%m-%d")
    FULL_PATH_TO_CREATE="$TARGET_PARENT_DIR/$DIR_NAME"

    if [ ! -d "$FULL_PATH_TO_CREATE" ]; then
        mkdir "$FULL_PATH_TO_CREATE"
        if [ $? -eq 0 ]; then # 直前のコマンドの終了ステータスを確認
            echo "ディレクトリ '$FULL_PATH_TO_CREATE' を作成しました。"
        else
            echo "エラー: ディレクトリ '$FULL_PATH_TO_CREATE' の作成に失敗しました。" >&2
            # エラー発生時に処理を停止する場合は以下のコメントを解除
            # exit 1
        fi
    else
        echo "警告: ディレクトリ '$FULL_PATH_TO_CREATE' は既に存在します。"
    fi

    # 次の日へ進む
    CURRENT_SECONDS=$((CURRENT_SECONDS + ONE_DAY_SECONDS))
done

echo "ディレクトリの作成が完了しました。"
