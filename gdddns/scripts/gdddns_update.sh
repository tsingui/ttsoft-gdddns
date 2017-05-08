#!/bin/sh

export KSROOT=/jffs/koolshare
source $KSROOT/scripts/base.sh
eval `dbus export gdddns_`

if [ "$gdddns_enable" != "1" ]; then
    echo "not enable"
    exit
fi

die () {
    echo $1
    dbus set gdddns_last_act="$now [失败](IP:$1)"
}

urlencode() {
    # urlencode <string>
    out=""
    while read -n1 c; do
        case $c in
            [a-zA-Z0-9._-]) out="$out$c" ;;
            *) out="$out`printf '%%%02X' "'$c"`" ;;
        esac
    done
    echo -n $out
}

enc() {
    echo -n "$1" | urlencode
}

update_record() {
    curl -kLsX PUT -H "Authorization: sso-key $gdddns_key:$gdddns_secret" \
        -H "Content-type: application/json" "https://api.godaddy.com/v1/domains/$gdddns_domain/records/A/$(enc "$gdddns_name")" \
        -d "{\"data\":\"$current_ip\",\"ttl\":$gdddns_ttl}"
}

now=`date "+%Y-%m-%d %H:%M:%S"`

[ "$gdddns_curl" = "" ] && gdddns_curl="1"
[ "$gdddns_dns" = "" ] && gdddns_dns="114.114.114.114"
[ "$gdddns_ttl" = "" ] && gdddns_ttl="600"


case $gdddns_curl in
"2")
    ip=`nvram get wan2_ipaddr` || die "$ip"
    ;;
"3")
    ip=`nvram get wan3_ipaddr` || die "$ip"
    ;;
"4")
    ip=`nvram get wan4_ipaddr` || die "$ip"
    ;;
*)
    ip=`nvram get wan_ipaddr` || die "$ip"
    ;;
esac

current_ip_info=`nslookup $gdddns_domain $gdddns_dns 2>&1`


if [ "$?" -eq "0" ]; then
    current_ip=`echo "$current_ip_info" | grep 'Address 1' | tail -n1 | awk '{print $NF}'`

    if [ "$ip" = "$current_ip" ]; then
        echo "skipping"
        dbus set gdddns_last_act="<font color=blue>$now    域名解析正常，跳过更新</font>"
        exit 0
    else
        echo "changing"
        update_record
        dbus set gdddns_last_act="<font color=blue>$now    解析已更新，当前解析IP: $current_ip</font>"
    fi 
fi

