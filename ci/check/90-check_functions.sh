#!/bin/bash
# ----------------------------------
#  __/\\\\____________/\\\\___________________/\\\\\\\\\\\____/\\\\\\\\\\\\\___
#   _\/\\\\\\________/\\\\\\_________________/\\\/////////\\\_\/\\\/////////\\\_
#	_\/\\\//\\\____/\\\//\\\____/\\\__/\\\__\//\\\______\///__\/\\\_______\/\\\_
#	 _\/\\\\///\\\/\\\/_\/\\\___\//\\\/\\\____\////\\\_________\/\\\\\\\\\\\\\\__
#	  _\/\\\__\///\\\/___\/\\\____\//\\\\\________\////\\\______\/\\\/////////\\\_
#	   _\/\\\____\///_____\/\\\_____\//\\\____________\////\\\___\/\\\_______\/\\\_
#		_\/\\\_____________\/\\\__/\\_/\\\______/\\\______\//\\\__\/\\\_______\/\\\_
#		 _\/\\\_____________\/\\\_\//\\\\/______\///\\\\\\\\\\\/___\/\\\\\\\\\\\\\/__
#		  _\///______________\///___\////__________\///////////_____\/////////////_____
#			By toulousain79 ---> https://github.com/toulousain79/
#
######################################################################
#
#	Copyright (c) 2013 toulousain79 (https://github.com/toulousain79/)
#	Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
#	The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
#	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
#	IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#	--> Licensed under the MIT license: http://www.opensource.org/licenses/mit-license.php
#
##################### FIRST LINE #####################################

nReturn=${nReturn}
[[ ${nReturn} -gt 0 ]] && exit "${nReturn}"

if [ -z "${vars}" ] || [ "${vars}" -eq 0 ]; then
    # shellcheck source=ci/check/00-load_vars.bsh
    source "$(dirname "$0")/00-libs.bsh"
else
    nReturn=${nReturn}
fi

