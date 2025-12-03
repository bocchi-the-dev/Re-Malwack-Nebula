#!/system/bin/sh
# shellcheck disable=SC2112
# shellcheck disable=SC3043
# shellcheck disable=SC3009
# shellcheck disable=SC2068
# Welcome to the main script of the module :)
# Side notes: Literally everything in this module relies on this script you're checking right now.
# customize.sh (installer script), action script and even WebUI!
# Now enjoy reading the code
# - ZG089, Founder of Re-Malwack.

# global variables:
persistantDirectory="/data/adb/Re-Malwack"
realPath="$(readlink -f "$0")"
moduleDirectory="$(dirname "${realPath}")"
hostsFile="$moduleDirectory/system/etc/hosts"
systemHosts="/system/etc/hosts"
tmpHosts="/data/local/tmp/hosts"
thisInstanceLogFile="$persistantDirectory/logs/Re-Malwack_$(date +%Y-%m-%d_%H%M%S).log"
# redirect error messages to /dev/stderr for logging when the action.sh is executed.
[ -n "$isRanByActions" ] && thisInstanceLogFile="/dev/stderr" 
prodOEM=$(tolower "$(getprop ro.product.brand)")
isZNDetected=false
ZNModuleDir="/data/adb/modules/hostsredirect"

# pre-setup:
for i in logs counts cache/whitelist cache/trackers; do
    for j in blacklist.txt sources.txt whitelist.txt; do
        mkdir -p $persistantDirectory/$i
        touch $persistantDirectory/$j
    done
done
PREVPATH="${PATH}"
PATH="/data/adb/ap/bin:/data/adb/ksu/bin:/data/adb/magisk:/data/data/com.termux/files/usr/bin:$PREVPATH"

# get values from the config.sh file.
source "/data/adb/Re-Malwack/config.sh" || . "/data/adb/Re-Malwack/config.sh"

# set `throwOneToTwo` if we got --quiet in the args
echo "$@" | grep -q "--quiet" && throwOneToTwo=true || throwOneToTwo=false

# PURE FREEAKING HEADACHEEEEEE
function rmlwkBanner() {
    [ "$throwOneToTwo" = "true" ] && return
    [ -n "$MAGISKTMP" ] && return
    clear
    case "$((($(date +%s) % 2) + 1))" in
        "1")
            printf '\033[0;31m'
            printf "    ____             __  ___      __                    __            \n"
            printf "   / __ \\___        /  |/  /___ _/ /      ______ ______/ /__          \n"
            printf "  / /_/ / _ \\______/ /|_/ / __ \`/ / | /| / / __ \`/ ___/ //_/       \n"
            printf " / _, _/  __/_____/ /  / / /_/ / /| |/ |/ / /_/ / /__/ ,<              \n"
            printf "/_/ |_|\\___/     /_/  /_/\\__,_/_/ |__/|__/\\__,_/\\___/_/|_|      \n"
            printf '\033[0;31m'
            echo "================================================================"
            printf '\033[0m'
        ;;
        "2")
            printf '\033[0;31m'
            printf "██████╗ ███████╗    ███╗   ███╗ █████╗ ██╗     ██╗    ██╗ █████╗  ██████╗██╗  ██╗\n"
            printf "██╔══██╗██╔════╝    ████╗ ████║██╔══██╗██║     ██║    ██║██╔══██╗██╔════╝██║ ██╔╝\n"
            printf "██████╔╝█████╗█████╗██╔████╔██║███████║██║     ██║ █╗ ██║███████║██║     █████╔╝ \n"
            printf "██╔══██╗██╔══╝╚════╝██║╚██╔╝██║██╔══██║██║     ██║███╗██║██╔══██║██║     ██╔═██╗ \n"
            printf "██║  ██║███████╗    ██║ ╚═╝ ██║██║  ██║███████╗╚███╔███╔╝██║  ██║╚██████╗██║  ██╗\n"
            printf "╚═╝  ╚═╝╚══════╝    ╚═╝     ╚═╝╚═╝  ╚═╝╚══════╝ ╚══╝╚══╝ ╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝\n"
            printf '\033[0;31m'
            echo "===================================================================================="
            printf '\033[0m'
        ;;
    esac
    updateStatus
}

function help() {
    rmlwkBanner
    logShit "help(): Arguments given by user: $args"
    consoleMessage "- Usage: $(basename "$0") [--OPTION] [SUB-OPTION]"
    consoleMessage ""
    consoleMessage "  Normal Options:"
    consoleMessage "    -u,  --update-hosts                     Update the adblock hosts."
    consoleMessage "    -a,  --auto-update <enable|disable>     Enable or disable automatic host updates."
    consoleMessage "    -r,  --reset                            Restore the original hosts file."
    consoleMessage "    -as, --adblock-switch                   Toggle adblock protections on/off."
    consoleMessage "    -w,  --whitelist <add|remove> <domain>  Add or remove a domain/pattern from the whitelist."
    consoleMessage "    -b,  --blocklist <add|remove> <domain>  Add or remove a domain from the blocklist."
    consoleMessage ""
    consoleMessage "  Block Options:"
    consoleMessage "    Example: --block=gambling, -bg <disable>"
    consoleMessage "             Pass \"disable\" to unblock."
    consoleMessage ""
    consoleMessage "    Available block categories:"
    consoleMessage "      gambling, fakenews, social, porn & trackers"
    consoleMessage ""
    consoleMessage "  Advanced Options:"
    consoleMessage "    -c, --custom-source <add|remove> <domain>   Add or remove a custom hosts source."
    consoleMessage ""
    consoleMessage "\033[0;31m Example usage: su -c rmlwk --update-hosts\033[0m"
}
# PURE FREEAKING HEADACHEEEEEE

# helper functions:
function consoleMessage() {
    if [ "${throwOneToTwo}" == "true" ]; then
        echo -e "[$(date +"%m-%d-%Y %I:%M:%S %p")] $2 | $1" >> ${thisInstanceLogFile}
    else
        echo -e "$1"
        [ -z "$2" ] || echo -e "[$(date +"%m-%d-%Y %I:%M:%S %p")] $2" >> ${thisInstanceLogFile}
    fi
}

function logShit() {
    echo -e "[$(date +"%m-%d-%Y %I:%M:%S %p")] $1" >> ${thisInstanceLogFile}
}

