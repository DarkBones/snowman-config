{ lib, pkgs, ... }:
{
  config = lib.mkIf pkgs.stdenv.isDarwin {

    home.activation.macosDefaults = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      echo "Applying macOS defaults"

      # Dock behavior
      /usr/bin/defaults write com.apple.dock autohide -bool true
      /usr/bin/defaults write com.apple.dock launchanim -bool false
      /usr/bin/defaults write com.apple.dock mineffect -string scale
      /usr/bin/defaults write com.apple.dock show-process-indicators -bool true
      /usr/bin/defaults write com.apple.dock show-recents -bool false
      /usr/bin/defaults write com.apple.dock tilesize -int 37

      # Finder
      /usr/bin/defaults write com.apple.finder FXArrangeGroupViewBy -string "Name"
      /usr/bin/defaults write com.apple.finder FXDefaultSearchScope -string "SCcf"
      /usr/bin/defaults write com.apple.finder FXEnableExtensionChangeWarning -bool false
      /usr/bin/defaults write com.apple.finder FXPreferredViewStyle -string "Nlsv"
      /usr/bin/defaults write com.apple.finder FXRemoveOldTrashItems -bool true
      /usr/bin/defaults write com.apple.finder NewWindowTarget -string "PfAF"
      /usr/bin/defaults write com.apple.finder WarnOnEmptyTrash -bool false
      /usr/bin/defaults write com.apple.finder _FXSortFoldersFirst -bool true

      # Symbolic hotkeys
      plist="$HOME/Library/Preferences/com.apple.symbolichotkeys.plist"
      /usr/bin/defaults read com.apple.symbolichotkeys >/dev/null 2>&1 || /usr/bin/defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict
      /usr/libexec/PlistBuddy -c "Delete :AppleSymbolicHotKeys" "$plist" 2>/dev/null || true
      /usr/libexec/PlistBuddy -c "Add :AppleSymbolicHotKeys dict" "$plist"

      # 33
      /usr/libexec/PlistBuddy -c "Add :AppleSymbolicHotKeys:33 dict" "$plist"
      /usr/libexec/PlistBuddy -c "Add :AppleSymbolicHotKeys:33:enabled bool false" "$plist"
      /usr/libexec/PlistBuddy -c "Add :AppleSymbolicHotKeys:33:value dict" "$plist"
      /usr/libexec/PlistBuddy -c "Add :AppleSymbolicHotKeys:33:value:type string standard" "$plist"
      /usr/libexec/PlistBuddy -c "Add :AppleSymbolicHotKeys:33:value:parameters array" "$plist"
      /usr/libexec/PlistBuddy -c "Add :AppleSymbolicHotKeys:33:value:parameters:0 integer 65535" "$plist"
      /usr/libexec/PlistBuddy -c "Add :AppleSymbolicHotKeys:33:value:parameters:1 integer 125" "$plist"
      /usr/libexec/PlistBuddy -c "Add :AppleSymbolicHotKeys:33:value:parameters:2 integer 8650752" "$plist"

      # 36
      /usr/libexec/PlistBuddy -c "Add :AppleSymbolicHotKeys:36 dict" "$plist"
      /usr/libexec/PlistBuddy -c "Add :AppleSymbolicHotKeys:36:enabled bool false" "$plist"
      /usr/libexec/PlistBuddy -c "Add :AppleSymbolicHotKeys:36:value dict" "$plist"
      /usr/libexec/PlistBuddy -c "Add :AppleSymbolicHotKeys:36:value:type string standard" "$plist"
      /usr/libexec/PlistBuddy -c "Add :AppleSymbolicHotKeys:36:value:parameters array" "$plist"
      /usr/libexec/PlistBuddy -c "Add :AppleSymbolicHotKeys:36:value:parameters:0 integer 65535" "$plist"
      /usr/libexec/PlistBuddy -c "Add :AppleSymbolicHotKeys:36:value:parameters:1 integer 103" "$plist"
      /usr/libexec/PlistBuddy -c "Add :AppleSymbolicHotKeys:36:value:parameters:2 integer 8388608" "$plist"

      # 52
      /usr/libexec/PlistBuddy -c "Add :AppleSymbolicHotKeys:52 dict" "$plist"
      /usr/libexec/PlistBuddy -c "Add :AppleSymbolicHotKeys:52:enabled bool false" "$plist"
      /usr/libexec/PlistBuddy -c "Add :AppleSymbolicHotKeys:52:value dict" "$plist"
      /usr/libexec/PlistBuddy -c "Add :AppleSymbolicHotKeys:52:value:type string standard" "$plist"
      /usr/libexec/PlistBuddy -c "Add :AppleSymbolicHotKeys:52:value:parameters array" "$plist"
      /usr/libexec/PlistBuddy -c "Add :AppleSymbolicHotKeys:52:value:parameters:0 integer 100" "$plist"
      /usr/libexec/PlistBuddy -c "Add :AppleSymbolicHotKeys:52:value:parameters:1 integer 2" "$plist"
      /usr/libexec/PlistBuddy -c "Add :AppleSymbolicHotKeys:52:value:parameters:2 integer 1572864" "$plist"

      # 79
      /usr/libexec/PlistBuddy -c "Add :AppleSymbolicHotKeys:79 dict" "$plist"
      /usr/libexec/PlistBuddy -c "Add :AppleSymbolicHotKeys:79:enabled bool false" "$plist"
      /usr/libexec/PlistBuddy -c "Add :AppleSymbolicHotKeys:79:value dict" "$plist"
      /usr/libexec/PlistBuddy -c "Add :AppleSymbolicHotKeys:79:value:type string standard" "$plist"
      /usr/libexec/PlistBuddy -c "Add :AppleSymbolicHotKeys:79:value:parameters array" "$plist"
      /usr/libexec/PlistBuddy -c "Add :AppleSymbolicHotKeys:79:value:parameters:0 integer 65535" "$plist"
      /usr/libexec/PlistBuddy -c "Add :AppleSymbolicHotKeys:79:value:parameters:1 integer 123" "$plist"
      /usr/libexec/PlistBuddy -c "Add :AppleSymbolicHotKeys:79:value:parameters:2 integer 8650752" "$plist"

      # 80
      /usr/libexec/PlistBuddy -c "Add :AppleSymbolicHotKeys:80 dict" "$plist"
      /usr/libexec/PlistBuddy -c "Add :AppleSymbolicHotKeys:80:enabled bool true" "$plist"
      /usr/libexec/PlistBuddy -c "Add :AppleSymbolicHotKeys:80:value dict" "$plist"
      /usr/libexec/PlistBuddy -c "Add :AppleSymbolicHotKeys:80:value:type string standard" "$plist"
      /usr/libexec/PlistBuddy -c "Add :AppleSymbolicHotKeys:80:value:parameters array" "$plist"
      /usr/libexec/PlistBuddy -c "Add :AppleSymbolicHotKeys:80:value:parameters:0 integer 65535" "$plist"
      /usr/libexec/PlistBuddy -c "Add :AppleSymbolicHotKeys:80:value:parameters:1 integer 123" "$plist"
      /usr/libexec/PlistBuddy -c "Add :AppleSymbolicHotKeys:80:value:parameters:2 integer 8781824" "$plist"

      # 81
      /usr/libexec/PlistBuddy -c "Add :AppleSymbolicHotKeys:81 dict" "$plist"
      /usr/libexec/PlistBuddy -c "Add :AppleSymbolicHotKeys:81:enabled bool false" "$plist"
      /usr/libexec/PlistBuddy -c "Add :AppleSymbolicHotKeys:81:value dict" "$plist"
      /usr/libexec/PlistBuddy -c "Add :AppleSymbolicHotKeys:81:value:type string standard" "$plist"
      /usr/libexec/PlistBuddy -c "Add :AppleSymbolicHotKeys:81:value:parameters array" "$plist"
      /usr/libexec/PlistBuddy -c "Add :AppleSymbolicHotKeys:81:value:parameters:0 integer 65535" "$plist"
      /usr/libexec/PlistBuddy -c "Add :AppleSymbolicHotKeys:81:value:parameters:1 integer 124" "$plist"
      /usr/libexec/PlistBuddy -c "Add :AppleSymbolicHotKeys:81:value:parameters:2 integer 8650752" "$plist"

      # 82
      /usr/libexec/PlistBuddy -c "Add :AppleSymbolicHotKeys:82 dict" "$plist"
      /usr/libexec/PlistBuddy -c "Add :AppleSymbolicHotKeys:82:enabled bool true" "$plist"
      /usr/libexec/PlistBuddy -c "Add :AppleSymbolicHotKeys:82:value dict" "$plist"
      /usr/libexec/PlistBuddy -c "Add :AppleSymbolicHotKeys:82:value:type string standard" "$plist"
      /usr/libexec/PlistBuddy -c "Add :AppleSymbolicHotKeys:82:value:parameters array" "$plist"
      /usr/libexec/PlistBuddy -c "Add :AppleSymbolicHotKeys:82:value:parameters:0 integer 65535" "$plist"
      /usr/libexec/PlistBuddy -c "Add :AppleSymbolicHotKeys:82:value:parameters:1 integer 124" "$plist"
      /usr/libexec/PlistBuddy -c "Add :AppleSymbolicHotKeys:82:value:parameters:2 integer 8781824" "$plist"

      # 118-122
      for spec in \
        "118 49 18 524288" \
        "119 50 19 524288" \
        "120 51 20 524288" \
        "121 52 21 524288" \
        "122 53 23 524288"
      do
        set -- $spec
        key="$1"; p0="$2"; p1="$3"; p2="$4"
        /usr/libexec/PlistBuddy -c "Add :AppleSymbolicHotKeys:$key dict" "$plist"
        /usr/libexec/PlistBuddy -c "Add :AppleSymbolicHotKeys:$key:enabled bool true" "$plist"
        /usr/libexec/PlistBuddy -c "Add :AppleSymbolicHotKeys:$key:value dict" "$plist"
        /usr/libexec/PlistBuddy -c "Add :AppleSymbolicHotKeys:$key:value:type string standard" "$plist"
        /usr/libexec/PlistBuddy -c "Add :AppleSymbolicHotKeys:$key:value:parameters array" "$plist"
        /usr/libexec/PlistBuddy -c "Add :AppleSymbolicHotKeys:$key:value:parameters:0 integer $p0" "$plist"
        /usr/libexec/PlistBuddy -c "Add :AppleSymbolicHotKeys:$key:value:parameters:1 integer $p1" "$plist"
        /usr/libexec/PlistBuddy -c "Add :AppleSymbolicHotKeys:$key:value:parameters:2 integer $p2" "$plist"
      done

      # Other disabled entries written by the UI
      for spec in \
        "190 113 12 8388608" \
        "222 65535 65535 0" \
        "233 109 46 1048576" \
        "235 65535 65535 0" \
        "237 102 3 8650752" \
        "238 99 8 8650752" \
        "239 114 15 8650752" \
        "240 65535 123 8650752" \
        "241 65535 124 8650752" \
        "242 65535 126 8650752" \
        "243 65535 125 8650752" \
        "244 65535 65535 0" \
        "245 65535 65535 0" \
        "246 65535 65535 0" \
        "247 65535 65535 0" \
        "248 65535 123 8781824" \
        "249 65535 124 8781824" \
        "250 65535 126 8781824" \
        "251 65535 125 8781824" \
        "256 65535 65535 0" \
        "257 65535 65535 0" \
        "258 65535 65535 0" \
        "260 65535 53 1048576"
      do
        set -- $spec
        key="$1"; p0="$2"; p1="$3"; p2="$4"
        /usr/libexec/PlistBuddy -c "Add :AppleSymbolicHotKeys:$key dict" "$plist"
        /usr/libexec/PlistBuddy -c "Add :AppleSymbolicHotKeys:$key:enabled bool false" "$plist"
        /usr/libexec/PlistBuddy -c "Add :AppleSymbolicHotKeys:$key:value dict" "$plist"
        /usr/libexec/PlistBuddy -c "Add :AppleSymbolicHotKeys:$key:value:type string standard" "$plist"
        /usr/libexec/PlistBuddy -c "Add :AppleSymbolicHotKeys:$key:value:parameters array" "$plist"
        /usr/libexec/PlistBuddy -c "Add :AppleSymbolicHotKeys:$key:value:parameters:0 integer $p0" "$plist"
        /usr/libexec/PlistBuddy -c "Add :AppleSymbolicHotKeys:$key:value:parameters:1 integer $p1" "$plist"
        /usr/libexec/PlistBuddy -c "Add :AppleSymbolicHotKeys:$key:value:parameters:2 integer $p2" "$plist"
      done

      /usr/bin/killall cfprefsd || true
      /usr/bin/killall Dock || true
      /usr/bin/killall Finder || true
      /System/Library/CoreServices/SystemUIServer.app/Contents/MacOS/SystemUIServer >/dev/null 2>&1 &
    '';
  };
}
