#!/usr/bin/env bash

# {{{ 
# モジュール配置スクリプト
# =======================
#
# ■ このスクリプトについて
# -----------------------
#
# xoops_modules/ 以下にモジュールのリポジトリを git clone しておき 
# 作業をしたあとこのスクリプトで legacy 内に配置する
#
# ■ 使い方
# -----------------------
#   sh ./deploy.sh
#
# ■ 作業フロー
# -----------------------
#
# 1. モジュールのリポジトリ保存ディレクトリに移動
#    cd /Users/web/htdocs/xoops_modules/
#
# 2. モジュールを git clone （していなければ）
#    git clone git://github.com/XoopsX/xupdate.git
#
# 3. モジュールのリポジトリに移動
#    cd xupdate
#
# 4. 作業用ブランチを作成/チェックアウト
#    git checkout -b pgsql
#
#    既に作業用ブランチを作成済みなら
#
#    git checkout pgsql
#
# 5. ソースコードをいじる
#    vi hogehoge.php
#
# 6. このスクリプトを呼び出す
#    sh ../deploy.sh
#
# 7. ブラウザで確認
#
#    問題がなければ 7 へ、
#    まだまだ続きがあれば 5 へ
#
# 8. コミット
#    git add xxxxx
#    git commit
#    git push pgsql origin
#
# 9. github の画面で pull request する
#
# ■ 想定ディレクトリ構成
# -----------------------
#
# /Users/web/htdocs/  <== http://localhost/ でアクセスする場所
#   |
#   +- xoops_modules/ <== 各モジュールのリポジトリを保存
#   |   |
#   |   +- deploy.sh  <== このスクリプトファイル
#   |   |
#   |   +- xupdate/
#   |   |
#   |   +- altsys/
#   |   |
#   |   +- protector/
#   |   |
#   |   +- pico/
#   |   |
#   |   +- その他
#   |
#   +- legacy/        <== legacy リポジトリ
#       |
#       +- html/
#       |   |
#       |   +- common/
#       |   |
#       |   +- modules/
#       |
#       +- xoops_trust_path/
#
# }}}

# このスクリプトのある一つ上のディレクトリの絶対パス
CURRENT_DIR=$(cd $(dirname $0);pwd)
WORK_DIR=$(cd $(dirname $(cd $(dirname $0);pwd));pwd)
# rsync コマンドパス
RSYNC=/usr/bin/rsync
# rsync のオプション
RSYNC_OPT="-av"
# 転送先ディレクトリ（複数ある場合はスペース区切りで指定）
LEGACY_REPOS="$WORK_DIR/legacy $WORK_DIR/legacy-mysql"
# ログファイル(deploy.YYYYMMDD-HHMM.log)
LOGDIR=$CURRENT_DIR/log
LOGFILE=$(basename $0 .sh).$(/bin/date +%Y%m%d)-$(/bin/date +%H%M).log
LOG=$LOGDIR/$LOGFILE

# ログディレクトリ作成
if [ ! -d $CURRENT_DIR/log ]; then
    mkdir $CURRENT_DIR/log
    if [ $? -ne 0 ]; then
        echo "Cannot mkdir $CURRENT_DIR/log"
        exit 1;
    fi
fi
touch $LOG

# モジュールのリポジトリをみつける
cd $CURRENT_DIR
find . -type d -maxdepth 1 -print | while read MOD_DIRNAME
do
    MODDIRNAME=$(basename $MOD_DIRNAME)
    # ./ ../ .git/ log/ はスキップ
    if [ "$MODDIRNAME" = "." -o "$MODDIRNAME" = ".." -o "$MODDIRNAME" = ".git" -o "$MODDIRNAME" = "log" ]; then
        continue;
    fi

    # モジュールリポジトリに入る
    cd $MODDIRNAME

    # リポジトリ内のディレクトリを rsync する
    find . -type d -maxdepth 1 -print | while read TARGET_DIR
    do
        TARGETDIR=$(basename $TARGET_DIR)
        # ./ ../ .git/ はスキップ
        if [ "$TARGETDIR" = "." -o "$TARGETDIR" = ".." -o "$TARGETDIR" = ".git" ]; then
            continue;
        fi

        SRC=$CURRENT_DIR/$MODDIRNAME/$TARGETDIR/

        for LEGACY_REPO in $LEGACY_REPOS; do
            DST=$LEGACY_REPO/$TARGETDIR/
            echo "$RSYNC $RSYNC_OPT $SRC $DST" >> $LOG
            $RSYNC $RSYNC_OPT $SRC $DST >> $LOG 2>&1
        done
    done
done

exit 0
