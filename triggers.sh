#!/bin/bash
# kick off a few commits 

kickOffFail () {
    git checkout rp/failed-test
    git commit --allow-empty -m "test commit"
    git push origin rp/failed-test
}

kickOffPass () {
    git checkout rp/cool-feature
    git add .
    git commit -m "fixed policy"
    git push origin rp/cool-feature
}

kickOffFail
kickOffPass