function abortInstance() {
    consoleMessage "$1" "$2"
    export PATH="${PREVPATH}"
    exit 1;
}

function tolower() {
    echo -e "$1" | tr '[:upper:]' '[:lower:]'
}

function checkInternet() {
    ping -c 1 -w 5 8.8.8.8 &>/dev/null || abortInstance "- No internet connection detected, Please connect to a network then try again." "checkInternet(): No internet connection."
}

function fetch() {
    checkInternet;
    local output="$1" url="$2"
    if command -v curl &>/dev/null; then
        while true; do
            curl -Ls "$url" > "$output" 2>"$thisInstanceLogFile" || abortInstance "- Failed to download the file, send the logs to the developer if the issue persists." "fetch(): Failed to download the file, URL=$url | download path: $output"
            echo "" >> "$output"
            break
        done
    elif command -v wget &>/dev/null; then
        while true; do
            wget --no-check-certificate -qO - "$url" > "$output" 2>"$thisInstanceLogFile" || abortInstance "- Failed to download the file, send the logs to the developer if the issue persists." "fetch(): Failed to download the file, URL=$url | download path: $output"
            echo "" >> "$output"
            break
        done
    fi
}
# helper functions:

# main functions:
function isDefaultHosts() {
    [ "$blocked_mod" -eq 0 ] && [ "$blocked_sys" -eq 0 ] \
    || { [ "$blocked_mod" -eq "$blacklist_count" ] && [ "$blocked_sys" -eq "$blacklist_count" ]; }
}

function hostsFilterer() {
    local file="$1"
    [ ! -f "$file" ] && return 1;
    tolower "$file" | grep -q "whitelist" && return 0
    sed -i '/^[[:space:]]*#/d; s/[[:space:]]*#.*$//; /^[[:space:]]*$/d; s/^[[:space:]]*//; s/[[:space:]]*$//; s/\r$//; s/[[:space:]]\+/ /g' "$file"
}

function stageBlocklistFiles() {
    local i=1
    local file
    for file in "$persistantDirectory/cache/$1/hosts"*; do
        [ -f "$file" ] || continue
        cp -f "$file" "${tmpHosts}${i}"
        i=$((i+1))
    done
}

function installHosts() {
    consoleMessage "- Trying to fetch module repo's whitelist files.." "installHosts(): fetchin' some whitelist from the origin repo.."
    fetch "$persistantDirectory/cache/whitelist/whitelist.txt" https://raw.githubusercontent.com/ZG089/Re-Malwack/main/whitelist.txt
    fetch "$persistantDirectory/cache/whitelist/social_whitelist.txt" https://raw.githubusercontent.com/ZG089/Re-Malwack/main/social_whitelist.txt
    consoleMessage "  Starting to install $1 hosts..." "installHosts(): Installing $1 hosts.."
    cp -f "$hostsFile" "${tmpHosts}0"
    consoleMessage "  Trying to prepare blocklists.." "installHosts(): Preparing blocklists.."
    local whitelistFile="${persistantDirectory}/cache/whitelist/whitelist.txt"
    [ "${block_social}" -eq 0 ] && whitelistFile="${whitelistFile} ${persistantDirectory}/cache/whitelist/social_whitelist.txt" || \
        consoleMessage "  Social block triggered, social whitelist won't be applied" "installHosts(): Social whitelist won't be applied because the social block is triggered already."
    [ -s "$persistantDirectory/whitelist.txt" ] && whitelistFile="$whitelistFile $persistantDirectory/whitelist.txt"
    
    # merge the whole whitelist into one single one!
    cat "$whitelistFile" | sed '/#/d; /^$/d' | awk '{print "0.0.0.0", $0}' > "${tmpHosts}w"
    [ ! -s "${tmpHosts}w" ] && echo "" > "${tmpHosts}w"
    
    # In case of hosts update (since only combined file exists only on --update-hosts)
    if [ -f "$combinedFile" ]; then
        consoleMessage "- Unified hosts has been found, sorting it.." "installHosts(): Sorting unified hosts.."
        cat "${tmpHosts}0" >> "$combinedFile" 
        awk '!seen[$0]++' "$combinedFile" > "${tmpHosts}merged.sorted"
    else
        consoleMessage "  Multiple hosts has been found, doing a merge + sort on them." "installHosts(): Doing a merge and sort on multiple hosts.."
        LC_ALL=C sort -u "${tmpHosts}"[!0] "${tmpHosts}0" > "${tmpHosts}merged.sorted"
    fi
    consoleMessage "- Trying to merge hosts into one..." "installHosts(): Doing a hosts merge and copying them into one.."
    grep -Fvxf "${tmpHosts}w" "${tmpHosts}merged.sorted" > "$hostsFile"
    chmod 644 "$hostsFile"
    rm -f "${tmpHosts}"* 2>/dev/null
    consoleMessage "- Successfully installed $1 hosts, thank you!" "installHosts(): installed $1 hosts successfully."
    return 0
}

function removeHosts() {
    consoleMessage "- Starting to remove hosts" "removeHosts(): Tryin' to remove nonsense? idk"
    cp -f "$hostsFile" "${tmpHosts}0"
    cat "$cacheHosts"* | sort -u > "${tmpHosts}1"
    awk 'NR==FNR {seen[$0]=1; next} !seen[$0]' "${tmpHosts}1" "${tmpHosts}0" > "$hostsFile"
    if [ ! -s "$hostsFile" ]; then
        consoleMessage "  Seems like the main hosts file is empty, restoring it's default entries.." "removeHosts(): Restoring the default entries on the main hosts file.."
        echo -e "127.0.0.1 localhost\n::1 localhost" > "$hostsFile"
    fi
    rm -f "${tmpHosts}"* 2>/dev/null
    consoleMessage "- Finished removing hosts" "removeHosts(): Finished removin' nonsense."
}

