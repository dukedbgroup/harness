#!/bin/bash
##! @AUTHOR:    dongfei@cs.duke.edu

GROUP='test-cluster'
NUM=1
EC2_PK="$HOME/.ec2/benchmark.pem"
PWD="$HOME/code/harness"
STARFISH_HOME="$HOME/code/Starfish/starfish"
HARNESS_HOME="$HOME/code/harness"
source $HOME/.bash_profile

start_instance()
{
    ${HADOOP_EC2_HOME}/hadoop-ec2 launch-cluster $GROUP $NUM $instance_type
}

terminate_instance()
{
    ${HADOOP_EC2_HOME}/hadoop-ec2 terminate-cluster $GROUP
    ${HADOOP_EC2_HOME}/hadoop-ec2 delete-cluster $GROUP
}

prepare()
{
    cd $STARFISH_HOME
#    git pull; ant clean; ant 
#    cd $STARFISH_HOME/contrib/examples; ant; cd -
#    cp $STARFISH_HOME/contrib/examples/hadoop-starfish-examples.jar $STARFISH_HOME/build
#    rm -rf build.tar.gz
#    tar czvf build.tar.gz build; 
    cd -
}

upload() 
{
    ${HADOOP_EC2_HOME}/hadoop-ec2 push $GROUP $STARFISH_HOME/build.tar.gz
    ${HADOOP_EC2_HOME}/hadoop-ec2 push $GROUP $HARNESS_HOME/benchmark/run.sh
}

execute_job() 
{
    ssh -i $EC2_PK -q -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no root@$machine_addr ' bash run.sh all'
    scp -i $EC2_PK -q -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no root@$machine_addr:/root/profiles.tar.gz output/profiles.$instance_type.tar.gz
}

main() 
{
    instance_type=$1
    start_instance
    sleep 60
    machine_addr=`cat $HOME/.hadooop-$GROUP-master`
    echo "machine addr:" $machine_addr
    if [ "$machine_addr" != "" ]; then
        prepare
        upload
        execute_job
    fi
    terminate_instance
    > $HOME/.hadooop-$GROUP-master
}

names="m1.large m1.xlarge c1.xlarge"
#names="m1.small c1.medium"
for instance_type in $names; do
    echo $instance_type
    main $instance_type
    break
done
