import os
import yaml
import logging


logger = logging.getLogger('config')

bad_context = "cera-vault-oidc-prod"
dev_deploy = "Deploy Dev"
main_workflow = "main"
class ConfigChanger:


    def load_config(self, path):
        self.path=path
        with open(path,'r') as file:
            self.config = yaml.load(file,Loader=yaml.FullLoader)

    def write_config(self):
        with open(self.path,'w') as file:
            yaml.dump(self.config, file)

    def the_dev_deploy_workflow_definition(self):
        job = self.get_workflow_job_named(dev_deploy)
        return job
    
    def get_workflow_job_named(self, name):
        for job in self.config['workflows'][main_workflow]['jobs']:
            if job == name:
                #simple key, construct
                return {"name":name}
            elif name in job:
                #complext without explicit mname, add it
                job[name]['name'] = name
                return job[name]
            elif isinstance(job,dict) :
                # complext object might override name
                job = next(iter(job.values()))
                if "name" in job and job['name'] == name:
                    return job
        

    def add_policy_violation(self):
        self.the_dev_deploy_workflow_definition()['context'].append(bad_context)
        self.write_config()

    def remove_policy_violation(self):
        self.the_dev_deploy_workflow_definition()['context'].remove(bad_context)
        self.write_config()