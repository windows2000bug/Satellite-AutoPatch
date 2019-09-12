#!/usr/bin/bash

#Written By D. Israel - Last Update 9/6/2019

#Recommend this be run once a month with similar contab entry:
#0 6 15-21 * * /usr/bin/test $(/usr/bin/date +\%u) -eq 2 && /usr/local/bin/contentView.sh


#Number of unused Content View Versions to be retained
cvCount=3

#Organization Name, if you want to set it manually
#ORG='ORG_COMPANY1234'

#Gets Orginzation Name that isn't named "Default" automatically
ORG=$(hammer --csv organization list | tail -n +2 | grep -vi default | awk -F',' '{print $2}')



#Get Content View Names
IFS=$'\n'
cvNames=($(hammer --csv content-view list | egrep -v 'Default Organization View|Name' | awk -F',' '{print $2}'))
unset IFS

#Get all Life Cycles
lcEnvs=($(hammer --csv lifecycle-environment paths --organization $ORG | tail -n +2 | sed 's/>>//g'))

echo "$(date) Generating new content view" >> /var/log/patching

for i in "${cvNames[@]}"
do
        prevLCE=''
        unset reverseMe
        for s in "${lcEnvs[@]}"
        do
                curVer=''

                #Skip this round, if it is Library.
                if [ "$s" == "Library" ]; then
                        prevLCE="$s"
                        echo "$(date) Top level Lifecycle Environment is $s for $i." >> /var/log/patching
                        continue
                fi

                #Current contentview version ID for this contentview
                curVer=$(hammer --csv content-view version list --content-view $i --environment $prevLCE --organization $ORG | tail -n +2 | awk -F',' '{print $1}')

                #Check to see if Lifecycle Environment exists in org
                newVer=$(hammer --csv content-view version list --content-view $i --environment $s --organization $ORG | tail -n +2 | awk -F',' '{print $1}')
                if [ -n "$newVer" ]; then
                        echo "$(date) Promoting $s Lifecycle Environment for $i" >> /var/log/patching
                        #Build Array  to reverse them to avoid protection errrors.
                        reverseMe+=("hammer content-view version promote --content-view $i --to-lifecycle-environment $s --organization $ORG --id $curVer")
                else
                        echo "$(date) Skipping, no $s Lifecyle Environment for $i" >> /var/log/patching
                        prevLCE="$s"
                        continue
                fi
                prevLCE="$s"
        done

        min=0
        max=$(( ${#reverseMe[@]} -1 ))
        #Loop to reverse order of array to avoid protection errors
        while [[ min -lt max ]]
        do
                x="${reverseMe[$min]}"
                reverseMe[$min]="${reverseMe[$max]}"
                reverseMe[$max]="$x"

                (( min++, max-- ))
        done
        for t in "${reverseMe[@]}"
        do
                #echo $t
                $($t)
        done

        echo "$(date) Publishing new Content View for $i Library" >> /var/log/patching
        #echo "hammer content-view publish --name $i --organization $ORG"
        hammer content-view publish --name $i --organization $ORG

        echo "$(date) Cleanup - Leaving only $cvCount unused Content Views for $i" >> /var/log/patching
        #echo "hammer content-view purge --count $cvCount --name $i --organization $ORG"
        hammer content-view purge --count $cvCount --name $i --organization $ORG

        echo "$(date) $i Tasks Completed" >> /var/log/patching
done
