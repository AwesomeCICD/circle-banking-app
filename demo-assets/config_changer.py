import os
import yaml
import logging


logger = logging.getLogger('config')

bad_context = "cera-vault-oidc-prod"
dev_deploy_prefix = 'Deploy Dev'
docker_push_preifx = 'Skaffold build & Push'
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
        job = self.get_workflow_job_with_prefix(dev_deploy_prefix)
        return job
    
    def the_docker_push_workflow_definition(self):
        job = self.get_workflow_job_with_prefix(docker_push_preifx)
        return job
    
    def get_workflow_job_with_prefix(self, prefix):
        for job in self.config['workflows'][main_workflow]['jobs']:
            if isinstance(job,dict) :
                # complext object might override name
                key = next(iter(job.keys()))
                job = job[key]
                if key.startswith(prefix):
                    job['name']=key
                    return job
                elif "name" in job and job['name'].startswith(prefix):
                    return job
            elif isinstance(job,str) and job.startswith(prefix):
                #simple key, construct
                return {"name": job}
        

    def add_policy_violation(self):
        self.the_docker_push_workflow_definition()['context'].append(bad_context)
        self.write_config()

    def remove_policy_violation(self):
        self.the_docker_push_workflow_definition()['context'].remove(bad_context)
        self.write_config()