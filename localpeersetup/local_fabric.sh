#!/bin/bash

PEER_IMAGE=rameshthoomu/peer:latest
MEMBERSRVC_IMAGE=rameshthoomu/membersrvc:latest
REST_PORT=5000
USE_PORT=30000
#PEER_IMAGE=pushdocker/working:vagrant2
#OBCCA_IMAGE=pushdocker/obcca:vagrant2

CONSENSUS=pbft
PBFT_MODE=batch
WORKDIR=$(pwd)

#
membersrvc_setup()
{
curl -L https://raw.githubusercontent.com/hyperledger/fabric/master/membersrvc/membersrvc.yaml -o membersrvc.yaml

local NUM_PEERS=$1
local IP=$2
local PORT=$3
echo "--------> Starting membersrvc Server"

docker run -d --name=caserver -p 50051:50051 -p 50052:30303 -it $MEMBERSRVC_IMAGE membersrvc

echo "--------> Starting hyperledger PEER0"

docker run -d --name=PEER0 -it \
                -e CORE_VM_ENDPOINT="http://$IP:$PORT" \
                -e CORE_PEER_ID="vp0" \
                -e CORE_SECURITY_ENABLED=true \
                -e CORE_SECURITY_PRIVACY=true \
                -e CORE_PEER_ADDRESSAUTODETECT=false -p $REST_PORT:5000 -p `expr $USE_PORT + 1`:30303 \
                -e CORE_PEER_ADDRESS=$IP:`expr $USE_PORT + 1` \
                -e CORE_PEER_PKI_ECA_PADDR=$IP:50051 \
                -e CORE_PEER_PKI_TCA_PADDR=$IP:50051 \
                -e CORE_PEER_PKI_TLSCA_PADDR=$IP:50051 \
                -e CORE_PEER_LISTENADDRESS=0.0.0.0:30303 \
                -e CORE_PEER_VALIDATOR_CONSENSUS_PLUGIN=$CONSENSUS \
                -e CORE_PBFT_GENERAL_MODE=$PBFT_MODE \
                -e CORE_PBFT_GENERAL_TIMEOUT_REQUEST=10s \
                -e CORE_PEER_LOGGING_LEVEL=error \
                -e CORE_VM_DOCKER_TLS_ENABLED=false \
                -e CORE_SECURITY_ENROLLID=test_vp0 \
                -e CORE_SECURITY_ENROLLSECRET=MwYpmSRjupbT $PEER_IMAGE peer peer

CONTAINERID=$(docker ps | awk 'NR>1 && $NF!~/caserv/ {print $1}')
PEER_IP_ADDRESS=$(docker inspect --format '{{.NetworkSettings.IPAddress}}' $CONTAINERID)

for (( peer_id=1; $peer_id<"$NUM_PEERS"; peer_id++ ))
do
# Storing USER_NAME and SECRET_KEY Values from membersrvc.yaml file

USER_NAME=$(awk '/users:/,/^[^ ]/' membersrvc.yaml | egrep "test_vp$((peer_id)):" | cut -d ":" -f 1 | tr -d " ")
SECRET_KEY=$(awk '/users:/,/^[^ ]/' membersrvc.yaml | egrep "test_vp$((peer_id)):" | cut -d ":" -f 2 | cut -d " " -f 3)
REST_PORT=`expr $REST_PORT + 1`
USE_PORT=`expr $USE_PORT + 2`

echo "--------> Starting hyperledger PEER$peer_id <-----------"

docker run  -d --name=PEER$peer_id -it \
                -e CORE_VM_ENDPOINT="http://$IP:$PORT" \
                -e CORE_PEER_ID="vp"$peer_id \
                -e CORE_SECURITY_ENABLED=true \
                -e CORE_SECURITY_PRIVACY=true \
                -e CORE_PEER_ADDRESSAUTODETECT=true -p $REST_PORT:5000 -p `expr $USE_PORT + 1`:30303 \
                -e CORE_PEER_DISCOVERY_ROOTNODE=$IP:30001 \
                -e CORE_PEER_PKI_ECA_PADDR=$IP:50051 \
                -e CORE_PEER_PKI_TCA_PADDR=$IP:50051 \
                -e CORE_PEER_PKI_TLSCA_PADDR=$IP:50051 \
                -e CORE_PEER_LISTENADDRESS=0.0.0.0:30303 \
                -e CORE_PEER_VALIDATOR_CONSENSUS_PLUGIN=$CONSENSUS \
                -e CORE_PBFT_GENERAL_MODE=$PBFT_MODE \
                -e CORE_PEER_LOGGING_LEVEL=error \
                -e CORE_PBFT_GENERAL_TIMEOUT_REQUEST=10s \
                -e CORE_VM_DOCKER_TLS_ENABLED=false \
                -e CORE_VM_DOCKER_TLS_ENABLED=false \
                -e CORE_SECURITY_ENROLLID=$USER_NAME \
                -e CORE_SECURITY_ENROLLSECRET=$SECRET_KEY $PEER_IMAGE peer peer
done
}

