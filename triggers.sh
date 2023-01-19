#!/bin/bash
# kick off a few commits 

kickOffFail () {
    git checkout rp/failed-test
    git commit --allow-empty -m "test commit"
    git push origin rp/failed-test
    git checkout rp/cool-feature
}

kickOffPass () {
    git checkout rp/cool-feature
    git add .
    git commit -m --allow-empty "fixed policy"
    git push origin rp/cool-feature
}

kickOffPass
kickOffFail