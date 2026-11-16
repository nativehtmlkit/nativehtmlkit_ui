#!/usr/bin/env bash
# Enable/restore fcitx5 (Pinyin) as KWin's Wayland input method for the desktop user (linuxDEV).
#   linux-ime.sh on STATE_DIR | off STATE_DIR
# "on" snapshots the current KWin/fcitx5 settings into STATE_DIR first; "off" restores them.
# Same mechanism as the Project's native-journeys lab-settings.sh (ime-on/ime-off).
set -uo pipefail
. ~/lab/bin/gui-env; unset DISPLAY
mode=$1; ST=$(mkdir -p "$2" && cd "$2" && pwd)
F=$HOME/.config/fcitx5
case $mode in
on)
  if [[ ! -f $ST/before.env ]]; then
    { echo "IM=$(kreadconfig6 --file kwinrc --group Wayland --key InputMethod)"
      echo "VK=$(busctl --user get-property org.kde.KWin /VirtualKeyboard org.kde.kwin.VirtualKeyboard enabled | awk '{print $2}')"; } > "$ST/before.env"
    [[ -d $F ]] && cp -a "$F" "$ST/fcitx5.before"
  fi
  mkdir -p "$F/conf"
  printf '[Groups/0]\nName=Default\nDefault Layout=us\nDefaultIM=pinyin\n\n[Groups/0/Items/0]\nName=keyboard-us\nLayout=\n\n[Groups/0/Items/1]\nName=pinyin\nLayout=\n\n[GroupOrder]\n0=Default\n' > "$F/profile"
  printf 'CloudPinyinEnabled=False\nPredictionEnabled=False\nPageSize=5\n' > "$F/conf/pinyin.conf"
  printf '[Behavior]\nShareInputState=No\nPreeditEnabledByDefault=True\nShowPreeditForPassword=False\n' > "$F/config"
  busctl --user set-property org.kde.KWin /VirtualKeyboard org.kde.kwin.VirtualKeyboard enabled b true
  kwriteconfig6 --notify --file kwinrc --group Wayland --key InputMethod --delete; sleep 1
  kwriteconfig6 --notify --file kwinrc --group Wayland --key InputMethod /usr/share/applications/org.fcitx.Fcitx5.desktop
  for _ in $(seq 1 40); do pgrep -u "$(id -u)" -x fcitx5 >/dev/null && break; sleep 0.25; done
  sleep 2; pgrep -u "$(id -u)" -x fcitx5 >/dev/null && echo "fcitx5 running" || { echo "fcitx5 did not start" >&2; exit 1; } ;;
off)
  [[ -f $ST/before.env ]] || { echo "no snapshot"; exit 0; }
  . "$ST/before.env"
  if [[ -n $IM ]]; then kwriteconfig6 --notify --file kwinrc --group Wayland --key InputMethod "$IM"
  else kwriteconfig6 --notify --file kwinrc --group Wayland --key InputMethod --delete; fi
  [[ $VK == true || $VK == false ]] && busctl --user set-property org.kde.KWin /VirtualKeyboard org.kde.kwin.VirtualKeyboard enabled b "$VK"
  sleep 2; pkill -u "$(id -u)" -x fcitx5 2>/dev/null; sleep 0.5
  rm -rf "$F"; [[ -d $ST/fcitx5.before ]] && cp -a "$ST/fcitx5.before" "$F"
  rm -rf "$HOME/.local/share/fcitx5"
  echo "input method restored (IM='$IM' VK=$VK)" ;;
esac
