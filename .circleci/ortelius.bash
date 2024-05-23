export DHURL="https://console.deployhub.com"
export DHUSER=eddiewebb-ci
export DHPASS=logincci
export DOCKERREPO=${SKAFFOLD_IMAGE_REPO}
export IMAGE_TAG=${SKAFFOLD_IMAGE_TAG}  #skafoold sets from git tree specific sha
echo "export IMAGE_TAG=${SKAFFOLD_IMAGE_TAG}" >> $BASH_ENV #make available to parent CCI job steps that come
          

pip install ortelius-cli
python -m pip install cyclonedx-bom
cyclonedx-py --requirements
dh updatecomp --rsp ortelius.toml --deppkg "cyclonedx@cyclonedx.json"