function blockContent() {
    local blockType="$1" status="$2"
    cacheHosts="$persistantDirectory/cache/$blockType/hosts"
    mkdir -p "$persistantDirectory/cache/$blockType"
    if [ "$status" = 0 ]; then
        if [ ! -f "${cacheHosts}1" ]; then
            consoleMessage "- No cached $blockType blocklist is found, redownloading it to disable it properly.." "blockContent(): Cached ${blockType} blocklist is missing, setting it up again to disable it properly..."
            fetch "${cacheHosts}1" "https://raw.githubusercontent.com/StevenBlack/hosts/master/alternates/${blockType}-only/hosts"
            if [ "${blockType}" = "porn" ]; then
                fetch "${cacheHosts}2" https://raw.githubusercontent.com/johnlouie09/Anti-Porn-HOSTS-File/refs/heads/master/HOSTS.txt
                fetch "${cacheHosts}3" https://raw.githubusercontent.com/Sinfonietta/hostfiles/refs/heads/master/pornography-hosts
                fetch "${cacheHosts}4" https://raw.githubusercontent.com/columndeeply/hosts/refs/heads/main/safebrowsing
            fi
            stageBlocklistFiles
            installHosts "${blockType}"
        fi
        removeHosts
        sed -i "s/^block_${blockType}=.*/block_${blockType}=0/" "/data/adb/Re-Malwack/config.sh"
        consoleMessage "- Disabled $blockType blocklist" "blockContent(): Disabled $blockType"
    else
        if [ ! -f "${cacheHosts}1" ] || [ "${status}" = "update" ]; then
            consoleMessage "- Trying to download hosts for $blockType block.."
            fetch "${cacheHosts}1" "https://raw.githubusercontent.com/StevenBlack/hosts/master/alternates/${blockType}-only/hosts"
            if [ "$blockType" = "porn" ]; then
                fetch "${cacheHosts}2" https://raw.githubusercontent.com/johnlouie09/Anti-Porn-HOSTS-File/refs/heads/master/HOSTS.txt
                fetch "${cacheHosts}3" https://raw.githubusercontent.com/Sinfonietta/hostfiles/refs/heads/master/pornography-hosts
                fetch "${cacheHosts}4" https://raw.githubusercontent.com/columndeeply/hosts/refs/heads/main/safebrowsing
            fi
            hostsFilterer "$persistantDirectory/cache/$blockType/hosts"*
        fi
        if [ "$status" != "update" ]; then
            stageBlocklistFiles "$blockType"
            installHosts "$blockType"
            sed -i "s/^block_${blockType}=.*/block_${blockType}=1/" "/data/adb/Re-Malwack/config.sh"
            consoleMessage "- Enabled $blockType blocklist." "blockContent(): Enabled $blockType blocklist.."
        fi
    fi
}

function remountHosts()
{
    if [ "$isZNDetected" == "true" ]; then
        logShit "ZN Hosts redirect is found, skipping mount operation.";
        return 0;
    fi
    consoleMessage "Attempting for a hosts remount..." "remountHosts(): Attempting for a hosts remount..."
    umount -l "$systemHosts" &>/dev/null || logShit "remountHosts(): Failed to unmount $systemHosts"
    if ! mount --bind "$hostsFile" "$systemHosts"; then
        consoleMessage "- Failed to remount hosts, please report this issue to the developer!" "remountHosts(): Failed to mount $hostsFile -> $systemHosts";
        return 1;
    else
        consoleMessage "Hosts has been remounted successfully." "remountHosts(): Hosts remounted."
    fi
}

function blockTrackers() {
    status="$1"
    cacheHosts="${persistantDirectory}/cache/trackers/hosts"
    mkdir -p $(dirname "$cacheHosts")
    if [ "$status" = "disable" ] || [ "$status" = "0" ]; then
        [ "$block_trackers" = 0 ] && abortInstance "- Tracker blocking is already disabled." "blockTrackers: User tried to unblock trackers while it's already unblocked."
        if ! ls "${cacheHosts}"* >/dev/null 2&1; then
            case "${prodOEM}" in
                xiaomi|poco|redmi|oppo|realme)
                    :
                ;;
                *)
                    abortInstance "Your ${prodOEM} is not found in the oem trackers blocklists, aborting this instance." "blockTrackers(): User's ${prodOEM} is not supported for blocking OEM trackers."
                ;;
            esac
            consoleMessage "- No cached trackers blocklist file found for your $prodOEM, re-downloading before removal." "blockTrackers(): Re-downloading tracker hosts.."
            fetch "${cacheHosts}1" "https://raw.githubusercontent.com/r-a-y/mobile-hosts/refs/heads/master/AdguardTracking.txt"
            hostsFilterer "${cacheHosts}1"
            fetch "${cacheHosts}2" "https://raw.githubusercontent.com/hagezi/dns-blocklists/main/hosts/native.$(
                case "${prodOEM}" in
                    xiaomi|poco|redmi)
                        echo "xiaomi"
                    ;;
                    oppo|realme)
                        echo "oppo-realme"
                    ;;
                    *)
                        echo "${prodOEM}"
                    ;;
                esac
            ).txt"
            hostsFilterer "${cacheHosts}2"
            stageBlocklistFiles "trackers"
            installHosts "trackers"
        fi
        consoleMessage "  Disabling trackers block for $prodOEM device."
        removeHosts
        sed -i "s/^block_trackers=.*/block_trackers=0/" "/data/adb/Re-Malwack/config.sh"
        consoleMessage "- Trackers block has been disabled" "blockTrackers(): User's request for blocking the trackers has been disabled."
    else
        [ "$block_trackers" = 1 ] && abortInstance "- Tracker blocking is already enabled." "blockTrackers: User tried to block trackers while it's already blocked."
        if ! ls "${cacheHosts}"* >/dev/null 2&1; then
            consoleMessage "- Fetching trackers block hosts for $prodOEM" "blockTrackers(): Fetching trackers block hosts for $prodOEM"
            fetch "${cacheHosts}1" "https://raw.githubusercontent.com/hagezi/dns-blocklists/main/hosts/native.$(
                case "${prodOEM}" in
                    xiaomi|poco|redmi)
                        echo "xiaomi"
                    ;;
                    oppo|realme)
                        echo "oppo-realme"
                    ;;
                    *)
                        echo "${prodOEM}"
                    ;;
                esac
            ).txt"
            hostsFilterer "${cacheHosts}1"
            consoleMessage "  Enabling trackers block for $prodOEM device." "blockTrackers(): Enabling trackers block for $prodOEM device."
            stageBlocklistFiles "trackers"
            installHosts "trackers"
            sed -i "s/^block_trackers=.*/block_trackers=1/" "/data/adb/Re-Malwack/config.sh"
            consoleMessage "- Trackers block has been enabled" "blockTrackers(): User's request for blocking the trackers has been enabled."
        fi
    fi
}

