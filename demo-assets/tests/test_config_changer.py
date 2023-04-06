import pytest
import config_changer

@pytest.fixture(autouse=True)
def default_config_changer() -> config_changer.ConfigChanger:
    changer = config_changer.ConfigChanger()
    changer.load_config('.circleci/config.yml')
    return changer


def test_config_is_loaded(default_config_changer):
    assert(default_config_changer.config != None)
    assert(len(default_config_changer.config['jobs']) > 0)


def test_can_get_named_jobs_simple_entry(default_config_changer):
    name = 'python-test'
    job = default_config_changer.get_workflow_job_named(name)
    assert(job['name'] == name )


def test_can_get_named_jobs_entry_with_info(default_config_changer):
    name = 'java-checkstyle'
    job = default_config_changer.get_workflow_job_named(name)
    assert(job['name'] == name )

def test_can_get_named_jobs_entry_with_info_and_name(default_config_changer):
    name = 'Deploy Dev'
    job = default_config_changer.get_workflow_job_named(name)
    assert(job['name'] == name )


def test_can_modify_context(default_config_changer):
    job = default_config_changer.the_dev_deploy_workflow_definition()
    job['context'].append("boop")
    assert(job['name'] == "Deploy Dev" )
    newjob = default_config_changer.get_workflow_job_named("Deploy Dev")
    assert("boop" in newjob['context'] )
   