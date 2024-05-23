echo "++++++++++"
echo "REPO: ${SKAFFOLD_IMAGE_REPO}"
echo "IMAGE: ${SKAFFOLD_IMAGE}"
echo "TAG: ${SKAFFOLD_IMAGE_TAG}"
echo "NAME: ${SKAFFOLD_IMAGE%":$SKAFFOLD_IMAGE_TAG"}"
env
echo "+++++++++++"


export DHURL="https://console.deployhub.com"
export DHUSER=eddiewebb-ci
export DHPASS=logincci
export DOCKERREPO=${SKAFFOLD_IMAGE%":$SKAFFOLD_IMAGE_TAG"}
export IMAGE_TAG=${SKAFFOLD_IMAGE_TAG}  #skafoold sets from git tree specific sha
#echo "export IMAGE_TAG=${SKAFFOLD_IMAGE_TAG}" >> $BASH_ENV #make available to parent CCI job steps that come
          
pip install ortelius-cli
python3 -m pip install cyclonedx-bom
cd $SKAFFOLD_BUILD_CONTEXT
cyclonedx-py requirements > cyclonedx.json
dh updatecomp --rsp ortelius.toml --deppkg "cyclonedx@cyclonedx.json"
