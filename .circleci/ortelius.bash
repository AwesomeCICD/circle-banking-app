export DHURL="https://console.deployhub.com"
export DHUSER=eddiewebb-ci
export DHPASS=logincci
export DOCKERREPO=${SKAFFOLD_IMAGE_REPO}
export IMAGE_TAG=${SKAFFOLD_IMAGE_TAG}  #skafoold sets from app_version
          

pip install ortelius-cli
python -m pip install cyclonedx-bom
cyclonedx-py --requirements
dh updatecomp --rsp ortelius.toml --deppkg "cyclonedx@cyclonedx.json"
