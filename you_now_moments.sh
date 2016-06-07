#!/bin/bash

declare -a moments # bash don't support mutlideminsional arrays. use a row/ columm offset approach instead.
declare moments_count
columnsM=4
id=44

# Handle building the menu and user inputs for displaying the moments avialable
# and allowing the user to download specific moments.
#
# @param: user name
# @param: user id
function downloadMomentsMenu()
{
    local user_name=$1
    local user_id=$2
    local ex="false"

    wget --no-check-certificate -q "https://www.younow.com/php/api/moment/profile/channelId=${user_id}/createdBefore=0/records=50" -O "./_temp/${user_name}_moments.json"
    parseMomentJson "./_temp/${user_name}_moments.json"

    while [ "$ex" == "false" ]; do
        displayUserBroadcastWithMoments $user_name

        echo "Enter the ID to see available moments."
        read input_broadcast

        if [ "$input_broadcast" == "" ]; then
            ex="true"
        else
            echo " "
            displayBroadcastsMoments $input_broadcast
            broadcast_id=${moments[ $[ ${input_broadcast} * ${columnsM} + 1 ] ]}
            
            local inner_ex="false"
            while [ "$inner_ex" == "false" ]; do
                echo "Type comma separated numbers, \"all\" to download everything."
                read input_moment
                if [ "$input_moment" == "" ]; then
                    inner_ex="true"

                else
                    moments_to_download=( )
                    if [ "$input_moment" == "all" ]; then
                        IFS=', ' read -r -a moments_to_download <<< "${moments[ $[ ${input_broadcast} * ${columnsM} + 3 ] ]}"
                    else
                        IFS=', ' read -r -a moments_to_download <<< "${input_moment}"
                    fi

                    for moment_id in ${moments_to_download[@]}; do
                        echo "downloadMoment <$user_name> <$broadcast_id> <$moment_id>"
                        downloadMoment ${user_name} ${broadcast_id} ${moment_id}
                    done
                fi
            done
        fi
    done
}

# Display a selection ID along with the broadcast id and moment count
# that are available to be explored by the user.
#
# @param: user name
# @param(global): moments
# @param(global): moments_count
function displayUserBroadcastWithMoments() 
{
    printf "Broadcasts with Moments Available for $user_name \n"
    printf "    ID    Broadcast id   Moment count"
    local counter="0"
    while [ $counter -lt "${moments_count}" ]
    do
        printf "  %4s    %10s         %3s \n" ${moments[$[ $counter * ${columnsM} + 0 ]]} ${moments[$[ $counter * ${columnsM} + 1 ]]} ${moments[$[ $counter * ${columnsM} + 2 ]]}
        counter=$[$counter + 1]
    done
}

# Display the moment_ids which are available for the selected video
#
# @param: broadcast index into {moments[@]}
function displayBroadcastsMoments()
{
    local broadcast_index=$1
    printf " Moment_id\n"
    local moment_id_collection=${moments[ $[ ${broadcast_index} * ${columnsM} + 3 ] ]}

    IFS=','
    for i in $moment_id_collection
    do
        printf "  %4s \n" ${i} 
    done
}


# Download information about the user's moments from the server. Make this information
# available to the moments menuing system via a global variable. (Because bash does not
# support returning an array from a function.)
#
# @param: moments json file
# @return(global -> moments): Array of details about the available moments
# @return(gloabl -> moments_count): The number of broadcasts with available moments to be downloaded
function parseMomentJson() 
{
    local moment_json_file=$1
    unset moments   
    local counter="0"
    local index="1"

    ############# read the moment information retrieved from the server #############
    local broadcast_ids=$(xidel -q -e '($json).items()/join((broadcastId),"-")' "./$moment_json_file" | tr "\n" " ")
    broadcast_ids=( $broadcast_ids )
    
    ############# for each broadcast #############
    while [ $counter -lt "${#broadcast_ids[@]}" ]
    do
        ############# gather up details about this broadcast's moments #############
        moment_index=$[${counter} +1]
        broadcast_moment_ids=$(xidel -q -e '($json).items('${moment_index}').momentsIds()' "./$moment_json_file" | tr "\n" " ")
        broadcast_moment_ids=( $broadcast_moment_ids )
        broadcast_moment_count="${#broadcast_moment_ids[@]}"
        
        if [ "${broadcast_moment_count}" -ne 0 ]
        then
            # four entries per broadcast
            moments[$[ ${index} * ${columnsM} + 0 ]]="${index}"
            moments[$[ ${index} * ${columnsM} + 1 ]]="${broadcast_ids[$counter]}"
            moments[$[ ${index} * ${columnsM} + 2 ]]="${broadcast_moment_count}"
            moments[$[ ${index} * ${columnsM} + 3 ]]=$(IFS=, ; echo "${broadcast_moment_ids[*]}")
            index=$[$index + 1]
        fi
        counter=$[$counter + 1]
    done
    moments_count=${index}
}

# Download a moment (portion of a video).
#
# @param: user name
# @param: broadcast id
# @param: moment id
function downloadMoment() 
{
    local user_name=$1
    local broadcast_id=$2
    local moment_id=$3

    mkdir -p "./videos/$user_name"

    local filename=$(findNextAvailableFileName ${user_name} "${broadcast_id}_moment" ${moment_id} "mkv")

    # Execute the command
    if [ "$mac" == "" ] 
    then
        xterm -e "ffmpeg -i \"https://hls.younow.com/momentsplaylists/live/${moment_id}/${moment_id}.m3u8\"  -c:v copy \"./videos/${user_name}/${filename}\";bash;exit" &
    else
        echo "cd `pwd`;  ffmpeg -hide_banner -y -loglevel panic -stats -i \"https://hls.younow.com/momentsplaylists/live/${moment_id}/${moment_id}.m3u8\"  -c copy \"./videos/${user_name}/${filename}\" "  > "./_temp/${filename}_moment.command"
        chmod +x "./_temp/${filename}_moment.command"
        open "./_temp/${filename}_moment.command"
    fi
}