peer_setup()

{

    local  NUM_PEERS=$1
    local  IP=$2
    local  PORT=$3
echo "--------> Starting hyperledger PEER0 <-----------"
docker run -d  -it --name=PEER0 \
                -e CORE_VM_ENDPOINT="http://$IP:$PORT" \
                -e CORE_PEER_ID="vp0" \
                -p $REST_PORT:5000 -p `expr $USE_PORT + 1`:30303 \
                -e CORE_PEER_ADDRESSAUTODETECT=true \
                -e CORE_PEER_LISTENADDRESS=0.0.0.0:30303 \
                -e CORE_PEER_LOGGING_LEVEL=error \
                -e CORE_VM_DOCKER_TLS_ENABLED=false $PEER_IMAGE peer peer

CONTAINERID=$(docker ps | awk 'NR>1 && $NF!~/caserv/ {print $1}')
PEER_IP_ADDRESS=$(docker inspect --format '{{.NetworkSettings.IPAddress}}' $CONTAINERID)

for (( peer_id=1; peer_id<"$NUM_PEERS"; peer_id++ ))
do
#Hardcoded NAT-ed port and API port ====>>> list
echo "--------> Starting hyperledger PEER$peer_id <------------"
REST_PORT=`expr $REST_PORT + 1`
USE_PORT=`expr $USE_PORT + 2`

docker run -d -it --name=PEER$peer_id \
                -e CORE_VM_ENDPOINT="http://$IP:$PORT" \
                -e CORE_PEER_ID="vp"$peer_id \
                -p $REST_PORT:5000 -p `expr $USE_PORT + 1`:30303 \
                -e CORE_PEER_ADDRESSAUTODETECT=false \
                -e CORE_PEER_ADDRESS=$IP:`expr $USE_PORT + 1` \
                -e CORE_PEER_DISCOVERY_ROOTNODE=$IP:30001 \
                -e CORE_PEER_LISTENADDRESS=0.0.0.0:30303 \
                -e CORE_PEER_LOGGING_LEVEL=error \
                -e CORE_VM_DOCKER_TLS_ENABLED=false $PEER_IMAGE peer peer
done
}

while getopts "\?hsn:" option; do
  case "$option" in
     s)   SECURITY="Y"           ;;
     n)   NUM_PEERS="$OPTARG" ;;
   \?|h)  usage
          exit 1
          ;;
  esac
done


#let's clean house

#kill all running containers and LOGFILES...This may need to be revisited.
docker kill $(docker ps -q) 1>/dev/null 2>&1
docker ps -aq -f status=exited | xargs docker rm 1>/dev/null 2>&1
rm LOG*


echo "--------> Setting default command line Arg values to without security & consensus and starts 5 peers"
: ${SECURITY:="N"}
: ${NUM_PEERS="5"}
SECURITY=$(echo $SECURITY | tr a-z A-Z)

