#!/usr/bin/env sh

# Change ADB Shell Arguments Based on Selection
debloat () {
case "$1" in
    Enable)
        adb shell pm enable "$2" 2> /dev/null ||
        echo "Failed to Enable: $2";;
    Disable)
        adb shell pm disable-user -k "$2" 2> /dev/null ||
        echo "Failed to Disable: $2";;
esac
}

# GUI Specs
opt=$(zenity --list \
--title="Debloat" \
--width=510 --height=400 \
--column="Option" --column="Description" \
    "Enable" "Enable all Amazon apps" \
    "Disable" "Disable Amazon bloat" \
    "Custom" "Disable selected packages" \
    "Edit" "Open Debloat.txt in a text editor")

# Debloat & Package List
packages=$(awk '{print $1}' < Debloat.txt)
adb shell pm list packages -s > packagelist

# Enable or Disable Packages (if Present) & Features Based on Selection
case "$opt" in
    "Enable" | "Disable")
        for package in ${packages}; do
            grep -q "$package" < packagelist && debloat "$opt" "$package" &
        done
        wait
        if [ "$opt" = "Enable" ]; then
            echo "Disabling Adguard DNS"
            adb shell settings put global private_dns_mode -hostname
            export core="com.amazon.firelauncher com.amazon.device.software.ota com.amazon.device.software.ota.override com.amazon.kindle.otter.oobe.forced.ota"
            for package in ${core}; do
                adb shell pm enable "$package" 2> /dev/null ||
                echo "Failed to Enable: $package"
            done
            echo "Enabling Background Activities"
            adb shell settings put global always_finish_activities 0
            echo "Successfully Enabled Fire OS Bloat"
        else
            echo "Disabling Telemetry & Resetting Advertising ID"
            adb shell settings put secure limit_ad_tracking 1
            adb shell settings put secure usage_metrics_marketing_enabled 0
            adb shell settings put secure USAGE_METRICS_UPLOAD_ENABLED 0
            adb shell pm clear com.amazon.advertisingidsettings
            echo "Disabling Location"
            adb shell settings put secure location_providers_allowed -network
            echo "Blocking Ads With Adguard DNS"
            adb shell settings put global private_dns_mode hostname
            adb shell settings put global private_dns_specifier dns.adguard.com
            echo "Disabling Lockscreen Ads"
            adb shell settings put global LOCKSCREEN_AD_ENABLED 0
            echo "Disabling Search on Lockscreen"
            adb shell settings put secure search_on_lockscreen_settings 0
            echo "Speeding Up Animations"
            adb shell settings put global window_animation_scale 0.50
            adb shell settings put global transition_animation_scale 0.50
            adb shell settings put global animator_duration_scale 0.50
            ram=$(adb shell grep "MemTotal" /proc/meminfo | awk '{print $2}')
            [ "$ram" -lt "1500000" ] && { echo "Disabling Background Activities (< 1.5GB Ram)";
            adb shell settings put global always_finish_activities 1; }
            echo "Successfully Debloated Fire OS"
        fi;;
    
    "Custom")
        packages=$(adb shell pm list packages -e | cut -f2 -d:)
        list=$(zenity --list --width=500 --height=400 --column=Packages --multiple $packages | tr '|' '\n')
        for package in ${list}; do
            debloat "Disable" "$package"
        done;;

    "Edit")
        xdg-open ./Debloat.txt 2> /dev/null || open -e ./Debloat.txt
        exec ./debloat.sh;
    esac

exec ./ui.sh
