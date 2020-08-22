#!/bin/bash -x

#cd $HOME/catkin_ws/src/burger_war
#BURGER_WAR_REPOSITORY=$HOME/catkin_ws/src/burger_war
RESULTLOG=$HOME/catkin_ws/result.log
SRC_LOG=$RESULTLOG 
BURGER_WAR_AUTOTEST_LOG_REPOSITORY=$HOME/catkin_ws/burger_war_autotest2
DST_LOG=$BURGER_WAR_AUTOTEST_LOG_REPOSITORY/result/result-20200820.log
LATEST_GITLOG_HASH="xxxx"

echo "iteration, enemy_name, game_time(s), date, my_score, enemy_score, battle_result" > $RESULTLOG

LOOP_TIMES=1

function do_game(){
    ITERATION=$1
    ENEMY_LEVEL=4 # invalid default enemy launch
    ENEMY_NAME=$2
    GAME_TIME=$3

    #start
    pushd burger_war
    gnome-terminal -e "bash scripts/sim_with_judge.sh"
    sleep 30
    gnome-terminal -e "bash scripts/start.sh -l ${ENEMY_LEVEL}"
    popd
    pushd burger_war_seigot
    gnome-terminal -e "bash scripts/start.sh -l ${ENEMY_LEVEL}"

    #wait game finish
    sleep $GAME_TIME

    #get result
    timeout 30s python ~/catkin_ws/src/burger_war_seigot/autotest/get_score.py > out.log
    # MY_SCORE=enemy_score, mybot work on enemy_bot side
    MY_SCORE=`cat out.log | grep -w enemy_score | cut -d'=' -f2`
    ENEMY_SCORE=`cat out.log | grep -w my_score | cut -d'=' -f2`
    DATE=`date --iso-8601=seconds`
    BATTLE_RESULT="LOSE"
    if [ $MY_SCORE -gt $ENEMY_SCORE ]; then
	BATTLE_RESULT="WIN"
    fi

    #output result
    echo "$ITERATION, $ENEMY_NAME, $GAME_TIME, $DATE, $MY_SCORE, $ENEMY_SCORE, $BATTLE_RESULT" >> $RESULTLOG
    tail -1 $RESULTLOG
    
    #stop
    PROCESS_ID=`ps -e -o pid,cmd | grep start.sh | grep -v grep | awk '{print $1}'`
    kill $PROCESS_ID
    PROCESS_ID=`ps -e -o pid,cmd | grep sim_with_judge.sh | grep -v grep | awk '{print $1}'`
    kill $PROCESS_ID
    PROCESS_ID=`ps -e -o pid,cmd | grep judgeServer.py | grep -v grep | awk '{print $1}'`
    kill $PROCESS_ID
    PROCESS_ID=`ps -e -o pid,cmd | grep visualizeWindow.py | grep -v grep | awk '{print $1}'`
    kill $PROCESS_ID
    sleep 30
}

function check_latest_hash(){
    # check latest hash
    pushd $BURGER_WAR_REPOSITORY
    git pull
    GITLOG_HASH=`git log | head -1 | cut -d' ' -f2`
    if [ "$GITLOG_HASH" != "$LATEST_GITLOG_HASH" ];then
	echo "#--> latest commit:$GITLOG_HASH" >> $RESULTLOG
	LATEST_GITLOG_HASH=$GITLOG_HASH
    fi
    popd
}

function do_push(){

    # push
    pushd $BURGER_WAR_AUTOTEST_LOG_REPOSITORY/result
    git pull
    cp $SRC_LOG $DST_LOG
    git add $DST_LOG
    git commit -m "result.log update"
    git push

    #prepare
    bash prepare.sh
    popd
}

REPOSITORY_LIST=(
    "https://github.com/BolaDeArroz/burger_war"
    #"https://github.com/CollegeFriends/burger_war"
    #"https://github.com/raucha/burger_war"
    #"https://github.com/F0CACC1A/burger_war"
    #"https://github.com/dnrtk/burger_war"
    #"https://github.com/K-Shima-0325/burger_war"
    #"https://github.com/sugarman1983/burger_war"
    #"https://github.com/yshimomura/burger_war"
    #"https://github.com/Gantetsu-robocon/burger_war"
    #"https://github.com/kanemotohidekatsu/burger_war"
    #"https://github.com/nakanishi-keita001/qqq/"
    #"https://github.com/tsuburin/burger_war"
    #"https://github.com/JinruiMinaDaito/burger_war"
    #"https://github.com/kyad/burger_war_20200818"
    #"https://github.com/safubuki/burger_war"
    ##"https://github.com/airkei/burger_war"
    #"https://github.com/X-Ranger/burger_war"
    #"https://github.com/naoyayosinaga/burger_war"
    #"https://github.com/TEAM-QWERT/burger_war"
    #"https://github.com/rhc-ipponmanzoku/burger_war"
)

function prepare_environment(){
    REPOSITORY=$1
    ENEMY_NAME=$2

    # init & clone
    cd ~/catkin_ws/src
    sudo rm -r burger_war* obstacle_detector                              # delete old directory
    git clone $REPOSITORY burger_war        # clone your repository
    git clone https://github.com/seigot/burger_war burger_war_seigot # clone this repository for enemy_bot
    if [ $ENEMY_NAME != "BolaDeArroz" ];then
	git clone https://github.com/tysik/obstacle_detector.git         # if necessary
    fi
    cd burger_war_seigot
    patch -p1 < autotest/patch/20200822_change_namespace_to_enemy_bot.patch  # apply patch
    cd ~/catkin_ws
    catkin clean --yes   # if necessary, delete old devel/build/log directory
    catkin build
    bash devel/setup.sh
    source ~/.bashrc
}

# main loop
for ((i=0; i<${LOOP_TIMES}; i++));
do
    # battle with all repository
    for (( i = 0; i < ${#REPOSITORY_LIST[@]}; ++i ))
    do
	# prepare
	ENEMY_NAME=`echo ${REPOSITORY_LIST[$i]} | cut -d'/' -f4`
	prepare_environment ${REPOSITORY_LIST[$i]} $ENEMY_NAME

	# game
	cd ~/catkin_ws/src
	#check_latest_hash
	do_game ${i} ${ENEMY_NAME} 225 # 180 * 5/4 
	#do_push
    done
done