function updateStatus() {
    local lastMod=$(stat -c '%y' "$hostsFile" 2>/dev/null | cut -d'.' -f1)
    
    # Module hosts count
    blocked_sys=$(cat "$persistantDirectory/counts/blocked_sys.count" 2>/dev/null)
    blocked_mod=$(cat "$persistantDirectory/counts/blocked_mod.count" 2>/dev/null)    
    
    # Count blacklisted entries (excluding comments and empty lines)
    blacklist_count=0
    [ -s "$persistantDirectory/blacklist.txt" ] && blacklist_count=$(grep -c '^[^#[:space:]]' "$persistantDirectory/blacklist.txt")
    
    # Count whitelisted entries (excluding comments and empty lines)
    whitelist_count=0
    [ -f "$persistantDirectory/whitelist.txt" ] && whitelist_count=$(grep -c '^[^#[:space:]]' "$persistantDirectory/whitelist.txt")
    
    # whatever
    logShit "Blacklist entries count: $blacklist_count"
    logShit "Whitelist entries count: $whitelist_count"
    logShit "System hosts entries count: $blocked_sys"
    logShit "Module hosts entries count: $blocked_mod"

    # Determine mode based on zn-hostsredirect detection
    [ "$isZNDetected" == "true" ] && mode="hosts mount mode: zn-hostsredirect" || mode="hosts mount mode: Standard mount"

    if isBlockerPaused; then
        statusMessage="Status: Re-Malwack is paused temporarily now."
    elif [ -d "/data/adb/modules_update/Re-Malwack" ]; then
        statusMessage="Status: Reboot required to apply the pending module update changes."
    elif [ -d /data/adb/modules_update/Re-Malwack ] && [ ! -d /data/adb/modules/Re-Malwack ]; then
        statusMessage="Status: Reboot required to apply first time install changes."
    elif isDefaultHosts; then
        if [ "$blacklist_count" -ge 2 ]; then
            plural="entries are active"
            [ "$blacklist_count" -eq 1 ] && plural="entry is active"
            statusMessage="Status: Protection is disabled due to reset | Only $blacklist_count blacklist $plural"
        else
            statusMessage="Status: Protection is disabled due to reset."
        fi
    elif [ "$blocked_mod" -ge 0 ]; then
        if [ "$blocked_sys" -eq 0 ] && [ "$blocked_mod" -gt 0 ] && [ "$isZNDetected" -ne 1 ]; then
            # Attempt to remount hosts and refresh status
            # Only in case of broken mount detection - @ZG089
            remountHosts
            refreshCounts
            if [ "$blocked_sys" -eq 0 ] && [ "$blocked_mod" -gt 0 ]; then
                statusMessage="Status: Critical Error Detected (Hosts Mount Failure). Please check your root manager settings and disable any conflicted module(s)."
                consolePrint "- Critical Error Detected (Hosts mount failure). Please check your root manager settings and disable any conflicting module(s)."
            fi
            statusMessage="Critical: Hosts mount is broken and it needs to be fixed. Please check your root manager settings and disable any conflicted module(s)."
            consoleMessage "- Critical error found! Solution: Please check your root manager settings and disable any conflicted module(s)." "updateStatus(): Hosts mount is broken."
        else
            statusMessage="Status: Protection is enabled | Blocking $blocked_mod domains"
            [ "$blacklist_count" -ge 1 ] && statusMessage="Status: Protection is enabled | Blocking $((blocked_mod - blacklist_count)) domains + $blacklist_count (blacklist)"
            [ "$whitelist_count" -ge 1 ] && statusMessage="$statusMessage | Whitelist: $whitelist_count"
            statusMessage="$statusMessage | Last updated: $lastMod | $mode"
        fi
    fi
    [ -n "${statusMessage}" ] && sed -i "s/^description=.*/description=$statusMessage/" "$moduleDirectory/module.prop"
}

function toggleCron() {
    local JOB_DIR="/data/adb/Re-Malwack/auto_update"
    local JOB_FILE="$JOB_DIR/root"
    CRON_JOB="0 */12 * * * sh /data/adb/modules/Re-Malwack/rmlwk.sh --update-hosts && echo '[AUTO UPDATE TIME!!!]' >> /data/adb/Re-Malwack/logs/auto_update.log"
    if [ "$1" == "disable" ]; then  
        CRON_JOB="0 */12 * * * sh /data/adb/modules/Re-Malwack/rmlwk.sh --update-hosts && echo \"[$(date '+%Y-%m-%d %H:%M:%S')] - Running auto update.\" >> /data/adb/Re-Malwack/logs/auto_update.log"
        logShit "toggleCron(): Disabling auto update cron work."
        logShit "toggleCron(): Killing cron processes..."
        busybox pkill crond > /dev/null 2>&1
        busybox pkill busybox crond > /dev/null 2>&1
        busybox pkill busybox crontab > /dev/null 2>&1
        busybox pkill crontab > /dev/null 2>&1
        logShit "toggleCron(): cron processes has been stopped."
        # Check if cron job exists
        if [ ! -d "$JOB_DIR" ]; then
            consoleMessage "- Auto update is already disabled"
        else    
            rm -rf "$JOB_DIR"
            logShit "toggleCron(): cron job removed."
            sed -i 's/^daily_update=.*/daily_update=0/' "/data/adb/Re-Malwack/config.sh"
            consoleMessage "- Auto-updates has been disabled." "toggleCron(): Auto-updates has been disabled."
        fi
    else
        if [ -d "$JOB_DIR" ]; then
            consoleMessage "- Auto update is already enabled"
        else
            mkdir -p "$JOB_DIR"
            touch "$JOB_FILE"
            echo "$CRON_JOB" >> "$JOB_FILE"
            if ! busybox crontab "$JOB_FILE" -c "$JOB_DIR"; then
                consoleMessage "  Failed to enable auto updates, this could be an issue with cron itself." "toggleCron(): Failed to enable auto update: cron-side error."
            else
                logShit "toggleCron(): cron job added."
                crond -c $JOB_DIR -L $persistantDirectory/logs/auto_update.log
                sed -i 's/^daily_update=.*/daily_update=1/' "/data/adb/Re-Malwack/config.sh"
                consoleMessage "- Auto-updates has been enabled." "toggleCron(): Auto-updates has been enabled."
            fi
        fi
    fi
}

