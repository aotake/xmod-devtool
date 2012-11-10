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
#   sh ./deploy.sh [legacy リポジトリのパス]
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
# 転送しないモジュール（カンマ区切り）
IGNORE_MODULES=
# リポジトリ、モジュールの確認をしないですぐに処理する場合 yes
ANSWER=no
# ログファイル(deploy.YYYYMMDD-HHMM.log)
LOGDIR=$CURRENT_DIR/log
LOGFILE=$(basename $0 .sh).$(/bin/date +%Y%m%d)-$(/bin/date +%H%M).log
LOG=$LOGDIR/$LOGFILE

function usage_exit() {
    echo ""
    echo "Usage: /bin/sh $0 [-r path1:path2:...] [-i mod1,mod2,...]"
    echo ""
    echo "  e.g.) /bin/sh $0"
    echo "  e.g.) /bin/sh $0 -r ../legacy"
    echo "  e.g.) /bin/sh $0 -r ../legacy:../legacy-mysql"
    echo "  e.g.) /bin/sh $0 -r ../legacy -i xupdate"
    echo "  e.g.) /bin/sh $0 -r ../legacy -i xupdate,pico"
    echo "  e.g.) /bin/sh $0 -y -r ../legacy -i xupdate,pico"
    echo ""
    exit 1
}
function isIgnoreModule() {
    CHECK_MODNAME=$1
    IGNORE_FLAG=0
    for check in $IGNORE_MODULES; do
        if [ "$check" = "$CHECK_MODNAME" ]; then
            IGNORE_FLAG=1
            break;
        fi
    done
    return $IGNORE_FLAG;
}


# 引数があれば処理する
if [ $# -gt 0 ]; then
    while getopts "r:i:hy" flag; do
        case $flag in
            r) LEGACY_REPOS=""
                for r in $(echo $OPTARG| sed "s/:/ /g"); do
                    ADD_REPO=$(cd $r; pwd)
                    if [ "$LEGACY_REPOS" = "" ]; then
                        LEGACY_REPOS="$ADD_REPO"
                    else
                        LEGACY_REPOS="$LEGACY_REPOS $ADD_REPO"
                    fi
                done
                ;;
            i) IGNORE_MODULES=$(echo $OPTARG| sed "s/,/ /g") ;;
            y) ANSWER=yes ;;
            h) usage_exit ;;
            *) usage_exit ;;
        esac
    done
fi

echo "REP=$LEGACY_REPOS"
echo "IGNORE=$IGNORE_MODULES"

if [ $# -gt 0 -a "$ANSWER" != "yes" ]; then
    /bin/echo -n "Continue? [y/N]: "
    read answer
    if [ "$answer" != "y" -a "$answer" != "Y" ]; then
        echo "...cancel."
        exit 1
    fi
fi

# rsync があるか確認
if [ ! -x $RSYNC ]; then
    echo "ERROR: not found rsync command: $RSYNC"
    exit 1;
fi

# ログディレクトリ作成
if [ ! -d $CURRENT_DIR/log ]; then
    mkdir $CURRENT_DIR/log
    if [ $? -ne 0 ]; then
        echo "ERROR: Cannot mkdir $CURRENT_DIR/log"
        exit 1;
    fi
fi
touch $LOG

# モジュールのリポジトリをみつける
cd $CURRENT_DIR
find . -maxdepth 1 -type d -print | while read MOD_DIRNAME
do
    MODDIRNAME=$(basename $MOD_DIRNAME)
    # ./ ../ .git/ log/ はスキップ
    if [ "$MODDIRNAME" = "." -o "$MODDIRNAME" = ".." -o "$MODDIRNAME" = ".git" -o "$MODDIRNAME" = "log" ]; then
        continue;
    fi

    isIgnoreModule $MODDIRNAME
    if [ $? = 1 ]; then
        echo "----> ignore: $MODDIRNAME"
        continue;
    fi

    # モジュールリポジトリに入る
    if [ ! -d $MODDIRNAME ]; then
        echo "ERROR: $MODDIRNAME is not found"
        echo "CURRENT: "$(pwd)
        exit 1
    fi
    pushd $MODDIRNAME > /dev/null

    # リポジトリ内のディレクトリを rsync する
    find . -maxdepth 1 -type d -print | while read TARGET_DIR
    do
        TARGETDIR=$(basename $TARGET_DIR)
        # ./ ../ .git/ はスキップ
        if [ "$TARGETDIR" = "." -o "$TARGETDIR" = ".." -o "$TARGETDIR" = ".git" ]; then
            continue;
        fi

        SRC=$CURRENT_DIR/$MODDIRNAME/$TARGETDIR/

        for LEGACY_REPO in $LEGACY_REPOS; do
            DST=$LEGACY_REPO/$TARGETDIR/
            echo "$RSYNC $RSYNC_OPT $SRC $DST"
            echo "$RSYNC $RSYNC_OPT $SRC $DST" >> $LOG
            $RSYNC $RSYNC_OPT $SRC $DST >> $LOG 2>&1
        done
    done
    popd > /dev/null
done

exit 0
