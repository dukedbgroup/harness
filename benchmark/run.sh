#!/bin/bash

init()
{
    rm -rf build
    tar xzvf build.tar.gz
    source .bash_profile
    ./build/bin/install_btrace.sh /root/SLAVE_NAMES.txt
}

terasort()
{
    ${HADOOP_HOME}/bin/hadoop jar /root/build/hadoop-starfish-examples.jar teragen -Dmapred.map.tasks=100 10000000 ~/tera/in
    /root/build/bin/profile jar /root/build/hadoop-starfish-examples.jar terasort -Dmapred.reduce.task=10 ~/tera/in ~/tera/out
}

wordcount() 
{
    # 50M * 2 * nodes
    ${HADOOP_HOME}/bin/hadoop jar /root/build/hadoop-starfish-examples.jar randomtextwriter -Dtest.randomtextwrite.bytes_per_map=52428800 -Dtest.randomtextwrite.maps_per_host=2 -Dtest.randomtextwrite.min_words_value=5 -Dtest.randomtextwrite.max_words_value=10 ~/wordcount/in
    /root/build/bin/profile jar /root/build/hadoop-starfish-examples.jar wordcount ~/wordcount/in ~/wordcount/out
}

collect()
{
    tar czvf profiles.tar.gz results
}

if [[ $# = 0 ]];then
    echo "usage: $0 [all|terasort|wordcount]"
    exit 1
fi
for i in "$@"; do
    case $i in
    all)
        init
        terasort; wordcount
        collect
        ;;  
    terasort)
        init
        terasort
        collect
        ;;  
    wordcount)
        init
        wordcount
        collect
        ;;  
    *)
        echo "usage: $0 [all|terasort|wordcount]"
        exit 1
    esac
done
