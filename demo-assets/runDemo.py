#!/usr/bin/env python3
import shutil
import sys
import logging
import requests
from subprocess import call,run
import user_info, config_changer


main_branch = 'feature/SE-105'
demo_assets = 'demo-assets'
auth    = None
settings = None
configHelper = config_changer.ConfigChanger()
current_hash =""

"""
This is the primary flow of demo
"""
def main():
    global configHelper, current_hash
    setup_logging()
    current_hash = get_git_hash(demo_assets)
    collectValues()
    get_gh_user()

    #reset state
    force_latest_on_main()
    happy_branch = f'demo-{settings.username}'
    sync_or_create_branch(happy_branch)
    logger.info('\nReady on My Demo Branch %s!!\n',happy_branch)
   
    #Add config violation & pause
    input(">>> Hit enter to push policy failure")
    configHelper.load_config('.circleci/config.yml')
    commit_policy_failure()
    push_changes(happy_branch)
   
    #Add Config violation fix, spawn passing branch with dev deploy
    input(">>> Hit enter to FIX policy failure, and spawn test failures and pass")
    remove_policy_failure()
    push_changes(happy_branch)

    # Run a branch of fialing tests, no deploy
    fail_branch = f'demo-{settings.username}-fails'
    sync_or_create_branch(fail_branch)
    commit_bad_tests()
    push_changes(fail_branch)
    logger.info("(You are on fail branch.)")
    logger.info(f'(run `git checkout {happy_branch}` for the passing branch)')



def setup_logging():
    global logger
    # default debug level logs go to file with detailed logging format (level, name, message) 
    logging.basicConfig(level=logging.DEBUG, filename='demo-assets/demo.log')
    logger = logging.getLogger('runDemo')
    # console is INFO only and just (message)
    ch = logging.StreamHandler(sys.stdout)
    ch.setLevel(logging.INFO)
    ch.setFormatter(logging.Formatter('%(message)s'))
    logger.addHandler(ch)


def collectValues():
    global auth, settings
    settings = user_info.UserInfo.from_file()
    auth=(settings.username,settings.github_token)

def get_gh_user():
    r = requests.get("https://api.github.com/user",auth=auth)
    if r.status_code == 200:
        logger.info('\nLet\'s do this demo %s!!\n',r.json()['name'])
    else:
        logger.error(f'GH check failed with response code: {r.status_code}')
        logger.error(r.text)
        exit(1)

def force_latest_on_main():
    cur_branch = run(['git','branch','--show-current'], capture_output=True)
    if cur_branch.stdout != main_branch:
        logger.info("Not on main,switching..")
        output = run(['git','stash','push'],capture_output=True)
        output = run(['git','checkout',main_branch],capture_output=True)
    logger.info("Pulling latest changes into main..")
    run(['git','pull'],capture_output=True)
    reload_script_if_new()
    logger.info('Ready on Main\n')

"""
Script runs from memory, and may not reflect latest on main.  
Check hash of script and reload if different.
"""
def reload_script_if_new():
    new_hash = get_git_hash(demo_assets)
    logger.debug("script hash compare - running: %s",current_hash)
    logger.debug("script hash compare - new: %s",new_hash)
    if current_hash != new_hash:
        logger.warning("Script hash does not match latest from main, restarting.")
        refresh()
    else:
        logger.debug("Hashes match, keep rolling!")

def sync_or_create_branch(name):
    run(['git','branch','-D',name],capture_output=True)
    run(['git','checkout', '-b',name],capture_output=True)
    logger.debug("New branch %s created",name)
    logger.debug(f'Ensuring {name} has latest from main..')
    run(['git','reset','--hard', main_branch],capture_output=True)
    logger.info("%s ready",name)


def commit_policy_failure():
    configHelper.add_policy_violation()
    run(['git','add','.circleci/config.yml'],capture_output=True)
    run(['git','commit', '-m',"Violate config policy with prod contex on non default branch"],capture_output=True)

def remove_policy_failure():
    configHelper.remove_policy_violation()
    run(['git','add','.circleci/config.yml'],capture_output=True)
    run(['git','commit', '-m',"Remove policy violation"],capture_output=True)

def push_changes(branch_name):
    run(['git','push','-f','--set-upstream','origin',branch_name ], capture_output=True)
    logger.info("Changes pushed")


def commit_bad_tests():
    test_file_name='src/balancereader/src/test/java/anthos/samples/bankofanthos/balancereader/BalanceReaderControllerTest.java'
    shutil.copy('./demo-assets/resources/BalanceReaderControllerTest.java',test_file_name)
    run(['git','add', test_file_name],capture_output=True)
    run(['git','commit', '-m',"Dev work with failing tests.."],capture_output=True)

def refresh():
    global current_hash
    current_hash = get_git_hash(__file__)
    with open(__file__) as fo:
        source_code = fo.read()
        byte_code = compile(source_code, __file__, "exec")
        exec(byte_code)
    logger.debug("Dynamically loaded script execution ended. Exiting parent process.")
    exit(0) # do not resume 'old' script

def get_git_hash(path):
    run(['git','rev-parse',f'HEAD:{path}'],capture_output=True).stdout

main()
