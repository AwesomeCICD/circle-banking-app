#!/usr/bin/env python3
import shutil
import sys
import logging
from subprocess import call,run
import user_info, config_changer

def commit_bad_tests():
    test_file_name='src/balancereader/src/test/java/com/circleci/samples/bankcorp/balancereader/BalanceReaderControllerTest.java'
    shutil.copy('./demo-assets/resources/BalanceReaderControllerTest.java',test_file_name)
    run(['git','add', test_file_name],capture_output=True)
    run(['git','commit', '-m',"Dev work with failing tests.."],capture_output=True)
    run(['git','push'], capture_output=True)

commit_bad_tests()