#export DOCKERSHA=`docker inspect --format='{{index .RepoDigests 0}}' ${SKAFFOLD_IMAGE}`
export DHURL="https://console.deployhub.com"
export DHUSER=eddiewebb-ci
export DHPASS=logincci
export BUILD_OR_DEPLOY=${1:-"build"}

echo "++++++++++"
echo "action: $BUILD_OR_DEPLOY"
if [ "$BUILD_OR_DEPLOY" = "deploy" ];then
    shift
    DEPLOY_ENV=${1:-"dev"}
    cho "DEPLOY_ENV: ${DEPLOY_ENV}"
else    
    BUILD_OR_DEPLOY=build
    export DOCKERSHA=`docker manifest inspect ${SKAFFOLD_IMAGE} | jq -r '.config.digest'`
    export DOCKERREPO=${SKAFFOLD_IMAGE%":$SKAFFOLD_IMAGE_TAG"}
    export IMAGE_TAG=${SKAFFOLD_IMAGE_TAG}  #skafoold sets from git tree specific sha
    export PROJECT_DIR=${1:-$SKAFFOLD_BUILD_CONTEXT}
    echo "REPO: ${SKAFFOLD_IMAGE_REPO}"
    echo "IMAGE: ${SKAFFOLD_IMAGE}"
    echo "TAG: ${SKAFFOLD_IMAGE_TAG}"
    echo "NAME: ${DOCKERREPO}"
    echo "DIGEST: ${DOCKERSHA}"
    echo "P_DIR: ${PROJECT_DIR}"
fi

echo "+++++++++++"

#echo "export IMAGE_TAG=${SKAFFOLD_IMAGE_TAG}" >> $BASH_ENV #make available to parent CCI job steps that come
          
pip install ortelius-cli

if [ "$BUILD_OR_DEPLOY" == "deploy" ];then
    echo "DEPLOYING to: $DEPLOY_ENV"
    dh deploy ----appname "GLOBAL.eddiewebb.CircleCI Orb.CCI Bank Corp"  --deployenv $DEPLOY_ENV
else    
    #assume build
    python3 -m pip install cyclonedx-bom
    cd $PROJECT_DIR
    if [ -f requirements.txt ];then
        echo "Generating SBOm for python app"
        cyclonedx-py requirements > cyclonedx.json
    elif [ -f pom.xml ];then
        echo "Java app, use sbom generated by maven plugin."
        cp target/bom.json cyclonedx.json
    fi
    dh updatecomp --rsp ortelius.toml --deppkg "cyclonedx@cyclonedx.json"
fi