echo "Number of PEERS are $NUM_PEERS"
if [ $NUM_PEERS -le 0 ] ; then
        echo "Enter valid number of PEERS"
        exit 1
fi

echo "Is Security and Privacy enabled $SECURITY"

Dockerps_ID=$(ps -ef | grep docker | grep daemon | awk '{print $3}')
echo $Dockerps_ID
if [[ $Dockerps_ID -ne 1 ]] ; then echo " Docker daemon is not running " ; exit 1 ; else echo "Docker daemon is running" ; fi

echo "--------> Pulling Docker Images from Docker Hub"
docker pull rameshthoomu/working:baseimagelatest
docker tag rameshthoomu/working:baseimagelatest hyperledger/fabric-baseimage:latest
#curl -L https://github.com/rameshthoomu/fabric/blob/master/scripts/provision/common.sh -o common.sh
#curl -L https://raw.githubusercontent.com/rameshthoomu/fabric/master/scripts/provision/docker.sh -o docker.sh
#chmod +x docker.sh
#sudo ./docker.sh 0.0.9

if [ "$SECURITY" == "Y" ] ; then
        echo "--------> Fetching IP address"
        IP="$(ifconfig docker0 | grep "inet" | awk '{print $2}' | cut -d ':' -f 2)"
        echo "Docker0 interface IP Address $IP"
        echo "--------> Fetching PORT number"
        PORT="$(sudo netstat -tunlp | grep docker | awk '{print $4'} | cut -d ":" -f 4)"
        echo "PORT NUMBER IS $PORT"
        echo "--------> Calling membersrvc_setup function"
        membersrvc_setup $NUM_PEERS $IP $PORT

else

        IP="$(ifconfig docker0 | grep "inet" | awk '{print $2}' | cut -d ':' -f 2)"
        echo "Docker0 interface IP Address $IP"
        PORT="$(sudo netstat -tunlp | grep docker | awk '{print $4'} | cut -d ":" -f 4)"
        echo "PORT NUMBER IS $PORT"
        echo "--------> Calling CORE PEER function"
        peer_setup $NUM_PEERS $IP $PORT
fi

echo "--------> Printing list of Docker Containers"
CONTAINERS=$(docker ps | awk 'NR>1 && $NF!~/caserv/ {print $1}')
echo $CONTAINERS
NUM_CONTAINERS=$(echo $CONTAINERS | awk '{FS=" "}; {print NF}')
echo $NUM_CONTAINERS

# Printing Log files
for (( container_id=1; $container_id<="$((NUM_CONTAINERS))"; container_id++ ))
do
        CONTAINER_ID=$(echo $CONTAINERS | awk -v con_id=$container_id '{print $con_id}')
    #    echo "Container ID $CONTAINER_ID"
    #    echo "-----------> Printing Log file in detached mode for Container"$CONTAINER_ID
        docker logs -f $CONTAINER_ID > "LOGFILE_"$CONTAINER_ID &
done

# Writing Peer data into a file for Go SDK
cd $WORKDIR
touch networkcredentials
echo "{" > $WORKDIR/networkcredentials
echo "   \"PeerData\" :  [" >> $WORKDIR/networkcredentials
echo " "
echo "PeerData : "

echo "----------> Printing Container ID's with IP Address and PORT numbers"