function refreshCounts() {
    blocked_mod=$(grep -c '^0\.0\.0\.0[[:space:]]' "$hostsFile" 2>/dev/null)
    echo "${blocked_mod:-0}" > "$persistantDirectory/counts/blocked_mod.count"
    blocked_sys=$(grep -c '^0\.0\.0\.0[[:space:]]' "$systemHosts" 2>/dev/null)
    echo "${blocked_sys:-0}" > "$persistantDirectory/counts/blocked_sys.count"
}

function isBlockerPaused() {
    [ -f "$persistantDirectory/hosts.bak" ] || [ "$adblock_switch" -eq 1 ]
}

function pauseBlocker() {
    if isBlockerPaused; then
        resumeBlocker
        exit 0
    fi
    if isDefaultHosts && ! isBlockerPaused; then
        consoleMessage "- You cannot pause protections while hosts is reset." "pauseBlocker(): User tried to pause protections while the hosts is reset."
        exit 1
    fi
    consoleMessage "- Trying to resume protections..." "pauseBlocker(): Trying to resume protections.."
    cp "$hostsFile" "$persistantDirectory/hosts.bak"
    printf "127.0.0.1 localhost\n::1 localhost\n" > "$hostsFile"
    sed -i 's/^adblock_switch=.*/adblock_switch=1/' "/data/adb/Re-Malwack/config.sh"
    refreshCounts
    updateStatus
    consoleMessage "  Protection has been paused." "pauseBlocker(): Re-Malwack is paused now, the services will remain suspended till the user resumes the service."
}

function resumeBlocker() {
    consoleMessage "- Trying to resume protection..." "resumeBlocker(): Trying to resume protections.."
    if [ -f "$persistantDirectory/hosts.bak" ]; then
        cat "$persistantDirectory/hosts.bak" > "$hostsFile"
        rm -f $persistantDirectory/hosts.bak
        sed -i 's/^adblock_switch=.*/adblock_switch=0/' "/data/adb/Re-Malwack/config.sh"
        refreshCounts
        updateStatus
        consoleMessage "  Protection has been resumed." "resumeBlocker(): Re-Malwack services has been started! the services will get resumed soon!"
    else
        consoleMessage "  Backup hosts file is missing in the expected path, running an update as a fallback action." "resumeBlocker(): Force resuming protection and running hosts update as a fallback action due to the missing backup hosts file."
        sed -i 's/^adblock_switch=.*/adblock_switch=0/' "/data/adb/Re-Malwack/config.sh"
        exec "$0" --update-hosts
    fi
}

# main functions:

# gbl starts from now on:
if [ -n "$WEBUI" ]; then
    refreshCounts
    updateStatus
fi

# log errors:
exec 2>>"$thisInstanceLogFile"

# Trap runtime errors (logs failing command + exit code)
trap '
err_code=$?
timestamp=$(date +"%Y-%m-%d %I:%M:%S %p")
echo "[$timestamp] - [ERROR] - Command \"$BASH_COMMAND\" failed at line $LINENO (exit code: $err_code)" >> "$thisInstanceLogFile"
' ERR

# Trap final script exit
trap '
exit_code=$?
timestamp=$(date +"%Y-%m-%d %I:%M:%S %p")

case $exit_code in
    0)   echo "[$timestamp] - [SUCCESS] - Script ran successfully with no errors" >> "$thisInstanceLogFile" ;;
    1)   msg="General error" ;;
    126) msg="Command invoked cannot execute" ;;
    127) msg="Command not found" ;;
    130) msg="Terminated by Ctrl+C (SIGINT)" ;;
    137) msg="Killed (possibly OOM or SIGKILL)" ;;
    *)   msg="Unknown error (code $exit_code)" ;;
esac

[ $exit_code -ne 0 ] && echo "[$timestamp] - [ERROR] - $msg at line $LINENO (exit code: $exit_code)" >> "$thisInstanceLogFile"
' EXIT

# check if zygisk host redirect module is enabled - @ZG089
if [ -d "$ZNModuleDir" ] && [ ! -f "$ZNModuleDir/disable" ]; then
    isZNDetected=true
    hostsFile="$ZNModuleDir/hosts"
    logShit "Zygisk hosts redirect module is found, using it's hosts from now on."
else 
    logShit "Using standard mount method with system hosts."
fi

# print the banner thing.
rmlwkBanner

# put arguments in a variable (useful in the near future.)
args="$(tolower "$@")"

