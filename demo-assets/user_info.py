import os
import json
import logging

logger = logging.getLogger('userinfo')

user_info_file_path = "demo-assets/userinfo.json"
class UserInfo:

    fields = {
         "orgname":{"default":"AwesomeCICD","envvar":"GITHUB_ORG"},
         "reponame":{"default":"circle-banking-app","envvar":"GITHUB_REPO"},
         "username":{"default":"","envvar":"GITHUB_USER"},
         "github_token":{"default":"","envvar":"GITHUB_API_TOKEN"},
    }

    def __init__(self, username=None, orgname=None, reponame=None, options=None):
        self.username = username
        self.orgname = orgname
        self.reponame = reponame
        self.options = options

    def from_file( prompt_missing=True,update_collected=True):
        me = UserInfo()
        if os.path.isfile(user_info_file_path):
            with open(user_info_file_path,'r') as file:
                existing = json.load(file)
                for field in existing:
                    if existing[field]: #not null
                        me.__dict__[field] = existing[field]
        if prompt_missing:
            me.prompt_for_missing_info()
            if update_collected:
                with open(user_info_file_path, 'w') as json_file:
                    json.dump(me.__dict__, json_file)
        return me

    def prompt_for_missing_info(self):
        for key in UserInfo.fields:
            field = UserInfo.fields[key]
            if key in self.__dict__ and self.__dict__[key]:
                logger.debug(f'Using {key} from file')
            elif field['envvar'] in os.environ: 
                self.__dict__[key] = os.environ[field['envvar']]                      
                logger.debug(f'Set {key} from envvar')
            elif field['default']:
                self.__dict__[key] = field['default']
                logger.debug(f'Set {key} from default value')
            else:
                self.__dict__[key]=input(f'No defaul or envvar for {key}. Please enter value:')
         