case "${CHECK_METHOD}" in
    'full' | 'integ' | 'install')
        #### Replace systemctl
        gfnCopyProject
        sFilesList="$(grep -IRl "systemctl " --exclude-dir ".git" --exclude-dir ".vscode" --exclude-dir "ci" --exclude-dir "lang" --exclude-dir "logrotate" --exclude-dir "web" "${sDirToScan}/")"
        if [ -n "${sFilesList}" ]; then
            echo && echo -e "${CBLUE}*** Replace all systemctl commands ***${CEND}"
            for sFile in ${sFilesList}; do
                nRes=0
                while read -r sROW; do
                    ## DO NOT REMOVE FOLLOWING ELSE LOOP WILL FAILING !!!
                    echo "${sROW}" >/dev/null

                    sColumns=()
                    for sString in ${sROW}; do
                        sColumns+=("${sString}")
                    done

                    nCount=0
                    for ((col = nCount; col <= ${#sColumns[@]}; col++)); do
                        (! grep -q '^systemctl' <<<"${sColumns[${col}]}") && {
                            /bin/true
                            continue
                        }

                        nCount=${col}

                        [[ ${nCount} -gt 0 ]] && {
                            /bin/true
                            break
                        }
                    done

                    nCount=$((nCount + 1))
                    sSwitch="${sColumns[${nCount}]}"
                    nCount=$((nCount + 1))
                    sService="${sColumns[${nCount}]}"
                    sService="${sService}"

                    if (grep -q 'daemon-reload' <<<"${sROW}"); then
                        # echo "${sFile}: systemctl daemon-reload --> #systemctl daemon-reload"
                        (! sed -i -e "s/systemctl daemon-reload/#systemctl daemon-reload/g" "${sFile}") && {
                            /bin/true
                            ((nRes++))
                        }
                    elif (grep -q 'systemctl reboot' <<<"${sROW}"); then
                        # echo "${sFile}: systemctl reboot --> #systemctl reboot"
                        (! sed -i -e "s/systemctl reboot/#systemctl reboot/g" "${sFile}") && {
                            /bin/true
                            ((nRes++))
                        }
                    elif (grep -q ' disable' <<<"${sROW}"); then
                        # echo "${sFile}: systemctl disable ${sService} --> update-rc.d ${sService//.service/} disable"
                        (! sed -i -e "s/systemctl disable ${sService}/update-rc.d ${sService//.service/} disable/g" "${sFile}") && {
                            /bin/true
                            ((nRes++))
                        }
                    elif (grep -q ' enable' <<<"${sROW}"); then
                        # echo "${sFile}: systemctl enable ${sService} --> update-rc.d ${sService//.service/} enable"
                        (! sed -i -e "s/systemctl enable ${sService}/update-rc.d ${sService//.service/} enable/g" "${sFile}") && {
                            /bin/true
                            ((nRes++))
                        }
                    else
                        # echo "${sFile}: systemctl ${sSwitch} ${sService} --> service ${sService//.service/} ${sSwitch}"
                        (! sed -i -e "s/systemctl ${sSwitch} ${sService}/service ${sService//.service/} ${sSwitch}/g" "${sFile}") && {
                            /bin/true
                            ((nRes++))
                        }
                    fi
                done < <(grep 'systemctl ' "${sFile}")

                # shellcheck disable=SC2181
                if [[ ${nRes} -eq 0 ]]; then
                    echo -e "${CYELLOW}${sFile}:${CEND} ${CGREEN}Passed${CEND}"
                else
                    echo -e "${CYELLOW}${sFile}:${CEND} ${CRED}Failed${CEND}"
                    nReturn=$((nReturn + 1))
                fi
            done
        fi

        [[ ${nReturn} -gt 0 ]] && exit "${nReturn}"
        ;;
esac

case "${CHECK_METHOD}" in
    'full' | 'install' | 'integ')
        #### Start install
        bash "${sDirToScan}"/install/MySB_Install.bsh 'fr'
        ;;
esac

case "${CHECK_METHOD}" in
    'integ' | 'full' | 'install')
        # shellcheck source=/dev/null
        . /etc/MySB/config
        sFilesList="$(find "${MySB_InstallDir}"/inc/funcs_by_script/ -type f)"
        if [ -n "${sFilesList}" ]; then
            echo && echo -e "${CBLUE}*** Validate some functions ***${CEND}"
            # shellcheck source=/dev/null
            . "${MySB_InstallDir}"/inc/vars
            for sFile in ${sFilesList}; do
                # shellcheck source=/dev/null
                if (. "${sFile}"); then
                    echo -e "${CYELLOW}Loading: ${sFile}${CEND} ${CGREEN}Passed${CEND}"
                else
                    echo -e "${CYELLOW}Loading: ${sFile}${CEND} ${CRED}Failed${CEND}"
                    nReturn=$((nReturn + 1))
                fi
            done

            # gfnStatistics
            gfnStatistics
            if [ ! -f "${MySB_InstallDir}"/statistics ] || (! grep -q '77ae4c9263e68f87596f9a57b6cab4870102e8af0e88eaf3de660deed69df673' "${MySB_InstallDir}"/statistics); then
                echo -e "${CYELLOW}gfnStatistics${CEND} ${CRED}Failed${CEND}"
                nReturn=$((nReturn + 1))
            else
                echo -e "${CYELLOW}gfnStatistics${CEND} ${CGREEN}Passed${CEND}"
            fi

            # gfnValidateMail
            if (! gfnValidateMail 'toulousain79@github.com'); then
                echo -e "${CYELLOW}gfnValidateMail${CEND} ${CRED}Failed${CEND}"
                nReturn=$((nReturn + 1))
            else
                echo -e "${CYELLOW}gfnValidateMail${CEND} ${CGREEN}Passed${CEND}"
            fi

            # gfnValidateIP
            [ -z "$(gfnValidateIP 192.168.0.1)" ] && nReturn=$((nReturn + 1))
            [ -n "$(gfnValidateIP 192.168.0.333)" ] && nReturn=$((nReturn + 1))
            if [ -z "$(gfnValidateIP 192.168.0.1)" ] || [ -n "$(gfnValidateIP 192.168.0.333)" ]; then
                echo -e "${CYELLOW}gfnValidateIP${CEND} ${CRED}Failed${CEND}"
                nReturn=$((nReturn + 1))
            else
                echo -e "${CYELLOW}gfnValidateIP${CEND} ${CGREEN}Passed${CEND}"
            fi

            # gfnPackageBundleInstall
            if [ "$(gfnPackageBundleInstall "dos2unix")" != "dos2unix is already installed !" ]; then
                echo -e "${CYELLOW}gfnPackageBundleInstall${CEND} ${CRED}Failed${CEND}"
                nReturn=$((nReturn + 1))
            else
                echo -e "${CYELLOW}gfnPackageBundleInstall${CEND} ${CGREEN}Passed${CEND}"
            fi

            # gfnPackagesManage
            if (! gfnPackagesManage 'upgrade'); then
                echo -e "${CYELLOW}gfnPackagesManage 'upgrade'${CEND} ${CRED}Failed${CEND}"
                nReturn=$((nReturn + 1))
            else
                echo -e "${CYELLOW}gfnPackagesManage 'upgrade'${CEND} ${CGREEN}Passed${CEND}"
            fi
            if (! gfnPackagesManage 'dist-upgrade'); then
                echo -e "${CYELLOW}gfnPackagesManage 'dist-upgrade'${CEND} ${CRED}Failed${CEND}"
                nReturn=$((nReturn + 1))
            else
                echo -e "${CYELLOW}gfnPackagesManage 'dist-upgrade'${CEND} ${CGREEN}Passed${CEND}"
            fi
            if (! gfnPackagesManage 'install' 'vim'); then
                echo -e "${CYELLOW}gfnPackagesManage 'install' 'vim'${CEND} ${CRED}Failed${CEND}"
                nReturn=$((nReturn + 1))
            else
                echo -e "${CYELLOW}gfnPackagesManage 'install' 'vim'${CEND} ${CGREEN}Passed${CEND}"
            fi
            if (! gfnPackagesManage 'purge' 'vim'); then
                echo -e "${CYELLOW}gfnPackagesManage 'purge' 'vim'${CEND} ${CRED}Failed${CEND}"
                nReturn=$((nReturn + 1))
            else
                echo -e "${CYELLOW}gfnPackagesManage 'purge' 'vim'${CEND} ${CGREEN}Passed${CEND}"
            fi

            # gfnFail2BanWhitheList
            gfnFail2BanWhitheList
            if [ -f /etc/fail2ban/jail.local ]; then
                md5sum /etc/fail2ban/jail.local
                if [ "$(md5sum /etc/fail2ban/jail.local)" != "7ba9728c9b02ffc6c26ac97bb871dafb  /etc/fail2ban/jail.local" ]; then
                    nReturn=$((nReturn + 1))
                fi
            else
                nReturn=$((nReturn + 1))
            fi
            if [[ ${nReturn} -ne 0 ]]; then
                echo -e "${CYELLOW}gfnFail2BanJailLocal${CEND} ${CRED}Failed${CEND}"
            else
                echo -e "${CYELLOW}gfnFail2BanJailLocal${CEND} ${CGREEN}Passed${CEND}"
            fi
        fi
        ;;
esac

export nReturn

##################### LAST LINE ######################################