case "$(echo "${args}" | awk '{print $1}')" in
    "--adblock-switch|-as")
        pauseBlocker
    ;;
    "--reset|-r")
        consoleMessage "\n- Running reset actions.." "main: User initiated a hosts reset!"
        isBlockerPaused && abortInstance "- Adblocker is paused and it cannot be reset. Please resume it before running this action." "main: User tried to reset service while the service is paused."
        consoleMessage "- Trying to revert previous changes..." "main: Hosts reset is triggered, trying to revert the changes.."
        printf "127.0.0.1 localhost\n::1 localhost" > "${hostsFile}"
        
        # re-add blocklist entries after reset if they exist :/
        if [ -s "${persistantDirectory}/blacklist.txt" ]; then
            consoleMessage "  Re-inserting blocklist entries after a reset trigger..." \
                "main: Re-inserting the blocklist entries (${persistantDirectory}/blacklist.txt exists and has some content inside it)"
            grep -VFxf "${persistantDirectory}/blacklist.txt" "${hostsFile}" > "${tmpHosts}_b"
            while read -r line; do
                echo "0.0.0.0 $line"
            done < "$persistantDirectory/blacklist.txt" >> "${tmpHosts}_b"
            cat "${tmpHosts}_b" > "$hostsFile"
            rm -f "${tmpHosts}_b"
        fi
        chmod 644 "${hostsFile}"

        # reset blocklist values to 0 :/
        sed -i 's/^block_\(.*\)=.*/block_\1=0/' "/data/adb/Re-Malwack/config.sh"
        refreshCounts
        updateStatus
        consoleMessage "- Successfully reset hosts." "main: Hosts reset is finished with $? code"
    ;;
    --block=*|-b?)
        clean="${args#--block=}"
        clean="${clean#-b}"
        status="$2"
        blockType="$(
            case "${clean}" in
                "t")
                    echo "trackers"
                ;;
                "s")
                    echo "social"
                ;;
                "f")
                    echo "fakenews"
                ;;
                "g")
                    echo "gambling"
                ;;
                "p")
                    echo "porn"
                ;;
                *)
                    echo "${clean}"
                ;;
            esac)"
        case "$clean" in
            porn|gambling|fakenews|social|trackers|t|s|f|g|p)
                :
            ;;
            *)
                help
                abortInstance "\n- Invalid option argument!" "main: Expected argument not met, what we got instead: $clean | $args"
            ;;
        esac
        consoleMessage "\n- Trying to run requested $blockType block action to get it $(if [ "$status" == "disable" ] || [ "$status" == "0" ]; then echo disabled; else echo enabled; fi)"
        logShit "main: User requested for $blockType block type to get $(if [ "$status" == "disable" ] || [ "$status" == "0" ]; then echo disabled; else echo enabled; fi)"
        if [ "$blockType" = "trackers" ]; then
            blockTrackers "$status"
        else
            eval "block_toggle\"\$block_${blockType}\""
            if [ "$status" == "disable" ] || [ "$status" == "0" ]; then
                if [ "$block_toggle" = 0 ]; then
                    abortInstance "- ${blockType} is already blocked." "main: ${blockType} block is already disabled."
                else 
                    consoleMessage "- Disabling ${blockType} ads block type..." "main: ${blockType} block type disable has been initialized."
                    blockContent "${blockType}" 0
                    consoleMessage "- Unblocked ${blockType} sites successfully :/" "main: unblocked ${blockType} sites."
                fi
            else
                if [ "$block_toggle" = 1 ]; then
                    abortInstance "- ${blockType} is already unblocked." "main: ${blockType} block is already enabled."
                else 
                    consoleMessage "- Enabling ${blockType} ads block type..." "main: ${blockType} block type enable has been initialized."
                    blockContent "${blockType}" 1
                    consoleMessage "- Blocked ${blockType} sites successfully :/" "main: blocked ${blockType} sites."
                fi
            fi
        fi
        refreshCounts
        updateStatus
    ;;
    "--whitelist|-w")
        consoleMessage "\n- Trying to run whitelist actions on given domain(s).." "main: User requested for a domain(s) to get whitelisted."
        isBlockerPaused && abortInstance "- Adblocker is paused and it cannot be reset. Please resume it before running this action." "main: User tried to whitelist some links white the blocker is paused."
        isDefaultHosts && abortInstance "- You cannot whitelist links while hosts is reset." "main: User tried to whitelist some links while the hosts is reset."
        action="$2"
        shift 2
        if [ -z "$action" ] || [ "$#" -ge 3 ] || { [ "$action" != "add" ] && [ "$action" != "remove" ]; }; then
            echo "[!] Invalid arguments for --whitelist|-w"
            echo "Usage: rmlwk --whitelist|-w <add|remove> <domain|pattern>"
            displayWhitelist=$(cat "$persistantDirectory/whitelist.txt" 2>/dev/null)
            [ -n "$displayWhitelist" ] && echo -e "Current whitelist:\n$displayWhitelist" || echo "Current whitelist: no saved whitelist"
            exit 1
        fi

        for rawInput in $@; do 
            # extract host if a URL has been passed.
            printf '%s' "$rawInput" | grep -qE '^https?://' && host=$(printf '%s' "$rawInput" | awk -F[/:] '{print $4}') || host="$rawInput"
            
            # Validate domain format (Special cases for wildcards)
            if ! printf '%s' "$host" | grep -qE '(\*|\.)'; then
                consoleMessage "  Invalid domain input: $rawInput"
                consoleMessage "  Inputs that are considered as valid: 'domain.com', '*.domain.com', '*something', 'something*'"
                continue
            fi
            
            # Ensure the domain is not already blacklisted
            if grep -Fxq "$host" "$persistantDirectory/blacklist.txt"; then
                consoleMessage "  Cannot whitelist $rawInput, it already exists in blocklist." "main: User tried to whitelist a domain that exists in blocklist."
                continue
            fi
            
            # Determine wildcard mode
            # - suffix wildcard if starts with "*.something" or ".something"
            # - glob mode if contains '*' anywhere (over entire domain)
            suffixWildcard=0
            globMode=0
            if printf '%s' "$host" | grep -qE '^\*\.|^\.'; then
                suffixWildcard=1
            elif printf '%s' "$host" | grep -q '\*'; then
                globMode=1
            fi

            # Normalize the base domain/pattern
            base="$host"
            
            # strip leading "*." or "." (one label or the dot)
            [ "$suffixWildcard" -eq 1 ] && base="${base#*.}"
            
            # Build a domain-only ERE for matching the 2nd field in hosts
            # 1) escape regex metachars except '*' (handled separately for glob mode)
            escBase=$(printf '%s' "$base" | sed -e 's/[.[\^$+?(){}|\\]/\\&/g')
            if [ "$suffixWildcard" -eq 1 ]; then
                domRe="(^|.*\.)${escBase}$"
            elif [ "$globMode" -eq 1 ]; then
                domRe="^$(printf '%s' "$escBase" | sed 's/\*/.*/g')$"
            else
                domRe="^${escBase}$"
            fi
            if [ "$action" = "add" ]; then
                case "$rawInput" in
                    \*\.*) # Subdomain: *.domain.com
                        domain="${rawInput#*.}"
                        escDomain=$(printf '%s' "$domain" | sed -e 's/[.[\^$+?(){}|\\]/\\&/g')
                        pattern="^0\.0\.0\.0 [^.]+\\.${escDomain}\$"
                        matchType="subdomain"
                    ;;
                    \**) # Suffix: *something
                        suffix="${rawInput#\*}"
                        escSuffix=$(printf '%s' "$suffix" | sed -e 's/[.[\^$+?(){}|\\]/\\&/g')
                        pattern="^0\.0\.0\.0 .*${escSuffix}\$"
                        matchType="suffix"
                    ;;
                    *\*) # Prefix: something*
                        prefix="${rawInput%\*}"
                        escPrefix=$(printf '%s' "$prefix" | sed -e 's/[.[\^$+?(){}|\\]/\\&/g')
                        pattern="^0\.0\.0\.0 ${escPrefix}.*\$"
                        matchType="prefix"
                    ;;
                    *) # Exact
                        domain="$rawInput"
                        escDomain=$(printf '%s' "$domain" | sed -e 's/[.[\^$+?(){}|\\]/\\&/g')
                        pattern="^0\.0\.0\.0 ${escDomain}\$"
                        matchType="exact"
                    ;;
                esac
                # check if already whitelisted.
                if grep -qxF "$rawInput" "${persistantDirectory}/whitelist.txt"; then
                    consoleMessage "  ${rawInput} is already whitelisted." "main: User requested domain cannot be added to the whitelist because it is already in the whitelist domain lists."
                    continue
                fi

                # Collect matches
                matchedDomains=$(grep -E "$pattern" "$hostsFile" | awk '{print $2}' | sort -u)
                if [ -z "$matchedDomains" ]; then
                    consoleMessage "  No matches found for ${rawInput}" "main: No matches has been found for the user requested whitelist domain."
                    continue
                fi

                # Remove blacklisted entries from the match set 
                [ -s "$persistantDirectory/blacklist.txt" ] && matchedDomains=$(printf '%s\n' "$matchedDomains" | grep -Fvxf "$persistantDirectory/blacklist.txt")

                # If nothing left, bail out
                # This code may be removed in the future?
                # I only wrote it just in case a very rare chance that all matched domains are blacklisted
                # Like, someone tries to whitelist the whole blacklisted domains list in one wildcard :sob:
                # idk who's going to do such a thing like this, but uhmmmmmm
                if [ -z "$matchedDomains" ]; then
                    consoleMessage "  Matched domains for this input is already blacklisted, nothing to whitelist."
                    continue
                fi
            
                # Add matched domains to whitelist file
                consoleMessage "- Whitelisting ($matchType): $rawInput" "main: Whitelisting ($matchType): $rawInput. Domains: $matchedDomains"
                for md in $matchedDomains; do
                    grep -qxF "$md" "$persistantDirectory/whitelist.txt" && echo "$md" >> "$persistantDirectory/whitelist.txt"
                done

                # Rewrite hosts file excluding matched domains
                tmpHosts="$persistantDirectory/tmp.hosts.$$"
                grep -Ev "$pattern" "$hostsFile" > "$tmpHosts"
                cat "$tmpHosts" > "$hostsFile"
                rm -f "$tmpHosts"

                # Deduplicate whitelist file
                tmpf="$persistantDirectory/.whitelist.sorted.$$"
                sort -u "$persistantDirectory/whitelist.txt" > "$tmpf" && mv "$tmpf" "$persistantDirectory/whitelist.txt"
                consoleMessage "- Whitelisted ($matchType): $rawInput"
                logShit "main: Whitelisted $rawInput ($matchType)."
            else 
                logShit "main: Removing $host from whitelist..."
                grep -Eq "$domRe" "$persistantDirectory/whitelist.txt" || abortInstance "- $host is not found in whitelist." "main: user requested host is not found in the whitelist."
                tmpf="$persistantDirectory/.whitelist.$$"
                    
                # Extract entries that are being removed
                removedEntries=$(grep -E "$domRe" "$persistantDirectory/whitelist.txt")
                    
                # Remove entry from whitelist file
                grep -Ev "$domRe" "$persistantDirectory/whitelist.txt" > "$tmpf" || true
                mv "$tmpf" "$persistantDirectory/whitelist.txt"
                    
                # Re-add them into hosts (blocked form)
                for re in $removedEntries; do
                    grep -qE "^0\.0\.0\.0[[:space:]]+$re\$" "$hostsFile" || echo -e "\n0.0.0.0 $re" >> "$hostsFile"
                done
                consoleMessage "- $host removed from whitelist. Domain(s) are now blocked again." "main: Removed hosts (pattern) from whitelist and re-blocked domains."
            fi
            consoleMessage " "
        done
    ;;
    "--blocklist|--blacklist|-b")
        consoleMessage "\n- Trying to run whitelist actions on given domain.." "main: User requested for a domain to get whitelisted."
        isBlockerPaused && abortInstance "- Adblocker is paused and it cannot be reset. Please resume it before running this action." "main: User tried to blocklist some links white the blocker is paused."
        option="$2"
        if [ "$option" != "add" ] && [ "$option" != "remove" ]; then
            echo "Usage: rmlwk --blocklist, -b <add/remove> <domain>"
            displayBlocklist=$(cat "$persistantDirectory/blacklist.txt" 2>/dev/null)
            [ -n "$displayBlocklist" ] && echo -e "Current blacklist:\n$displayBlocklist" || echo "Current blacklist: no saved blacklist"
            exit 1
        fi
        shift 2
        for rawInput in $@; do
            # Sanitize input
            printf "%s" "$rawInput" | grep -qE '^https?://' && domain=$(printf "%s" "$rawInput" | awk -F[/:] '{print $4}') || domain="$rawInput"
            
            # Validate domain format
            if ! printf '%s' "$domain" | grep -qiE '^[a-z0-9.-]+\.[a-z]{2,}$'; then
                consoleMessage "  Invalid domain: $domain" "main: User gave an invaild domain in the blocklist action."
                consoleMessage "- Example valid domain: example.com"
                continue
            fi
            
            # Ensure the domain is not already whitelisted
            if grep -Fxq "$domain" "$persistantDirectory/whitelist.txt"; then
                consoleMessage "- Cannot blocklist $domain, it already exists in blocklist." "main: User tried to blocklist a domain that exists in whitelist."
                continue
            fi
            
            if [ "$option" = "add" ]; then
                # Add to hosts file if not already present
                grep -qE "^0\.0\.0\.0[[:space:]]+$domain\$" "$hostsFile" && abortInstance "- $domain is already blocked" "main: User tried to block a domain that is already blocked."
                consoleMessage "- Blocklisting $domain..." "main: Trying to add user requested domain to the blocklist.."
                    
                # Add to blacklist.txt if not already there
                grep -qxF "$domain" "$persistantDirectory/blacklist.txt" || echo "$domain" >> "$persistantDirectory/blacklist.txt"
                    
                # Ensure newline at end before appending
                [ -s "$hostsFile" ] && tail -c1 "$hostsFile" | grep -qv $'\n' && echo -e "\n0.0.0.0 $domain" >> "$hostsFile" || echo -e "0.0.0.0 $domain" >> "$hostsFile"
                consoleMessage "- Added $domain to the hosts file and blocklist." "main: Finished adding requested $domain to the hosts and blocklist file."
            else
                # Remove from blacklist.txt and hosts
                consoleMessage "- Removing $domain from the blocklist..." "main: Trying to remove user requested domain from the blocklist.."
                if ! grep -qxF "$domain" "$persistantDirectory/blacklist.txt"; then
                    consoleMessage "  $domain is not found in blocklist." "main: User requested domain is not found in the blocklist."
                    continue
                fi
                sed -i "/^$(printf '%s' "$domain" | sed 's/[]\/$*.^|[]/\\&/g')$/d" "$persistantDirectory/blacklist.txt"
                tmpHosts="$persistantDirectory/tmp.hosts.$$"
                grep -vF "0.0.0.0 $domain" "$hostsFile" > "$tmpHosts"
                cat "$tmpHosts" > "$hostsFile"
                rm -f "$tmpHosts"
                consoleMessage "- $domain has been removed from blocklist and unblocked." "main: Removed $domain from the blocklist and unblocked."
            fi
            consoleMessage " "
        done
        refreshCounts
        updateStatus
    ;;
    --custom-source|-c)
        consoleMessage "\n- Trying to run custom sources actions on given domain.." "main: User requested for a custom source to be managed."
        option="$2"
        if [ "$#" -ge "3" ]; then
            help;
            abortInstance "- Required arguments are not given" "main: Expected argument style is not met, what we got instead: $clean | $args"
        fi
        if [ "$option" != "add" ] && [ "$option" != "remove" ]; then
            help;
            abortInstance "- Usage: rmlwk --custom-source <add/remove> <domain>" "main: User gave an invalid option: $option"
        fi
        shift 2
        for domain in $@; do
            # Validate URL format (accept http/https)
            if ! printf '%s' "$domain" | grep -qiE '^(https?://[a-z0-9.-]+\.[a-z]{2,}(/.*)?|[a-z0-9.-]+\.[a-z]{2,})$'; then
                consoleMessage "  Invalid domain: $domain"
                consoleMessage "- Example valid domain: example.com, https://example.com or https://example.com/hosts.txt" "main: User gave an invalid domain in the custom sources action."
                continue
            fi
            consoleMessage "- Trying to $([ "${option}" == "add" ] && echo add || echo remove) $domain into the sources.." "main: trying to $([ "${option}" == "add" ] && echo add || echo remove) user's custom domain in the sources."
            if [ "$option" = "add" ]; then
                if grep -qx "$domain" "$persistantDirectory/sources.txt"; then
                    consoleMessage "- $domain is already in sources." "main: User gave an domain that is already present in the sources."
                    continue
                fi
                echo "$domain" >> "$persistantDirectory/sources.txt"
                consoleMessage "- Added $domain to the sources." "main: Added user requested domain to the sources."
            else
                if grep -qx "$domain" "$persistantDirectory/sources.txt"; then
                    sed -i "/^$(printf '%s' "$domain" | sed 's/[]\/$*.^|[]/\\&/g')$/d" "$persistantDirectory/sources.txt"
                    consoleMessage "- Removed $domain from the sources." "main: Removed user requested domain from the sources."
                else
                    consoleMessage "- $domain is not found in the sources." "main: Failed to remove user requested domain, maybe it was not even found? Who knows right?"
                fi
            fi
        done
    ;;
    --update-hosts|-u)
        consoleMessage "\n- Trying to run hosts updater action.." "main: User requested for a hosts update."
        isBlockerPaused && abortInstance "- Adblocker is paused and it cannot be reset. Please resume it before running this action." "main: User tried to update hosts white the blocker is paused."
        combinedFile="${tmpHosts}_all"
        > "$combinedFile"

        # download + normalize base hosts
        consoleMessage "  Fetching base hosts..."
        counter=0
        for host in $(grep -Ev '^#|^$' "$persistantDirectory/sources.txt" | sort -u); do
            fetch "${tmpHosts}${counter}" "$host"
            hostsFilterer "${tmpHosts}${counter}"
            cat "${tmpHosts}${counter}" >> "$combinedFile"
            counter=$((counter + 1))
        done
    
        # Download & process blocklists (cached + enabled)
        for bl in porn gambling social fakenews; do 
            blockVar="block_${bl}"
            eval enabled=\$$blockVar
            cacheHosts="${persistantDirectory}/cache/bl/hosts"

            # download & process only if blocklist is enabled.
            if [ "$enabled" = "1" ]; then
                mkdir -p "${persistantDirectory}/cache/${bl}"
                consoleMessage "  Fetching blocklists for $bl type hosts." "main: fetching blocklists for $bl type hosts."
                fetch "${cacheHosts}1" "https://raw.githubusercontent.com/StevenBlack/hosts/master/alternates/${bl}-only/hosts"
                if [ "$bl" = "porn" ]; then
                    fetch "${cacheHosts}2" https://raw.githubusercontent.com/johnlouie09/Anti-Porn-HOSTS-File/refs/heads/master/HOSTS.txt
                    fetch "${cacheHosts}3" https://raw.githubusercontent.com/Sinfonietta/hostfiles/refs/heads/master/pornography-hosts
                    fetch "${cacheHosts}4" https://raw.githubusercontent.com/columndeeply/hosts/refs/heads/main/safebrowsing
                fi
                
                # Process downloaded hosts
                hostsFilterer "$persistantDirectory/cache/$bl/hosts"*

                # Append only if enabled
                cat "$persistantDirectory/cache/$bl/hosts"* >> "$combinedFile"
                consoleMessage "  Finished fetching $bl blocklists " "main: Added $bl blocklist to the combined file."
            fi
        done
        consoleMessage "  Installing hosts.." "main: Installing downloaded hosts.."
        printf "127.0.0.1 localhost\n::1 localhost" > "${hostsFile}"
        installHosts "all"
        refreshCounts
        updateStatus
    ;;
    --auto-update|-a)
        toggleCron "$(tolower "$2")"
    ;;
    *)
        help
        exit 1
    ;;
esac