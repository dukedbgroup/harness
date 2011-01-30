#!/bin/bash 

date
echo 'Downloading the XML dump of wikipedia (6.2 GB)'
mkdir /mnt/wiki
cd /mnt/wiki
wget http://download.wikimedia.org/enwiki/20101011/enwiki-20101011-pages-articles.xml.bz2
bunzip2 enwiki-20101011-pages-articles.xml.bz2

date
echo 'Loading wikipedia to HDFS:/user/root/wiki'
${HADOOP_HOME}/bin/hadoop fs -put \
  /mnt/wiki/enwiki-20101011-pages-articles.xml \
  /user/root/wiki/enwiki-20101011-pages-articles.xml

date
cd /root/aws_hadoop_harness/data_gen/wiki
echo 'Converting the XML dump into a text file in HDFS:/user/root/wiki/txt'
${HADOOP_HOME}/bin/hadoop jar cloud9.jar \
  edu.umd.cloud9.collection.wikipedia.DumpWikipediaToPlainText \
  -libjars lib/bliki-core-3.0.15.jar,lib/commons-lang-2.5.jar \
  /user/root/wiki/enwiki-20101011-pages-articles.xml \
  /user/root/wiki/txt

date
echo 'Converting the XML dump into block-compressed SequenceFiles'
${HADOOP_HOME}/bin/hadoop jar cloud9.jar \
  edu.umd.cloud9.collection.wikipedia.BuildWikipediaDocnoMapping \
  -libjars lib/bliki-core-3.0.15.jar,lib/commons-lang-2.5.jar \
  /user/root/wiki/enwiki-20101011-pages-articles.xml \
  /user/root/wiki/tmp \
  /user/root/wiki/docno-en-20101011.dat 100

${HADOOP_HOME}/bin/hadoop jar cloud9.jar \
  edu.umd.cloud9.collection.wikipedia.RepackWikipedia \
  -libjars lib/bliki-core-3.0.15.jar,lib/commons-lang-2.5.jar \
  /user/root/wiki/enwiki-20101011-pages-articles.xml \
  /user/root/wiki/files \
  /user/root/wiki/docno-en-20101011.dat block

date
echo 'Building the wikipedia link graph'
${HADOOP_HOME}/bin/hadoop jar cloud9.jar \
  edu.umd.cloud9.collection.wikipedia.BuildWikipediaLinkGraph \
  -libjars lib/bliki-core-3.0.15.jar,lib/commons-lang-2.5.jar \
  /user/root/wiki/files \
  /user/root/wiki/edges \
  /user/root/wiki/adjacency 10

${HADOOP_HOME}/bin/hadoop jar cloud9.jar \
  edu.umd.cloud9.example.bfs.EncodeBFSGraph \
  /user/root/wiki/adjacency \
  /user/root/wiki/bfs/iter0000 12

date