#for (( container_id=1; $container_id<="$((NUM_CONTAINERS-1))"; container_id++ ))
for (( container_id=1; $container_id<="$((NUM_CONTAINERS))"; container_id++ ))
do

        CONTAINER_ID=$(echo $CONTAINERS | awk -v con_id=$container_id '{print $con_id}')
        CONTAINER_NAME=$(docker inspect --format '{{.Name}}' $CONTAINER_ID |  sed 's/\///')
        echo "Container ID $CONTAINER_ID   Peer Name: $CONTAINER_NAME"

        peer_http_ip=$(docker inspect --format '{{.NetworkSettings.IPAddress}}' $CONTAINER_ID)
        api_host=$peer_http_ip
        api_port=$(docker inspect --format='{{(index (index .NetworkSettings.Ports "5000/tcp") 0).HostPort}}' $CONTAINER_ID)
        echo "   { \"api_host\" : \"$api_host\", \"api_port\" : \"$api_port\" } , " >> $WORKDIR/networkcredentials
        echo " REST_EndPoint : $api_host:$api_port"


        api_port_grpc=$(docker inspect --format='{{(index (index .NetworkSettings.Ports "30303/tcp") 0).HostPort}}' $CONTAINER_ID)
        echo " GRPC_EndPoint : $api_host:$api_port_grpc"
        echo " "

done

echo "Client Credentials : "

        for ((i=0; i<=$NUM_CONTAINERS-1;i++))
        do
        CLIENT_USER=$(awk '/users:/,/^[^ ]/' membersrvc.yaml | egrep "test_user$((i)):" | cut -d ":" -f 1 | tr -d " ")
        CLIENT_SECRET_KEY=$(awk '/users:/,/^[^ ]/' membersrvc.yaml | egrep "test_user$((i)):" | cut -d ":" -f 2 | cut -d " " -f 3)
        echo "Client_username: $CLIENT_USER  client_secretkey : $CLIENT_SECRET_KEY"

done

        container_id=1
        CONTAINER_ID=$(echo $CONTAINERS | awk -v con_id=$container_id '{print $con_id}')

#        peer_http_ip=$(docker inspect --format '{{.NetworkSettings.IPAddress}}' $CONTAINER_ID)
        api_host=$IP
        api_port=$(docker inspect --format='{{(index (index .NetworkSettings.Ports "5000/tcp") 0).HostPort}}' $CONTAINER_ID)

echo "   { \"api_host\" : \"$api_host\", \"api_port\" : \"$api_port\" }  " >> $WORKDIR/networkcredentials
echo "   ]"  >> $WORKDIR/networkcredentials

echo "} "  >> $WORKDIR/networkcredentials

echo "{" >> $WORKDIR/networkcredentials
echo "   \"UserData\" :  [" >> $WORKDIR/networkcredentials

echo " "
echo "Peer Credentials : "
for (( container_id=1; $container_id<="$((NUM_CONTAINERS))"; container_id++ ))
do

        CONTAINER_ID=$(echo $CONTAINERS | awk -v con_id=$container_id '{print $con_id}')
#        echo "Container ID $CONTAINER_ID"

        username=$(docker inspect $CONTAINER_ID | awk '/CORE_SECURITY_ENROLLID/ {sub(/.*=/,""); sub(/".*/,""); print}')
        secret=$(docker inspect $CONTAINER_ID | awk '/CORE_SECURITY_ENROLLSECRET/ {sub(/.*=/,""); sub(/".*/,""); print}')

echo "Peer_username: $username secret: $secret "
        echo "   { \"Peer_username\" : \"$Peer_username\", \"secret\" : \"$secret\" } , " >> $WORKDIR/networkcredentials

done
        container_id=1
        CONTAINER_ID=$(echo $CONTAINERS | awk -v con_id=$container_id '{print $con_id}')
      #  echo "Container ID $CONTAINER_ID"

        username=$(docker inspect $CONTAINER_ID | awk '/CORE_SECURITY_ENROLLID/ {sub(/.*=/,""); sub(/".*/,""); print}')

        secret=$(docker inspect $CONTAINER_ID | awk '/CORE_SECURITY_ENROLLSECRET/ {sub(/.*=/,""); sub(/".*/,""); print}')
echo "   { \"username\" : \"$username\", \"secret\" : \"$secret\" } " >> $WORKDIR/networkcredentials

echo "   ]"  >> $WORKDIR/networkcredentials

echo "} "  >> $WORKDIR/networkcredentials
