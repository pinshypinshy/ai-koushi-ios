#!/usr/bin/env bash
# 使い方：
#   worktree.sh create <名前> [元のブランチ]
#   worktree.sh candidates
#   worktree.sh link <新しいフォルダ> <パス>...
set -euo pipefail

die() { echo "error: $*" >&2; exit 1; }

# worktree の中で実行しても、元のフォルダを基準にする
common_dir=$(git rev-parse --path-format=absolute --git-common-dir) || die "git リポジトリの中で実行してください"
root=$(dirname "$common_dir")

default_branch() {
    local ref
    if ref=$(git -C "$root" symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null); then
        echo "${ref#origin/}"
        return
    fi
    for b in main master; do
        if git -C "$root" show-ref --verify --quiet "refs/heads/$b"; then
            echo "$b"
            return
        fi
    done
    die "既定のブランチが分かりません。元のブランチを指定してください"
}

cmd_create() {
    local name=${1:-} base=${2:-}
    [[ $name =~ ^[a-z0-9][a-z0-9-]*$ ]] || die "名前は英小文字・数字・ハイフンにしてください：'$name'"
    [[ -n $base ]] || base=$(default_branch)
    local branch="feature/$name"
    local dest
    dest="$(dirname "$root")/$(basename "$root")-$name"

    [[ ! -e $dest ]] || die "フォルダが既にあります：$dest"
    ! git -C "$root" show-ref --verify --quiet "refs/heads/$branch" || die "ブランチが既にあります：$branch"

    git -C "$root" worktree add -b "$branch" "$dest" "$base" >&2
    echo "$dest"
}

is_artifact() {
    local path=${1%/} part
    local IFS=/
    for part in $path; do
        case $part in
            DerivedData | build | .build | .swiftpm | xcuserdata | node_modules | .DS_Store | *.xcuserstate | *.xcresult)
                return 0 ;;
        esac
    done
    return 1
}

cmd_candidates() {
    local entry
    while IFS= read -r -d '' entry; do
        [[ $entry == '!! '* ]] || continue
        entry=${entry#'!! '}
        is_artifact "$entry" || echo "$entry"
    done < <(git -C "$root" status --ignored --porcelain -z)
}

linked=()

link_file() {
    local src=$1 dest=$2 rel=${1#"$root"/}
    local target="$dest/$rel"
    if [[ -L $target && $(readlink "$target") == "$src" ]]; then
        echo "skip: $rel" >&2
        linked+=("$rel")
        return
    fi
    [[ ! -e $target && ! -L $target ]] || die "既にファイルがあります：$target"
    mkdir -p "$(dirname "$target")"
    ln -s "$src" "$target"
    echo "link: $rel" >&2
    linked+=("$rel")
}

cmd_link() {
    local dest=${1:-}
    [[ -d $dest ]] || die "新しいフォルダがありません：'$dest'"
    dest=$(cd "$dest" && pwd)
    shift
    [[ $# -gt 0 ]] || die "リンクするパスを指定してください"

    local p src f
    for p in "$@"; do
        src="$root/${p%/}"
        if [[ -d $src && ! -L $src ]]; then
            while IFS= read -r -d '' f; do
                link_file "$f" "$dest"
            done < <(find "$src" \( -type f -o -type l \) -print0)
        elif [[ -e $src || -L $src ]]; then
            link_file "$src" "$dest"
        else
            die "元のフォルダにありません：$p"
        fi
    done

    # 除外されていないリンクは、そのままだとコミットされうる
    local untracked=() entry rel bad=()
    while IFS= read -r -d '' entry; do
        [[ $entry == '?? '* ]] && untracked+=("${entry#'?? '}")
    done < <(git -C "$dest" status --porcelain -z --untracked-files=all)
    for rel in ${linked[@]+"${linked[@]}"}; do
        for entry in ${untracked[@]+"${untracked[@]}"}; do
            [[ $entry == "$rel" ]] && bad+=("$rel")
        done
    done
    if [[ ${#bad[@]} -gt 0 ]]; then
        echo "error: 次のリンクは git に除外されていません：" >&2
        printf '  %s\n' "${bad[@]}" >&2
        exit 1
    fi
    echo "ok: ${#linked[@]} 件のリンクは、すべて git に除外されています" >&2
}

case ${1:-} in
    create) shift; cmd_create "$@" ;;
    candidates) shift; cmd_candidates "$@" ;;
    link) shift; cmd_link "$@" ;;
    *) die "使い方：worktree.sh create <名前> [元のブランチ] | candidates | link <新しいフォルダ> <パス>..." ;;
esac
