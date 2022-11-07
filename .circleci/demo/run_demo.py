"""Manages full lifecycle of an SE demo on CircleCI."""

#!/usr/bin/env python3
import os
import requests
import re
from subprocess import call
import logging


logger = logging.getLogger('cci_demo')
logger.setLevel(logging.DEBUG)
# create file handler which logs even debug messages
fh = logging.FileHandler('/tmp/demo.log')
fh.setLevel(logging.DEBUG)
# create console handler with a higher log level
ch = logging.StreamHandler()
ch.setLevel(logging.INFO)
# create formatter and add it to the handlers
formatter = logging.Formatter('%(asctime)s - %(levelname)s - %(message)s')
ch.setFormatter(formatter)
fh.setFormatter(formatter)
# add the handlers to logger
logger.addHandler(ch)
logger.addHandler(fh)


"""
Setup 
"""
starting_hash='b4f2b4eec46ca9cc29a95ef83c22ee72e3341cba'
target_branch='demo-flow' #should we keeep off main?
github_login="UNKNOWN" # well get it..
github_org='AwesomeCICD'
github_token=os.environ['GITHUB_API_TOKEN']
github_repo='bank-of-aion'
test_case='src/ledgerwriter/src/test/java/anthos/samples/bankofanthos/ledgerwriter/TransactionValidatorTest.java'
test_case_line=222
base_url=f'https://api.github.com/repos/{github_org}/{github_repo}'.format(**locals())
logger.info("using base URL: " + base_url )


"""
Go
"""


def main():
    """Action starts here."""
    getGithubUserInfo()
    closeAllMyGithubeIssues()
    issue=newDemoIssueId()
    branch=newDemoBranch(issue)
    uncommentTestFailure()
    commitLocalChangeAgainstIssue(branch,issue,"Breaks issue #" + str(issue['number']) + " with failing test.")
    pr=openPullRequestAgainstBranch(branch,issue)
    logger.info("PR: " + pr['html_url'] + " created")
    input("Press Enter to commit fix...")
    commentTestFailure()
    commitLocalChangeAgainstIssue(branch,issue,"Fixes issue #" + str(issue['number']) + ", tests passing.")
    logger.info("PR: " + pr['html_url'] + " will be closed if still open")
    input("Press enter to checkout latest from main (reset)")
    mergePullRequestIfOpen(pr)
    closeAllMyGithubeIssues()




def getGithubUserInfo():
    global github_login
    """Use provided token to load user login info and set Auth headers."""
    logger.debug('>>>getUserInfo()')
    url="https://api.github.com/user"
    response = fetch(url)
    github_login = response['login']
    logger.info("GH User: " + github_login)
    logger.debug('<<<getUserInfo()')

def fetch(url, params={}):
    headers = {
        "Accept": "application/vnd.github+json",
        "Authorization": f'Bearer {github_token}'
    }
    logger.debug (f'Calling {url}')
    r = requests.get(url,headers=headers,params=params)
    if r.status_code == 200:
        logger.debug("API Success.")
        return r.json()
    else:
        logger.error("error contactubg GH api, did you set a GITHUB_API_TOKEN variable?")
        logger.error(r.text)
        exit(1)

def request(url, method="POST",params={}, payload=None):
    headers = {
        "Accept": "application/vnd.github+json",
        "Authorization": f'Bearer {github_token}'
    }
    logger.debug (f'Calling {url}')
    r = requests.request(method, url, headers=headers, params=params, json=payload)
    if r.status_code >= 200 and r.status_code < 300 :
        logger.debug("API Success.")
        return r.json()
    else:
        logger.error("error contactubg GH api, did you set a GITHUB_API_TOKEN variable?")
        logger.error(r.text)
        exit(1)


def closeAllMyGithubeIssues():
    params={'state':'open','labels':f'demo-{github_login}'}
    url = base_url+'/issues'
    response = fetch(url, params=params)
    
    for issue in response:
        logger.info("Closing issue: " + issue['url'])
        closeGithubClosable(issue)
   
   

def closeGithubClosable(closable):
    status={'state':'closed'}
    url=closable['url']
    r = request( closable['url'],method="PATCH", payload=status)

def newDemoIssueId():
    logger.info("Creating new issue")
    new_issue={
        'title':"Demo: add functionality X to service Y",
        'body':"As a user I should be able to A so that B. I will be successful when O.",
        'labels': [ f'demo-{github_login}' ]
        }
    url = base_url + "/issues"
    response = request(url, payload=new_issue)
    logger.info("Created.")
    return response

def newDemoBranch(issue):
    branch_name='issue-'+str(issue['number'])
    logger.info("Creating branch: " + branch_name)
    call(['git','checkout','-b',branch_name])
    return branch_name

def uncommentTestFailure():
    with open(test_case, 'r+') as fd:
        contents = fd.readlines()
        contents.insert(222, 'fail("An intentional failure inserted by CircleCI");\n')  # new_string should end in a newline
        fd.seek(0)  # readlines consumes the iterator, so we need to start over
        fd.writelines(contents)  # No need to truncate as we are increasing filesize
   


def commentTestFailure():
    with open(test_case, 'r+') as fd:
        contents = fd.readlines()
        del contents[222]  # new_string should end in a newline
        fd.seek(0)  # readlines consumes the iterator, so we need to start over
        fd.truncate()
        fd.writelines(contents)  
   

def commitLocalChangeAgainstIssue(branch_name,  issue, commit_message):
    call(['git','commit','-am',commit_message])
    call(['git','push','--set-upstream','origin',branch_name])

def openPullRequestAgainstBranch(branch_name, issue):
    pull_request={
        'title':'Merge ' + branch_name + ' into production stream',
        'head':branch_name,
        'base':target_branch,
        'body':'Please review and merge changes for Issue #' +str(issue['number']),
        'labels': f'demo-{github_login}'
    }
    url = base_url+'/pulls'
    r = request(url, payload=pull_request)
    return r


def mergePullRequestIfOpen(pr):
    merge_details={
        'commit_title':'Merging hanging PR from demo.',
        'commit_message':'This PR was left open during a demo, and was forced merge upon completion',
    }
    url = base_url+'/pulls/' + str(pr['number']) + '/merge'
    r = request(url, method="PUT", payload=merge_details)
  

main()
